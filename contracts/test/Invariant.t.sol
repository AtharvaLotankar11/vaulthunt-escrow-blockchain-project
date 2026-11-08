// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {BountyToken} from "../src/BountyToken.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";
import {PlatformTreasury} from "../src/PlatformTreasury.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";
import {IReportRegistry} from "../src/interfaces/IReportRegistry.sol";

// =====================================================================================
// Invariant tests: Foundry calls a "handler" with random sequences of actions, and after
// every step the invariants below must still be true.
// =====================================================================================

// ---------------------------------------------------------------- 1. the escrow

/// @dev Plays both roles: it IS the Registry (the only caller of lock, pay and refund) and it
///      acts for the company and the hunters.
contract EscrowHandler is Test {
    uint256 public constant MAX_REPORTS = 12;

    BountyEscrow public escrow;
    address public company;
    address[3] public hunters;

    uint256 public ghostIn; // all ETH that ever went into the escrow
    uint256 public ghostWithdrawn; // all ETH the company took out
    bool public withdrawTookLockedFunds; // violation flag

    constructor(address company_) {
        company = company_;
        hunters = [makeAddr("hunter0"), makeAddr("hunter1"), makeAddr("hunter2")];
    }

    function init(BountyEscrow escrow_, uint256 initialFunding) external {
        require(address(escrow) == address(0), "already initialized"); // the fuzzer must not call this again
        escrow = escrow_;
        ghostIn = initialFunding;
    }

    function _id(uint256 seed) internal pure returns (uint256) {
        return 1 + (seed % MAX_REPORTS);
    }

    function _severity(uint8 value) internal pure returns (IBountyEscrow.Severity) {
        return IBountyEscrow.Severity(value % 4);
    }

    function deposit(uint96 amount) external {
        amount = uint96(bound(amount, 1, 100 ether));
        vm.deal(company, amount);
        vm.prank(company);
        escrow.deposit{value: amount}();
        ghostIn += amount;
    }

    function withdraw(uint96 amount) external {
        amount = uint96(bound(amount, 1, 100 ether));
        uint256 unlockedBefore = escrow.unlockedBalance();
        vm.prank(company);
        try escrow.withdraw(amount) {
            ghostWithdrawn += amount;
            if (amount > unlockedBefore) withdrawTookLockedFunds = true;
        } catch {}
    }

    function lock(uint256 idSeed, uint8 severity) external {
        try escrow.lock(_id(idSeed), _severity(severity)) {} catch {}
    }

    function pay(uint256 idSeed, uint8 severity, uint8 hunterIndex) external {
        try escrow.payHunter(_id(idSeed), hunters[hunterIndex % 3], _severity(severity)) {} catch {}
    }

    function refund(uint256 idSeed) external {
        try escrow.refundCompany(_id(idSeed)) {} catch {}
    }

    function claimFor(uint8 hunterIndex) external {
        try escrow.claimFor(hunters[hunterIndex % 3]) {} catch {}
    }

    function claim(uint8 hunterIndex) external {
        vm.prank(hunters[hunterIndex % 3]);
        try escrow.claim() {} catch {}
    }

    // views used by the invariants
    function sumLocked() external view returns (uint256 total) {
        for (uint256 id = 1; id <= MAX_REPORTS; id++) {
            (uint256 amount, bool locked,) = escrow.lockOf(id);
            if (locked) total += amount;
        }
    }

    function sumClaimable() external view returns (uint256 total) {
        for (uint256 i = 0; i < 3; i++) {
            total += escrow.claimable(hunters[i]);
        }
    }

    function hunterBalances() external view returns (uint256 total) {
        for (uint256 i = 0; i < 3; i++) {
            total += hunters[i].balance;
        }
    }
}

