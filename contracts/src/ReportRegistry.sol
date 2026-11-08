// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBountyEscrow} from "./interfaces/IBountyEscrow.sol";
import {IBountyFactory} from "./interfaces/IBountyFactory.sol";
import {IDisputeCourt} from "./interfaces/IDisputeCourt.sol";
import {IReputationSBT} from "./interfaces/IReputationSBT.sol";

/// @title ReportRegistry
/// @notice The single orchestrator of the platform (design decision D2).
///
///   Hunter  : commitReport -> (encrypt + upload off-chain) -> revealReport
///   Company : startReview (optional), acceptReport or rejectReport
///   Anyone  : escalateAfterTimeout once the review deadline has passed
///   Hunter  : escalate after a rejection
///   Court   : applyVerdict
///
/// The Registry is the ONLY address the program escrows accept orders from, so every payout
/// goes through the rules below. The company never calls the escrow to pay.
///
/// Commit-reveal (decision D1): the hunter commits
///     commitHash = keccak256(abi.encode(contentHash, salt, hunter))
/// BEFORE the report is encrypted and uploaded, then reveals (cid, contentHash, salt). The
/// commit proves who found the bug first without showing it; binding the hunter's address
/// stops anyone from copying another hunter's commit.
///
/// Money: revealing a report LOCKS its reward in the escrow, so the company cannot drain the
/// program while a report is waiting. A rejected report keeps its lock during the dispute
/// window so the hunter can still escalate.
contract ReportRegistry is Ownable, ReentrancyGuard {
    // ---------------------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------------------

    enum Status {
        None, // report does not exist
        Committed, // hash committed, report not revealed yet
        Revealed, // revealed and funds locked, waiting for the company
        UnderReview, // company said it started reviewing
        Rejected, // company rejected; hunter may still escalate until the dispute window ends
        Disputed, // with the DisputeCourt
        Paid, // reward credited to the hunter (and pushed if the hunter can receive ETH)
        Refunded // company kept its money (rejection final, or the Court sided with the company)
    }

    struct Report {
        uint256 programId;
        address escrow;
        address hunter;
        Status status;
        IBountyEscrow.Severity claimedSeverity; // stated by the hunter at reveal; locked amount
        IBountyEscrow.Severity paidSeverity; // meaningful once Paid
        uint64 committedAt; // priority timestamp: earliest commit wins duplicates
        uint64 revealedAt;
        uint64 reviewDeadline;
        uint64 rejectedAt;
        bytes32 commitHash;
        bytes32 contentHash;
        string cid; // IPFS address of the ENCRYPTED report
    }

    // ---------------------------------------------------------------------------------
    // Constants and configuration
    // ---------------------------------------------------------------------------------

    /// @dev Gas cap for badge calls, so a hostile hunter contract cannot block a payout.
    uint256 public constant BADGE_GAS = 400_000;

    uint256 public constant XP_LOW = 10;
    uint256 public constant XP_MEDIUM = 25;
    uint256 public constant XP_HIGH = 50;
    uint256 public constant XP_CRITICAL = 100;

    /// @dev Levels: 1 Rookie, 2 Hacker (100 XP), 3 Elite (300 XP), 4 Legend (700 XP).
    uint256 public constant LEVEL_2_XP = 100;
    uint256 public constant LEVEL_3_XP = 300;
    uint256 public constant LEVEL_4_XP = 700;

    IBountyFactory public immutable factory;
    IReputationSBT public immutable sbt;

    /// @notice Seconds the company has to answer after a report is revealed.
    uint64 public immutable reviewPeriod;
    /// @notice Seconds a hunter has to reveal after committing.
    uint64 public immutable revealWindow;
    /// @notice Seconds a hunter has to escalate after a rejection.
    uint64 public immutable disputeWindow;

    address public court;

    // ---------------------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------------------

    uint256 public reportCount; // report ids run from 1 to reportCount
    mapping(uint256 reportId => Report) private _reports;
    mapping(bytes32 commitHash => bool) public commitUsed;
    mapping(uint256 programId => uint256[]) private _programReports;
    mapping(address hunter => uint256[]) private _hunterReports;

    mapping(address hunter => uint256) public hunterXp;
    mapping(address hunter => bool) public hasBadge;
    mapping(address hunter => uint256) public badgeOf; // token id, valid only if hasBadge

    // ---------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------

    event CourtSet(address indexed court);
    event ReportCommitted(
        uint256 indexed reportId, uint256 indexed programId, address indexed hunter, bytes32 commitHash, uint64 committedAt
    );
    event ReportRevealed(
        uint256 indexed reportId,
        address indexed hunter,
        string cid,
        bytes32 contentHash,
        IBountyEscrow.Severity claimedSeverity,
        uint64 reviewDeadline
    );
    event ReviewStarted(uint256 indexed reportId);
    event ReportRejected(uint256 indexed reportId);
    event RejectionFinalized(uint256 indexed reportId);
    event ReportEscalated(uint256 indexed reportId, address indexed hunter, bool byTimeout);
    event VerdictApplied(uint256 indexed reportId, bool hunterWins);
    event RewardPaid(uint256 indexed reportId, address indexed hunter, IBountyEscrow.Severity severity);
    event BadgeUpdated(address indexed hunter, uint256 indexed tokenId, uint256 level, uint256 xp);

    // ---------------------------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------------------------

    constructor(address factory_, address sbt_, uint64 reviewPeriod_, uint64 revealWindow_, uint64 disputeWindow_)
        Ownable(msg.sender)
    {
        require(factory_ != address(0), "ReportRegistry: factory is zero address");
        require(sbt_ != address(0), "ReportRegistry: sbt is zero address");
        require(reviewPeriod_ > 0 && revealWindow_ > 0 && disputeWindow_ > 0, "ReportRegistry: period is zero");

        factory = IBountyFactory(factory_);
        sbt = IReputationSBT(sbt_);
        reviewPeriod = reviewPeriod_;
        revealWindow = revealWindow_;
        disputeWindow = disputeWindow_;
    }

    /// @notice One-time link to the DisputeCourt (Registry and Court need each other).
    function setCourt(address court_) external onlyOwner {
        require(court == address(0), "ReportRegistry: court already set");
        require(court_ != address(0), "ReportRegistry: court is zero address");
        court = court_;
        emit CourtSet(court_);
    }

    modifier onlyProgramOwner(uint256 reportId) {
        Report storage r = _reports[reportId];
        require(r.status != Status.None, "ReportRegistry: unknown report");
        require(msg.sender == IBountyEscrow(r.escrow).owner(), "ReportRegistry: caller is not the program owner");
        _;
    }

    // ---------------------------------------------------------------------------------
    // Hunter: commit and reveal
    // ---------------------------------------------------------------------------------

    /// @notice Step 1. Prove you found a bug first, without showing it.
    function commitReport(uint256 programId, bytes32 commitHash) external returns (uint256 reportId) {
        require(commitHash != bytes32(0), "ReportRegistry: empty commit hash");
        require(!commitUsed[commitHash], "ReportRegistry: commit hash already used");

        address escrow = factory.programs(programId);
        require(escrow != address(0), "ReportRegistry: unknown program");
        require(IBountyEscrow(escrow).registry() == address(this), "ReportRegistry: program not linked to this registry");

        commitUsed[commitHash] = true;
        reportId = ++reportCount;

        Report storage r = _reports[reportId];
        r.programId = programId;
        r.escrow = escrow;
        r.hunter = msg.sender;
        r.status = Status.Committed;
        r.commitHash = commitHash;
        r.committedAt = uint64(block.timestamp);

        _programReports[programId].push(reportId);
        _hunterReports[msg.sender].push(reportId);

        emit ReportCommitted(reportId, programId, msg.sender, commitHash, r.committedAt);
    }

    /// @notice Step 2, after encrypting the report and uploading it to IPFS. Locks the reward
    ///         for `claimedSeverity` in the program's escrow (reverts if the program cannot
    ///         cover it, so a revealed report is always backed by funds).
    function revealReport(
        uint256 reportId,
        string calldata cid,
        bytes32 contentHash,
        bytes32 salt,
        IBountyEscrow.Severity claimedSeverity
    ) external nonReentrant {
        Report storage r = _reports[reportId];
        require(r.status == Status.Committed, "ReportRegistry: report is not in Committed state");
        require(msg.sender == r.hunter, "ReportRegistry: caller is not the hunter");
        require(block.timestamp <= uint256(r.committedAt) + revealWindow, "ReportRegistry: reveal window closed");
        require(bytes(cid).length > 0, "ReportRegistry: empty CID");
        require(
            keccak256(abi.encode(contentHash, salt, msg.sender)) == r.commitHash,
            "ReportRegistry: reveal does not match commit"
        );

        r.status = Status.Revealed;
        r.revealedAt = uint64(block.timestamp);
        r.reviewDeadline = uint64(block.timestamp + reviewPeriod);
        r.claimedSeverity = claimedSeverity;
        r.contentHash = contentHash;
        r.cid = cid;

        IBountyEscrow(r.escrow).lock(reportId, claimedSeverity);

        emit ReportRevealed(reportId, msg.sender, cid, contentHash, claimedSeverity, r.reviewDeadline);
    }

    // ---------------------------------------------------------------------------------
    // Company: review, accept, reject
    // ---------------------------------------------------------------------------------

    /// @notice Optional signal that the company has started looking at the report.
    function startReview(uint256 reportId) external onlyProgramOwner(reportId) {
        Report storage r = _reports[reportId];
        require(r.status == Status.Revealed, "ReportRegistry: report is not in Revealed state");
        r.status = Status.UnderReview;
        emit ReviewStarted(reportId);
    }

    /// @notice Accept the report at the severity the company decides. Credits the hunter in
    ///         the escrow, pushes the money to them, and updates their reputation badge.
    function acceptReport(uint256 reportId, IBountyEscrow.Severity severity)
        external
        onlyProgramOwner(reportId)
        nonReentrant
    {
        Report storage r = _reports[reportId];
        require(_awaitingCompany(r.status), "ReportRegistry: report is not awaiting review");
        _pay(reportId, r, severity);
    }

    /// @notice Reject the report. Its reward stays locked until the hunter escalates or the
    ///         dispute window ends.
    function rejectReport(uint256 reportId) external onlyProgramOwner(reportId) {
        Report storage r = _reports[reportId];
        require(_awaitingCompany(r.status), "ReportRegistry: report is not awaiting review");
        r.status = Status.Rejected;
        r.rejectedAt = uint64(block.timestamp);
        emit ReportRejected(reportId);
    }

    /// @notice Anyone may close a rejection nobody disputed: the company gets its funds back.
    function finalizeRejection(uint256 reportId) external nonReentrant {
        Report storage r = _reports[reportId];
        require(r.status == Status.Rejected, "ReportRegistry: report is not rejected");
        require(block.timestamp > uint256(r.rejectedAt) + disputeWindow, "ReportRegistry: dispute window still open");

        r.status = Status.Refunded;
        IBountyEscrow(r.escrow).refundCompany(reportId);
        emit RejectionFinalized(reportId);
    }

    // ---------------------------------------------------------------------------------
    // Disputes
    // ---------------------------------------------------------------------------------

    /// @notice The hunter disputes a rejection (the Court takes the dispute fee in BBT).
    function escalate(uint256 reportId) external nonReentrant {
        Report storage r = _reports[reportId];
        require(r.status == Status.Rejected, "ReportRegistry: report is not rejected");
        require(msg.sender == r.hunter, "ReportRegistry: caller is not the hunter");
        require(block.timestamp <= uint256(r.rejectedAt) + disputeWindow, "ReportRegistry: dispute window closed");
        _openDispute(reportId, r, r.hunter, false);
    }

    /// @notice The company never answered. A contract cannot wake itself up, so anyone
    ///         (normally the hunter) calls this once the review deadline has passed.
    function escalateAfterTimeout(uint256 reportId) external nonReentrant {
        Report storage r = _reports[reportId];
        require(_awaitingCompany(r.status), "ReportRegistry: report is not awaiting review");
        require(block.timestamp > r.reviewDeadline, "ReportRegistry: review deadline not reached");
        _openDispute(reportId, r, address(0), true);
    }

    /// @notice Called by the DisputeCourt with the jury's decision.
    function applyVerdict(uint256 reportId, bool hunterWins) external nonReentrant {
        require(msg.sender == court, "ReportRegistry: caller is not the court");

        Report storage r = _reports[reportId];
        require(r.status == Status.Disputed, "ReportRegistry: report is not disputed");

        if (hunterWins) {
            _pay(reportId, r, r.claimedSeverity);
        } else {
            r.status = Status.Refunded;
            IBountyEscrow(r.escrow).refundCompany(reportId);
        }
        emit VerdictApplied(reportId, hunterWins);
    }

    // ---------------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------------

    function getReport(uint256 reportId) external view returns (Report memory) {
        return _reports[reportId];
    }

    function programReportIds(uint256 programId) external view returns (uint256[] memory) {
        return _programReports[programId];
    }

    function hunterReportIds(address hunter) external view returns (uint256[] memory) {
        return _hunterReports[hunter];
    }

    function programOwnerOf(uint256 reportId) external view returns (address) {
        Report storage r = _reports[reportId];
        require(r.status != Status.None, "ReportRegistry: unknown report");
        return IBountyEscrow(r.escrow).owner();
    }

    function severityXp(IBountyEscrow.Severity severity) public pure returns (uint256) {
        if (severity == IBountyEscrow.Severity.Low) return XP_LOW;
        if (severity == IBountyEscrow.Severity.Medium) return XP_MEDIUM;
        if (severity == IBountyEscrow.Severity.High) return XP_HIGH;
        return XP_CRITICAL;
    }

    function levelFor(uint256 xp) public pure returns (uint256) {
        if (xp >= LEVEL_4_XP) return 4;
        if (xp >= LEVEL_3_XP) return 3;
        if (xp >= LEVEL_2_XP) return 2;
        return 1;
    }

    // ---------------------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------------------

    function _awaitingCompany(Status status) private pure returns (bool) {
        return status == Status.Revealed || status == Status.UnderReview;
    }

    function _openDispute(uint256 reportId, Report storage r, address feePayer, bool byTimeout) private {
        address court_ = court;
        require(court_ != address(0), "ReportRegistry: court not set");

        r.status = Status.Disputed;
        emit ReportEscalated(reportId, r.hunter, byTimeout);

        IDisputeCourt(court_).openCase(reportId, r.hunter, feePayer);
    }

    /// @dev State first, then the external calls (checks-effects-interactions).
    function _pay(uint256 reportId, Report storage r, IBountyEscrow.Severity severity) private {
        address hunter = r.hunter;
        address escrow = r.escrow;

        r.status = Status.Paid;
        r.paidSeverity = severity;

        uint256 xp = hunterXp[hunter] + severityXp(severity);
        hunterXp[hunter] = xp;

        // Credits the reward in the escrow. Reverts (and so does the whole call) if the escrow
        // cannot cover the chosen severity.
        IBountyEscrow(escrow).payHunter(reportId, hunter, severity);

        // Push the money to the hunter. If the hunter cannot receive ETH, the credit simply
        // stays in the escrow and they collect it with claim(); the payment is not blocked.
        try IBountyEscrow(escrow).claimFor(hunter) {} catch {}

        _updateBadge(hunter, xp);

        emit RewardPaid(reportId, hunter, severity);
    }

    /// @dev A badge problem (hunter is a contract that cannot receive an NFT, the Registry is
    ///      not the SBT owner, etc.) must never block a payout, so failures are swallowed.
    function _updateBadge(address hunter, uint256 xp) private {
        if (!hasBadge[hunter]) {
            try sbt.mint{gas: BADGE_GAS}(hunter) returns (uint256 newTokenId) {
                hasBadge[hunter] = true;
                badgeOf[hunter] = newTokenId;
            } catch {
                return;
            }
        }

        uint256 tokenId = badgeOf[hunter];
        uint256 level = levelFor(xp);
        try sbt.updateLevel{gas: BADGE_GAS}(tokenId, level, xp) {
            emit BadgeUpdated(hunter, tokenId, level, xp);
        } catch {}
    }
}
