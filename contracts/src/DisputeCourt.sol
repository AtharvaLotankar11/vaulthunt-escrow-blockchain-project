// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDisputeCourt} from "./interfaces/IDisputeCourt.sol";
import {IReportRegistry} from "./interfaces/IReportRegistry.sol";

/// @title DisputeCourt
/// @notice A small staked jury that settles disputes between a hunter and a company.
///
/// How it works
///  1. Anyone can become a juror by staking BBT (`stake`). Stakes at or above `minStake` are in
///     the pool.
///  2. After a rejection the hunter pays the dispute fee THEMSELVES (`payDisputeFee`, after
///     approving BBT), then calls `Registry.escalate`. The Registry opens the case and
///     `jurorsPerCase` jurors are drawn from the pool. The hunter and the program's company can
///     never be drawn for their own case. (The Court never pulls tokens from an address chosen
///     by someone else.)
///  3. Jurors vote in two steps so nobody can copy a vote: `commitVote` (hidden), then, after the
///     commit window, `revealVote`.
///  4. Anyone calls `resolveCase`. The majority of REVEALED votes wins. Jurors who voted with
///     the verdict share the reward pool (the dispute fee plus the stake slashed from jurors who
///     voted against it or failed to reveal). The verdict is sent to the Registry, which pays
///     the hunter or refunds the company.
///
/// Tie-break (documented rule): when the revealed votes are tied, including "nobody revealed",
/// a case that came from a REJECTION goes to the company (the hunter has the burden of proof),
/// and a case that came from a company TIMEOUT goes to the hunter (the company stayed silent).
///
/// Rewards and slashes are bookkeeping on juror stakes (no token transfers), so a juror's
/// reward is collected with `requestUnstake` and `withdrawStake`.
///
/// KNOWN LIMITATION (put in LIMITATIONS.md): jurors are drawn with on-chain pseudo-randomness
/// (`block.prevrandao`). A block proposer could influence it slightly. This is acceptable for a
/// testnet demo; production should use a verifiable random function such as Chainlink VRF.
contract DisputeCourt is IDisputeCourt, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------------------

    struct Config {
        uint256 jurorsPerCase; // how many jurors are drawn per case (3 for the demo)
        uint256 minStake; // BBT needed to be in the pool
        uint256 slashPerJuror; // BBT taken from a juror who voted against the verdict or did not reveal
        uint256 disputeFee; // BBT paid by the hunter to open a case
        uint64 commitPeriod; // seconds jurors have to commit
        uint64 revealPeriod; // seconds jurors have to reveal, after the commit period
        uint64 unstakeCooldown; // seconds between requesting and withdrawing a stake
    }

    enum CaseStatus {
        None,
        Voting,
        Resolved
    }

    struct Case {
        uint256 reportId;
        address hunter;
        address programOwner;
        bool byTimeout;
        CaseStatus status;
        bool hunterWins; // valid once Resolved
        uint64 openedAt;
        uint64 commitDeadline;
        uint64 revealDeadline;
        uint256 fee; // BBT held for this case
        uint256 hunterVotes;
        uint256 companyVotes;
        uint256 revealedCount;
        address[] jurors;
    }

    struct VoteInfo {
        bool selected;
        bool committed;
        bool revealed;
        bool hunterWins;
        bytes32 commitHash;
    }

    // ---------------------------------------------------------------------------------
    // Configuration (fixed at deployment; the Court has no owner and no admin functions)
    // ---------------------------------------------------------------------------------

    address public immutable registry;
    IERC20 public immutable token;
    address public immutable treasury;

    uint256 public immutable jurorsPerCase;
    uint256 public immutable minStake;
    uint256 public immutable slashPerJuror;
    uint256 public immutable disputeFee;
    uint64 public immutable commitPeriod;
    uint64 public immutable revealPeriod;
    uint64 public immutable unstakeCooldown;

    // ---------------------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------------------

    mapping(address juror => uint256) public jurorStake;
    mapping(address juror => uint256) public unstakeAt; // time the stake can be withdrawn
    mapping(address juror => bool) public unstakePending;
    mapping(address juror => uint256) public activeCases;

    address[] private _pool;
    mapping(address juror => uint256) private _poolIndex; // 1-based, 0 = not in pool

    /// @notice BBT set aside to pay the fee of cases that have no fee payer (company timeouts).
    uint256 public reserve;

    struct Prepaid {
        address payer;
        uint256 amount;
    }

    /// @notice Dispute fees paid in advance, waiting for the Registry to open the case.
    mapping(uint256 reportId => Prepaid) public prepaid;

    uint256 public caseCount; // case ids run from 1 to caseCount
    mapping(uint256 caseId => Case) private _cases;
    mapping(uint256 reportId => uint256) public caseOfReport;
    mapping(uint256 caseId => mapping(address juror => VoteInfo)) private _votes;

    // ---------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------

    event Staked(address indexed juror, uint256 amount, uint256 totalStake);
    event UnstakeRequested(address indexed juror, uint256 unlockAt);
    event StakeWithdrawn(address indexed juror, uint256 amount);
    event ReserveFunded(address indexed from, uint256 amount);
    event DisputeFeePaid(uint256 indexed reportId, address indexed payer, uint256 amount);
    event DisputeFeeRefunded(uint256 indexed reportId, address indexed payer, uint256 amount);
    event CaseOpened(
        uint256 indexed caseId, uint256 indexed reportId, address indexed hunter, bool byTimeout, uint256 fee, address[] jurors
    );
    event VoteCommitted(uint256 indexed caseId, address indexed juror);
    event VoteRevealed(uint256 indexed caseId, address indexed juror, bool hunterWins);
    event CaseResolved(uint256 indexed caseId, uint256 indexed reportId, bool hunterWins, uint256 hunterVotes, uint256 companyVotes);
    event JurorRewarded(uint256 indexed caseId, address indexed juror, uint256 amount);
    event JurorSlashed(uint256 indexed caseId, address indexed juror, uint256 amount);

    // ---------------------------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------------------------

    /// @param registry_ The ReportRegistry (the only caller of `openCase`, and the receiver of verdicts).
    /// @param token_ BountyToken (BBT): used for stakes and fees.
    /// @param treasury_ PlatformTreasury: receives rounding dust and unclaimable pools. May be
    ///        address(0), in which case those amounts go to `reserve`.
    constructor(address registry_, address token_, address treasury_, Config memory cfg) {
        require(registry_ != address(0), "DisputeCourt: registry is zero address");
        require(token_ != address(0), "DisputeCourt: token is zero address");
        require(cfg.jurorsPerCase > 0, "DisputeCourt: jurors per case is zero");
        require(cfg.minStake > 0, "DisputeCourt: min stake is zero");
        require(cfg.slashPerJuror <= cfg.minStake, "DisputeCourt: slash above min stake");
        require(
            cfg.commitPeriod > 0 && cfg.revealPeriod > 0 && cfg.unstakeCooldown > 0, "DisputeCourt: period is zero"
        );

        registry = registry_;
        token = IERC20(token_);
        treasury = treasury_;
        jurorsPerCase = cfg.jurorsPerCase;
        minStake = cfg.minStake;
        slashPerJuror = cfg.slashPerJuror;
        disputeFee = cfg.disputeFee;
        commitPeriod = cfg.commitPeriod;
        revealPeriod = cfg.revealPeriod;
        unstakeCooldown = cfg.unstakeCooldown;
    }

    // ---------------------------------------------------------------------------------
    // Jurors: stake and unstake
    // ---------------------------------------------------------------------------------

    /// @notice Stake BBT (approve the Court first). Needs at least `minStake` in total to be drawn.
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "DisputeCourt: stake is zero");
        require(!unstakePending[msg.sender], "DisputeCourt: unstake pending");

        uint256 total = jurorStake[msg.sender] + amount;
        jurorStake[msg.sender] = total;
        _syncPool(msg.sender);
        emit Staked(msg.sender, amount, total);

        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Leave the pool and start the cooldown. Not possible while you sit on an open case.
    function requestUnstake() external {
        require(jurorStake[msg.sender] > 0, "DisputeCourt: nothing staked");
        require(activeCases[msg.sender] == 0, "DisputeCourt: juror has open cases");
        require(!unstakePending[msg.sender], "DisputeCourt: unstake already requested");

        uint256 unlockAt = block.timestamp + unstakeCooldown;
        unstakePending[msg.sender] = true;
        unstakeAt[msg.sender] = unlockAt;
        _removeFromPool(msg.sender);
        emit UnstakeRequested(msg.sender, unlockAt);
    }

    /// @notice Take your whole stake (including rewards, minus slashes) once the cooldown is over.
    function withdrawStake() external nonReentrant {
        require(unstakePending[msg.sender], "DisputeCourt: unstake not requested");
        require(block.timestamp >= unstakeAt[msg.sender], "DisputeCourt: cooldown not finished");

        uint256 amount = jurorStake[msg.sender];
        jurorStake[msg.sender] = 0;
        unstakePending[msg.sender] = false;
        unstakeAt[msg.sender] = 0;
        emit StakeWithdrawn(msg.sender, amount);

        if (amount > 0) token.safeTransfer(msg.sender, amount);
    }

    /// @notice Anyone may add BBT that pays the fee of cases opened by a company timeout
    ///         (nobody pays a fee in that case).
    function fundReserve(uint256 amount) external nonReentrant {
        require(amount > 0, "DisputeCourt: amount is zero");
        reserve += amount;
        emit ReserveFunded(msg.sender, amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Pay the dispute fee for a report (approve the Court first). The hunter does this
    ///         after a rejection and before calling `Registry.escalate`. The tokens are pulled
    ///         from the caller only.
    function payDisputeFee(uint256 reportId) external nonReentrant {
        require(disputeFee > 0, "DisputeCourt: no dispute fee");
        require(caseOfReport[reportId] == 0, "DisputeCourt: report already has a case");
        require(prepaid[reportId].amount == 0, "DisputeCourt: fee already paid");

        prepaid[reportId] = Prepaid({payer: msg.sender, amount: disputeFee});
        emit DisputeFeePaid(reportId, msg.sender, disputeFee);

        token.safeTransferFrom(msg.sender, address(this), disputeFee);
    }

    /// @notice Take back a fee you paid if no case was opened for that report.
    function refundDisputeFee(uint256 reportId) external nonReentrant {
        Prepaid memory p = prepaid[reportId];
        require(p.amount > 0 && p.payer == msg.sender, "DisputeCourt: no fee to refund");
        require(caseOfReport[reportId] == 0, "DisputeCourt: report already has a case");

        delete prepaid[reportId];
        emit DisputeFeeRefunded(reportId, msg.sender, p.amount);

        token.safeTransfer(msg.sender, p.amount);
    }

    // ---------------------------------------------------------------------------------
    // Registry: open a case
    // ---------------------------------------------------------------------------------

    /// @inheritdoc IDisputeCourt
    function openCase(uint256 reportId, address hunter, address feePayer) external override nonReentrant {
        require(msg.sender == registry, "DisputeCourt: caller is not the registry");
        require(caseOfReport[reportId] == 0, "DisputeCourt: report already has a case");

        address programOwner = IReportRegistry(registry).programOwnerOf(reportId);

        uint256 caseId = ++caseCount;
        caseOfReport[reportId] = caseId;

        Case storage c = _cases[caseId];
        c.reportId = reportId;
        c.hunter = hunter;
        c.programOwner = programOwner;
        c.byTimeout = feePayer == address(0);
        c.status = CaseStatus.Voting;
        c.openedAt = uint64(block.timestamp);
        c.commitDeadline = uint64(block.timestamp) + commitPeriod;
        c.revealDeadline = c.commitDeadline + revealPeriod;

        // The fee. After a rejection the hunter must already have paid it (`payDisputeFee`).
        // After a company timeout nobody owes a fee, so the reserve pays it (as far as it reaches),
        // unless somebody prepaid.
        Prepaid memory paid = prepaid[reportId];
        if (feePayer != address(0) && disputeFee > 0) {
            require(paid.payer == feePayer && paid.amount == disputeFee, "DisputeCourt: dispute fee not paid");
        }
        uint256 fee = paid.amount;
        if (feePayer == address(0) && fee == 0) {
            fee = disputeFee > reserve ? reserve : disputeFee;
            reserve -= fee;
        }
        delete prepaid[reportId];
        c.fee = fee;

        _selectJurors(caseId, c, hunter, programOwner);
        emit CaseOpened(caseId, reportId, hunter, c.byTimeout, fee, c.jurors);
    }

    // ---------------------------------------------------------------------------------
    // Jurors: vote
    // ---------------------------------------------------------------------------------

    /// @notice Step 1: commit a hidden vote.
    ///         voteHash = keccak256(abi.encode(hunterWins, salt, jurorAddress, caseId))
    function commitVote(uint256 caseId, bytes32 voteHash) external {
        Case storage c = _cases[caseId];
        require(c.status == CaseStatus.Voting, "DisputeCourt: case is not open for voting");
        require(block.timestamp <= c.commitDeadline, "DisputeCourt: commit window closed");

        VoteInfo storage v = _votes[caseId][msg.sender];
        require(v.selected, "DisputeCourt: not a juror in this case");
        require(!v.committed, "DisputeCourt: already committed");
        require(voteHash != bytes32(0), "DisputeCourt: empty vote hash");

        v.committed = true;
        v.commitHash = voteHash;
        emit VoteCommitted(caseId, msg.sender);
    }

    /// @notice Step 2, after the commit window: reveal your vote.
    function revealVote(uint256 caseId, bool hunterWins, bytes32 salt) external {
        Case storage c = _cases[caseId];
        require(c.status == CaseStatus.Voting, "DisputeCourt: case is not open for voting");
        require(block.timestamp > c.commitDeadline, "DisputeCourt: reveal window not open yet");
        require(block.timestamp <= c.revealDeadline, "DisputeCourt: reveal window closed");

        VoteInfo storage v = _votes[caseId][msg.sender];
        require(v.selected, "DisputeCourt: not a juror in this case");
        require(v.committed, "DisputeCourt: no vote committed");
        require(!v.revealed, "DisputeCourt: already revealed");
        require(
            keccak256(abi.encode(hunterWins, salt, msg.sender, caseId)) == v.commitHash,
            "DisputeCourt: reveal does not match commit"
        );

        v.revealed = true;
        v.hunterWins = hunterWins;
        if (hunterWins) c.hunterVotes++;
        else c.companyVotes++;
        c.revealedCount++;

        emit VoteRevealed(caseId, msg.sender, hunterWins);
    }

    // ---------------------------------------------------------------------------------
    // Anyone: settle
    // ---------------------------------------------------------------------------------

    /// @notice Count the revealed votes, pay and slash jurors, and send the verdict to the
    ///         Registry. Possible once every juror has revealed, or after the reveal window.
    function resolveCase(uint256 caseId) external nonReentrant {
        Case storage c = _cases[caseId];
        require(c.status == CaseStatus.Voting, "DisputeCourt: case is not open for voting");
        require(
            c.revealedCount == c.jurors.length || block.timestamp > c.revealDeadline,
            "DisputeCourt: voting still in progress"
        );

        // Verdict: majority of revealed votes; a tie follows the documented tie-break.
        bool hunterWins;
        if (c.hunterVotes > c.companyVotes) hunterWins = true;
        else if (c.hunterVotes < c.companyVotes) hunterWins = false;
        else hunterWins = c.byTimeout;

        c.status = CaseStatus.Resolved;
        c.hunterWins = hunterWins;

        uint256 dust = _settleJurors(caseId, c, hunterWins);

        emit CaseResolved(caseId, c.reportId, hunterWins, c.hunterVotes, c.companyVotes);

        // Interactions last.
        if (dust > 0) {
            if (treasury != address(0)) token.safeTransfer(treasury, dust);
            else reserve += dust;
        }
        IReportRegistry(registry).applyVerdict(c.reportId, hunterWins);
    }

    // ---------------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------------

    function getCase(uint256 caseId) external view returns (Case memory) {
        return _cases[caseId];
    }

    function jurorsOf(uint256 caseId) external view returns (address[] memory) {
        return _cases[caseId].jurors;
    }

    function voteInfo(uint256 caseId, address juror) external view returns (VoteInfo memory) {
        return _votes[caseId][juror];
    }

    function poolSize() external view returns (uint256) {
        return _pool.length;
    }

    function isInPool(address juror) external view returns (bool) {
        return _poolIndex[juror] != 0;
    }

    // ---------------------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------------------

    /// @dev Draw `jurorsPerCase` distinct eligible jurors: every pool member gets a pseudo-random
    ///      score and the lowest scores win. No modulo, no retries, and the hunter and the
    ///      company are skipped.
    function _selectJurors(uint256 caseId, Case storage c, address hunter, address programOwner) private {
        uint256 n = jurorsPerCase;
        bytes32 seed = keccak256(abi.encode(block.prevrandao, caseId, address(this)));

        address[] memory chosen = new address[](n);
        uint256[] memory scores = new uint256[](n);
        uint256 filled = 0;

        uint256 poolLength = _pool.length;
        for (uint256 i = 0; i < poolLength; i++) {
            address juror = _pool[i];
            if (juror == hunter || juror == programOwner) continue;

            uint256 score = uint256(keccak256(abi.encode(seed, juror)));

            uint256 position;
            if (filled < n) {
                position = filled;
                filled++;
            } else {
                if (score >= scores[n - 1]) continue;
                position = n - 1;
            }
            while (position > 0 && scores[position - 1] > score) {
                scores[position] = scores[position - 1];
                chosen[position] = chosen[position - 1];
                position--;
            }
            scores[position] = score;
            chosen[position] = juror;
        }

        require(filled == n, "DisputeCourt: not enough eligible jurors");

        for (uint256 i = 0; i < n; i++) {
            address juror = chosen[i];
            c.jurors.push(juror);
            _votes[caseId][juror].selected = true;
            activeCases[juror]++;
        }
    }

    /// @dev Slash jurors who did not vote with the verdict, then split the pool among those who did.
    /// @return dust Tokens nobody can be paid (rounding, or no juror voted with the verdict).
    function _settleJurors(uint256 caseId, Case storage c, bool hunterWins) private returns (uint256 dust) {
        address[] memory jurors = c.jurors;
        uint256 count = jurors.length;
        bool[] memory coherent = new bool[](count);

        uint256 pot = c.fee;
        uint256 coherentCount = 0;

        for (uint256 i = 0; i < count; i++) {
            address juror = jurors[i];
            VoteInfo storage v = _votes[caseId][juror];
            activeCases[juror]--;

            if (v.revealed && v.hunterWins == hunterWins) {
                coherent[i] = true;
                coherentCount++;
            } else {
                uint256 stakeBalance = jurorStake[juror];
                uint256 slash = stakeBalance < slashPerJuror ? stakeBalance : slashPerJuror;
                if (slash > 0) {
                    jurorStake[juror] = stakeBalance - slash;
                    pot += slash;
                    emit JurorSlashed(caseId, juror, slash);
                }
            }
        }

        if (coherentCount == 0) {
            dust = pot;
        } else {
            uint256 share = pot / coherentCount;
            dust = pot % coherentCount;
            if (share > 0) {
                for (uint256 i = 0; i < count; i++) {
                    if (coherent[i]) {
                        jurorStake[jurors[i]] += share;
                        emit JurorRewarded(caseId, jurors[i], share);
                    }
                }
            }
        }

        for (uint256 i = 0; i < count; i++) {
            _syncPool(jurors[i]);
        }
    }

    function _syncPool(address juror) private {
        bool shouldBeInPool = jurorStake[juror] >= minStake && !unstakePending[juror];
        bool inPool = _poolIndex[juror] != 0;
        if (shouldBeInPool && !inPool) {
            _pool.push(juror);
            _poolIndex[juror] = _pool.length;
        } else if (!shouldBeInPool && inPool) {
            _removeFromPool(juror);
        }
    }

    function _removeFromPool(address juror) private {
        uint256 index = _poolIndex[juror];
        if (index == 0) return;

        uint256 lastIndex = _pool.length;
        if (index != lastIndex) {
            address last = _pool[lastIndex - 1];
            _pool[index - 1] = last;
            _poolIndex[last] = index;
        }
        _pool.pop();
        _poolIndex[juror] = 0;
    }
}