contract EscrowInvariant is Test {
    EscrowHandler internal handler;
    BountyEscrow internal escrow;

    function setUp() public {
        address company = makeAddr("company");
        handler = new EscrowHandler(company);

        BountyFactory factory = new BountyFactory();
        factory.setRegistry(address(handler)); // the handler plays the Registry
        vm.deal(company, 10 ether);
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram{value: 10 ether}(company, [uint16(500), 1500, 3000, 5000]);
        escrow = BountyEscrow(escrowAddress);
        handler.init(escrow, 10 ether);

        targetContract(address(handler));
    }

    /// The escrow always holds at least what is locked plus what hunters are owed.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_BalanceCoversLocksAndCredits() public view {
        assertGe(address(escrow).balance, escrow.totalLocked() + escrow.totalClaimable());
    }

    /// The running totals always equal the sum of the individual records.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_TotalsMatchTheIndividualRecords() public view {
        assertEq(escrow.totalLocked(), handler.sumLocked());
        assertEq(escrow.totalClaimable(), handler.sumClaimable());
    }

    /// The company can never take money that is locked for a report or owed to a hunter.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_NothingLockedIsEverWithdrawn() public view {
        assertFalse(handler.withdrawTookLockedFunds());
    }

    /// Every wei that went in is either still in the escrow, back with the company, or with a hunter.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_EveryWeiIsAccountedFor() public view {
        assertEq(address(escrow).balance + handler.ghostWithdrawn() + handler.hunterBalances(), handler.ghostIn());
    }
}

// ---------------------------------------------------------------- 2. the soulbound badge

contract SbtHandler is Test {
    ReputationSBT public sbt;
    address[3] public actors;
    uint256 public minted;
    mapping(uint256 tokenId => address) public originalOwner;

    constructor(ReputationSBT sbt_) {
        sbt = sbt_;
        actors = [makeAddr("actor0"), makeAddr("actor1"), makeAddr("actor2")];
    }

    function mint(uint8 who) external {
        address to = actors[who % 3];
        uint256 id = sbt.mint(to); // the handler owns the SBT (it plays the Registry)
        originalOwner[id] = to;
        minted++;
    }

    function transferFrom(uint8 idSeed, uint8 toSeed) external {
        if (minted == 0) return;
        uint256 id = idSeed % minted;
        address from = sbt.ownerOf(id);
        vm.prank(from);
        try sbt.transferFrom(from, actors[toSeed % 3], id) {} catch {}
    }

    function safeTransferFrom(uint8 idSeed, uint8 toSeed) external {
        if (minted == 0) return;
        uint256 id = idSeed % minted;
        address from = sbt.ownerOf(id);
        vm.prank(from);
        try sbt.safeTransferFrom(from, actors[toSeed % 3], id) {} catch {}
    }

    function approveThenTransfer(uint8 idSeed, uint8 toSeed) external {
        if (minted == 0) return;
        uint256 id = idSeed % minted;
        address from = sbt.ownerOf(id);
        address to = actors[toSeed % 3];
        vm.prank(from);
        try sbt.approve(to, id) {} catch {}
        vm.prank(to);
        try sbt.transferFrom(from, to, id) {} catch {}
    }

    function operatorTransfer(uint8 idSeed, uint8 toSeed) external {
        if (minted == 0) return;
        uint256 id = idSeed % minted;
        address from = sbt.ownerOf(id);
        address to = actors[toSeed % 3];
        vm.prank(from);
        sbt.setApprovalForAll(to, true);
        vm.prank(to);
        try sbt.transferFrom(from, to, id) {} catch {}
    }

    function updateLevel(uint8 idSeed, uint256 level, uint256 xp) external {
        if (minted == 0) return;
        sbt.updateLevel(idSeed % minted, level, xp); // allowed for the owner; must not move the token
    }

    function sumBalances() external view returns (uint256 total) {
        for (uint256 i = 0; i < 3; i++) {
            total += sbt.balanceOf(actors[i]);
        }
    }
}

contract SbtInvariant is Test {
    ReputationSBT internal sbt;
    SbtHandler internal handler;

    function setUp() public {
        sbt = new ReputationSBT();
        handler = new SbtHandler(sbt);
        sbt.transferOwnership(address(handler));
        targetContract(address(handler));
    }

    /// A badge never changes hands, whatever anybody tries (transfer, safe transfer, approval,
    /// operator approval).
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_BadgesAreNonTransferable() public view {
        for (uint256 id = 0; id < handler.minted(); id++) {
            assertEq(sbt.ownerOf(id), handler.originalOwner(id));
        }
    }

    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_BalancesAddUpToTheNumberMinted() public view {
        assertEq(handler.sumBalances(), handler.minted());
    }
}

// ---------------------------------------------------------------- 3. the court

/// @dev A minimal Registry for the Court: it opens cases and swallows verdicts.
contract HandlerRegistry is IReportRegistry {
    address public company;
    uint256 public verdicts;

    constructor(address company_) {
        company = company_;
    }

    function programOwnerOf(uint256) external view returns (address) {
        return company;
    }

    function applyVerdict(uint256, bool) external {
        verdicts++;
    }

    function open(DisputeCourt court, uint256 reportId, address hunter, address feePayer) external {
        court.openCase(reportId, hunter, feePayer);
    }
}

contract CourtHandler is Test {
    uint256 public constant MAX_REPORTS = 8;

    DisputeCourt public court;
    BountyToken public token;
    HandlerRegistry public registry;
    address public hunter = makeAddr("hunter");
    address[5] public jurors;

    bool public resolvedWhileVotesWereHidden; // violation flag
    mapping(uint256 caseId => mapping(address juror => bool)) internal _savedVote;

    constructor(DisputeCourt court_, BountyToken token_, HandlerRegistry registry_) {
        court = court_;
        token = token_;
        registry = registry_;
        jurors = [makeAddr("j0"), makeAddr("j1"), makeAddr("j2"), makeAddr("j3"), makeAddr("j4")];
    }

    bool internal _initialized;

    /// @dev Called once by the test after the handler has been given tokens.
    function init() external {
        require(!_initialized, "already initialized"); // the fuzzer must not call this again
        _initialized = true;
        for (uint256 i = 0; i < 5; i++) {
            token.transfer(jurors[i], 1000 ether);
            vm.startPrank(jurors[i]);
            token.approve(address(court), type(uint256).max);
            court.stake(100 ether);
            vm.stopPrank();
        }
        token.transfer(hunter, 2000 ether);
        vm.prank(hunter);
        token.approve(address(court), type(uint256).max);
        token.approve(address(court), type(uint256).max); // for fundReserve from the handler itself
    }

    function _salt(address juror) internal pure returns (bytes32) {
        return keccak256(abi.encode("salt", juror));
    }

    function _reportId(uint256 seed) internal pure returns (uint256) {
        return 1 + (seed % MAX_REPORTS);
    }

    function _caseId(uint256 seed) internal view returns (uint256) {
        uint256 count = court.caseCount();
        if (count == 0) return 0;
        return 1 + (seed % count);
    }

    function payFee(uint256 reportSeed) external {
        vm.prank(hunter);
        try court.payDisputeFee(_reportId(reportSeed)) {} catch {}
    }

    function open(uint256 reportSeed, bool timeout) external {
        try registry.open(court, _reportId(reportSeed), hunter, timeout ? address(0) : hunter) {} catch {}
    }

    function commit(uint256 caseSeed, uint8 jurorIndex, bool vote) external {
        uint256 caseId = _caseId(caseSeed);
        if (caseId == 0) return;
        address juror = jurors[jurorIndex % 5];
        vm.prank(juror);
        try court.commitVote(caseId, keccak256(abi.encode(vote, _salt(juror), juror, caseId))) {
            _savedVote[caseId][juror] = vote;
        } catch {}
    }

    function reveal(uint256 caseSeed, uint8 jurorIndex) external {
        uint256 caseId = _caseId(caseSeed);
        if (caseId == 0) return;
        address juror = jurors[jurorIndex % 5];
        vm.prank(juror);
        try court.revealVote(caseId, _savedVote[caseId][juror], _salt(juror)) {} catch {}
    }

    function warp(uint32 seconds_) external {
        vm.warp(block.timestamp + bound(seconds_, 1, 2 days));
    }

    function resolve(uint256 caseSeed) external {
        uint256 caseId = _caseId(caseSeed);
        if (caseId == 0) return;
        DisputeCourt.Case memory c = court.getCase(caseId);
        bool allowed = c.revealedCount == c.jurors.length || block.timestamp > c.revealDeadline;
        bool wasVoting = c.status == DisputeCourt.CaseStatus.Voting;
        try court.resolveCase(caseId) {
            if (wasVoting && !allowed) resolvedWhileVotesWereHidden = true;
        } catch {}
    }

    function stake(uint8 jurorIndex, uint96 amount) external {
        vm.prank(jurors[jurorIndex % 5]);
        try court.stake(bound(amount, 1, 300 ether)) {} catch {}
    }

    function requestUnstake(uint8 jurorIndex) external {
        vm.prank(jurors[jurorIndex % 5]);
        try court.requestUnstake() {} catch {}
    }

    function withdrawStake(uint8 jurorIndex) external {
        vm.prank(jurors[jurorIndex % 5]);
        try court.withdrawStake() {} catch {}
    }

    function fundReserve(uint96 amount) external {
        try court.fundReserve(bound(amount, 1, 50 ether)) {} catch {}
    }

    /// @dev A whole dispute in one call, so random runs reach the interesting states often.
    function fullCycle(uint256 reportSeed, uint8 voteMask, uint8 revealMask, bool timeout) external {
        uint256 reportId = _reportId(reportSeed);
        if (!timeout) {
            vm.prank(hunter);
            try court.payDisputeFee(reportId) {} catch {}
        }
        try registry.open(court, reportId, hunter, timeout ? address(0) : hunter) {}
        catch {
            return;
        }
        uint256 caseId = court.caseCount();
        address[] memory drawn = court.jurorsOf(caseId);

        for (uint256 i = 0; i < drawn.length; i++) {
            bool vote = (voteMask >> i) & 1 == 1;
            vm.prank(drawn[i]);
            try court.commitVote(caseId, keccak256(abi.encode(vote, _salt(drawn[i]), drawn[i], caseId))) {
                _savedVote[caseId][drawn[i]] = vote;
            } catch {}
        }
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        for (uint256 i = 0; i < drawn.length; i++) {
            if ((revealMask >> i) & 1 == 1) {
                vm.prank(drawn[i]);
                try court.revealVote(caseId, _savedVote[caseId][drawn[i]], _salt(drawn[i])) {} catch {}
            }
        }
        vm.warp(court.getCase(caseId).revealDeadline + 1);
        try court.resolveCase(caseId) {} catch {}
    }

    // views used by the invariants
    function sumStakes() external view returns (uint256 total) {
        for (uint256 i = 0; i < 5; i++) {
            total += court.jurorStake(jurors[i]);
        }
    }

    function sumPrepaid() external view returns (uint256 total) {
        for (uint256 id = 1; id <= MAX_REPORTS; id++) {
            (, uint256 amount) = court.prepaid(id);
            total += amount;
        }
    }

    function sumOpenFees() external view returns (uint256 total) {
        uint256 count = court.caseCount();
        for (uint256 id = 1; id <= count; id++) {
            DisputeCourt.Case memory c = court.getCase(id);
            if (c.status == DisputeCourt.CaseStatus.Voting) total += c.fee;
        }
    }

    function openCasesOf(address juror) external view returns (uint256 total) {
        uint256 count = court.caseCount();
        for (uint256 id = 1; id <= count; id++) {
            DisputeCourt.Case memory c = court.getCase(id);
            if (c.status != DisputeCourt.CaseStatus.Voting) continue;
            for (uint256 i = 0; i < c.jurors.length; i++) {
                if (c.jurors[i] == juror) total++;
            }
        }
    }
}

contract CourtInvariant is Test {
    BountyToken internal token;
    DisputeCourt internal court;
    CourtHandler internal handler;

    function setUp() public {
        token = new BountyToken(1_000_000 ether);
        PlatformTreasury treasury = new PlatformTreasury();
        HandlerRegistry registry = new HandlerRegistry(makeAddr("company"));
        court = new DisputeCourt(
            address(registry),
            address(token),
            address(treasury),
            DisputeCourt.Config({
                jurorsPerCase: 3,
                minStake: 100 ether,
                slashPerJuror: 20 ether,
                disputeFee: 10 ether,
                commitPeriod: 1 hours,
                revealPeriod: 1 hours,
                unstakeCooldown: 1 hours
            })
        );
        handler = new CourtHandler(court, token, registry);
        token.transfer(address(handler), 50_000 ether);
        handler.init();

        targetContract(address(handler));
    }

    /// The Court's token balance is exactly: juror stakes + fees paid in advance + fees held by
    /// open cases + the reserve. Nothing leaks and nothing is created.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_CourtHoldsExactlyWhatItOwes() public view {
        uint256 owed = handler.sumStakes() + handler.sumPrepaid() + handler.sumOpenFees() + court.reserve();
        assertEq(token.balanceOf(address(court)), owed);
    }

    /// A case can never be resolved while votes are still hidden (before every juror has revealed
    /// AND before the reveal window has ended).
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_CasesCannotBeResolvedWhileVotesAreHidden() public view {
        assertFalse(handler.resolvedWhileVotesWereHidden());
    }

    /// A juror's "open cases" counter always equals the number of unresolved cases they sit on,
    /// so nobody is locked forever and nobody can unstake from under an open case.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 40
    function invariant_OpenCaseCountersMatchReality() public view {
        for (uint256 i = 0; i < 5; i++) {
            address juror = handler.jurors(i);
            assertEq(court.activeCases(juror), handler.openCasesOf(juror));
        }
    }
}
