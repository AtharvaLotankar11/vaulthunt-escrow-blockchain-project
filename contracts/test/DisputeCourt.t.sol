// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";
import {BountyToken} from "../src/BountyToken.sol";
import {PlatformTreasury} from "../src/PlatformTreasury.sol";
import {IReportRegistry} from "../src/interfaces/IReportRegistry.sol";

/// @dev Stands in for the ReportRegistry: it is the only address allowed to open cases, and it
///      records the verdicts the Court sends back.
contract MockRegistry is IReportRegistry {
    mapping(uint256 reportId => address) public owners;
    uint256 public verdictCalls;
    uint256 public lastReportId;
    bool public lastHunterWins;
    bool public revertOnVerdict;

    function setOwner(uint256 reportId, address owner_) external {
        owners[reportId] = owner_;
    }

    function setRevertOnVerdict(bool value) external {
        revertOnVerdict = value;
    }

    function programOwnerOf(uint256 reportId) external view returns (address) {
        return owners[reportId];
    }

    function applyVerdict(uint256 reportId, bool hunterWins) external {
        require(!revertOnVerdict, "MockRegistry: reverting");
        verdictCalls++;
        lastReportId = reportId;
        lastHunterWins = hunterWins;
    }

    function open(DisputeCourt court, uint256 reportId, address hunter, address feePayer) external {
        court.openCase(reportId, hunter, feePayer);
    }
}

contract DisputeCourtTest is Test {
    BountyToken internal token;
    PlatformTreasury internal treasury;
    MockRegistry internal mockRegistry;
    DisputeCourt internal court;

    address internal hunter = makeAddr("hunter");
    address internal company = makeAddr("company");
    address internal stranger = makeAddr("stranger");
    address[] internal jurors;

    uint256 internal constant REPORT = 1;
    uint256 internal constant MIN_STAKE = 100 ether;
    uint256 internal constant SLASH = 20 ether;
    uint256 internal constant FEE = 10 ether;
    uint64 internal constant COMMIT = 1 days;
    uint64 internal constant REVEAL = 1 days;
    uint64 internal constant COOLDOWN = 3 days;

    function _config(uint256 perCase) internal pure returns (DisputeCourt.Config memory) {
        return DisputeCourt.Config({
            jurorsPerCase: perCase,
            minStake: MIN_STAKE,
            slashPerJuror: SLASH,
            disputeFee: FEE,
            commitPeriod: COMMIT,
            revealPeriod: REVEAL,
            unstakeCooldown: COOLDOWN
        });
    }

    function setUp() public {
        token = new BountyToken(1_000_000 ether);
        treasury = new PlatformTreasury();
        mockRegistry = new MockRegistry();
        court = new DisputeCourt(address(mockRegistry), address(token), address(treasury), _config(3));

        for (uint256 i = 0; i < 7; i++) {
            address juror = makeAddr(string.concat("juror", vm.toString(i)));
            jurors.push(juror);
            _fundAndStake(court, juror, MIN_STAKE);
        }

        _fund(hunter, 1000 ether);
        _fund(stranger, 1000 ether);
        mockRegistry.setOwner(REPORT, company);
    }

    // ------------------------------------------------------------------ helpers

    function _fund(address who, uint256 amount) internal {
        token.transfer(who, amount);
        vm.prank(who);
        token.approve(address(court), type(uint256).max);
    }

    function _fundAndStake(DisputeCourt target, address juror, uint256 amount) internal {
        token.transfer(juror, 1000 ether);
        vm.startPrank(juror);
        token.approve(address(target), type(uint256).max);
        target.stake(amount);
        vm.stopPrank();
    }

    /// @dev Rejection path: the hunter pays the fee, then the Registry opens the case.
    function _open(uint256 reportId) internal returns (uint256 caseId) {
        mockRegistry.setOwner(reportId, company);
        vm.prank(hunter);
        court.payDisputeFee(reportId);
        mockRegistry.open(court, reportId, hunter, hunter);
        caseId = court.caseCount();
    }

    /// @dev Timeout path: nobody pays a fee.
    function _openTimeout(uint256 reportId) internal returns (uint256 caseId) {
        mockRegistry.setOwner(reportId, company);
        mockRegistry.open(court, reportId, hunter, address(0));
        caseId = court.caseCount();
    }

    function _salt(address juror) internal pure returns (bytes32) {
        return keccak256(abi.encode("salt", juror));
    }

    function _voteHash(bool hunterWins, address juror, uint256 caseId) internal pure returns (bytes32) {
        return keccak256(abi.encode(hunterWins, _salt(juror), juror, caseId));
    }

    function _commitAll(uint256 caseId, bool[3] memory votes) internal {
        address[] memory js = court.jurorsOf(caseId);
        for (uint256 i = 0; i < js.length; i++) {
            vm.prank(js[i]);
            court.commitVote(caseId, _voteHash(votes[i], js[i], caseId));
        }
    }

    function _toRevealPhase(uint256 caseId) internal {
        vm.warp(court.getCase(caseId).commitDeadline + 1);
    }

    function _reveal(uint256 caseId, uint256 index, bool vote) internal {
        address juror = court.jurorsOf(caseId)[index];
        vm.prank(juror);
        court.revealVote(caseId, vote, _salt(juror));
    }

    /// @dev Everyone commits and reveals the given votes.
    function _voteAll(uint256 caseId, bool[3] memory votes) internal {
        _commitAll(caseId, votes);
        _toRevealPhase(caseId);
        for (uint256 i = 0; i < 3; i++) {
            _reveal(caseId, i, votes[i]);
        }
    }

    function _stakeOf(uint256 caseId, uint256 index) internal view returns (uint256) {
        return court.jurorStake(court.jurorsOf(caseId)[index]);
    }

    function _contains(address[] memory list, address who) internal pure returns (bool) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == who) return true;
        }
        return false;
    }

    // ------------------------------------------------------------------ constructor

    function testConstructorStoresConfiguration() public view {
        assertEq(court.registry(), address(mockRegistry));
        assertEq(address(court.token()), address(token));
        assertEq(court.treasury(), address(treasury));
        assertEq(court.jurorsPerCase(), 3);
        assertEq(court.minStake(), MIN_STAKE);
        assertEq(court.slashPerJuror(), SLASH);
        assertEq(court.disputeFee(), FEE);
        assertEq(court.commitPeriod(), COMMIT);
        assertEq(court.revealPeriod(), REVEAL);
        assertEq(court.unstakeCooldown(), COOLDOWN);
        assertEq(court.poolSize(), 7);
    }

    function testConstructorRejectsBadConfiguration() public {
        DisputeCourt.Config memory cfg = _config(3);

        vm.expectRevert("DisputeCourt: registry is zero address");
        new DisputeCourt(address(0), address(token), address(treasury), cfg);

        vm.expectRevert("DisputeCourt: token is zero address");
        new DisputeCourt(address(mockRegistry), address(0), address(treasury), cfg);

        cfg.jurorsPerCase = 0;
        vm.expectRevert("DisputeCourt: jurors per case is zero");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);

        cfg = _config(3);
        cfg.minStake = 0;
        vm.expectRevert("DisputeCourt: min stake is zero");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);

        cfg = _config(3);
        cfg.slashPerJuror = MIN_STAKE + 1;
        vm.expectRevert("DisputeCourt: slash above min stake");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);

        cfg = _config(3);
        cfg.commitPeriod = 0;
        vm.expectRevert("DisputeCourt: period is zero");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);

        cfg = _config(3);
        cfg.revealPeriod = 0;
        vm.expectRevert("DisputeCourt: period is zero");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);

        cfg = _config(3);
        cfg.unstakeCooldown = 0;
        vm.expectRevert("DisputeCourt: period is zero");
        new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);
    }

    function testTreasuryMayBeZeroAddress() public {
        DisputeCourt noTreasury = new DisputeCourt(address(mockRegistry), address(token), address(0), _config(3));
        assertEq(noTreasury.treasury(), address(0));
    }

    // ------------------------------------------------------------------ staking

    function testStakeMovesTokensAndJoinsPool() public {
        address newJuror = makeAddr("newJuror");
        token.transfer(newJuror, 500 ether);
        vm.startPrank(newJuror);
        token.approve(address(court), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit DisputeCourt.Staked(newJuror, 150 ether, 150 ether);
        court.stake(150 ether);
        vm.stopPrank();

        assertEq(court.jurorStake(newJuror), 150 ether);
        assertTrue(court.isInPool(newJuror));
        assertEq(court.poolSize(), 8);
        assertEq(token.balanceOf(newJuror), 350 ether);
        assertEq(token.balanceOf(address(court)), 7 * MIN_STAKE + 150 ether);
    }

    function testStakeBelowMinimumJoinsPoolOnlyAfterTopUp() public {
        address newJuror = makeAddr("newJuror");
        token.transfer(newJuror, 500 ether);
        vm.startPrank(newJuror);
        token.approve(address(court), type(uint256).max);

        court.stake(60 ether);
        assertFalse(court.isInPool(newJuror));
        assertEq(court.poolSize(), 7);

        court.stake(40 ether);
        assertTrue(court.isInPool(newJuror));
        assertEq(court.poolSize(), 8);
        vm.stopPrank();
    }

    function testStakeZeroReverts() public {
        vm.prank(jurors[0]);
        vm.expectRevert("DisputeCourt: stake is zero");
        court.stake(0);
    }

    function testStakeWithoutAllowanceReverts() public {
        address newJuror = makeAddr("newJuror");
        token.transfer(newJuror, 500 ether);
        vm.prank(newJuror);
        vm.expectRevert();
        court.stake(100 ether);
        assertEq(court.jurorStake(newJuror), 0);
        assertFalse(court.isInPool(newJuror));
    }

    function testStakeWhileUnstakePendingReverts() public {
        vm.startPrank(jurors[0]);
        court.requestUnstake();
        vm.expectRevert("DisputeCourt: unstake pending");
        court.stake(1 ether);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------ unstaking

    function testRequestUnstakeLeavesPoolAndStartsCooldown() public {
        vm.expectEmit(true, false, false, true);
        emit DisputeCourt.UnstakeRequested(jurors[0], block.timestamp + COOLDOWN);
        vm.prank(jurors[0]);
        court.requestUnstake();

        assertFalse(court.isInPool(jurors[0]));
        assertEq(court.poolSize(), 6);
        assertTrue(court.unstakePending(jurors[0]));
        assertEq(court.unstakeAt(jurors[0]), block.timestamp + COOLDOWN);
    }

    function testWithdrawAfterCooldownReturnsTheStake() public {
        uint256 before = token.balanceOf(jurors[0]);
        vm.prank(jurors[0]);
        court.requestUnstake();

        vm.warp(block.timestamp + COOLDOWN);
        vm.expectEmit(true, false, false, true);
        emit DisputeCourt.StakeWithdrawn(jurors[0], MIN_STAKE);
        vm.prank(jurors[0]);
        court.withdrawStake();

        assertEq(token.balanceOf(jurors[0]), before + MIN_STAKE);
        assertEq(court.jurorStake(jurors[0]), 0);
        assertFalse(court.unstakePending(jurors[0]));
    }

    function testWithdrawBeforeCooldownReverts() public {
        vm.startPrank(jurors[0]);
        court.requestUnstake();
        vm.warp(block.timestamp + COOLDOWN - 1);
        vm.expectRevert("DisputeCourt: cooldown not finished");
        court.withdrawStake();
        vm.stopPrank();
    }

    function testWithdrawWithoutRequestReverts() public {
        vm.prank(jurors[0]);
        vm.expectRevert("DisputeCourt: unstake not requested");
        court.withdrawStake();
    }

    function testRequestUnstakeWithNothingStakedReverts() public {
        vm.prank(stranger);
        vm.expectRevert("DisputeCourt: nothing staked");
        court.requestUnstake();
    }

    function testRequestUnstakeTwiceReverts() public {
        vm.startPrank(jurors[0]);
        court.requestUnstake();
        vm.expectRevert("DisputeCourt: unstake already requested");
        court.requestUnstake();
        vm.stopPrank();
    }

    function testSelectedJurorCannotUnstakeWhileCaseIsOpen() public {
        uint256 caseId = _open(REPORT);
        address selected = court.jurorsOf(caseId)[0];
        vm.prank(selected);
        vm.expectRevert("DisputeCourt: juror has open cases");
        court.requestUnstake();
    }

    // ------------------------------------------------------------------ reserve and fees

    function testFundReserve() public {
        vm.expectEmit(true, false, false, true);
        emit DisputeCourt.ReserveFunded(stranger, 50 ether);
        vm.prank(stranger);
        court.fundReserve(50 ether);
        assertEq(court.reserve(), 50 ether);
    }

    function testFundReserveZeroReverts() public {
        vm.expectRevert("DisputeCourt: amount is zero");
        court.fundReserve(0);
    }

    function testPayDisputeFeePullsFromTheCallerOnly() public {
        uint256 before = token.balanceOf(hunter);
        vm.expectEmit(true, true, false, true);
        emit DisputeCourt.DisputeFeePaid(REPORT, hunter, FEE);
        vm.prank(hunter);
        court.payDisputeFee(REPORT);

        assertEq(token.balanceOf(hunter), before - FEE);
        (address payer, uint256 amount) = court.prepaid(REPORT);
        assertEq(payer, hunter);
        assertEq(amount, FEE);
    }

    function testPayDisputeFeeTwiceReverts() public {
        vm.startPrank(hunter);
        court.payDisputeFee(REPORT);
        vm.expectRevert("DisputeCourt: fee already paid");
        court.payDisputeFee(REPORT);
        vm.stopPrank();
    }

    function testPayDisputeFeeWhenNoFeeConfiguredReverts() public {
        DisputeCourt.Config memory cfg = _config(3);
        cfg.disputeFee = 0;
        DisputeCourt freeCourt = new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);
        vm.expectRevert("DisputeCourt: no dispute fee");
        freeCourt.payDisputeFee(REPORT);
    }

    function testPayDisputeFeeAfterCaseOpenedReverts() public {
        _open(REPORT);
        vm.prank(hunter);
        vm.expectRevert("DisputeCourt: report already has a case");
        court.payDisputeFee(REPORT);
    }

    function testRefundDisputeFee() public {
        uint256 before = token.balanceOf(hunter);
        vm.startPrank(hunter);
        court.payDisputeFee(REPORT);

        vm.expectEmit(true, true, false, true);
        emit DisputeCourt.DisputeFeeRefunded(REPORT, hunter, FEE);
        court.refundDisputeFee(REPORT);
        vm.stopPrank();

        assertEq(token.balanceOf(hunter), before);
        (, uint256 amount) = court.prepaid(REPORT);
        assertEq(amount, 0);
    }

    function testRefundDisputeFeeByAnotherAddressReverts() public {
        vm.prank(hunter);
        court.payDisputeFee(REPORT);
        vm.prank(stranger);
        vm.expectRevert("DisputeCourt: no fee to refund");
        court.refundDisputeFee(REPORT);
    }

    function testRefundDisputeFeeAfterCaseOpenedReverts() public {
        _open(REPORT);
        vm.prank(hunter);
        vm.expectRevert("DisputeCourt: no fee to refund"); // the fee moved into the case
        court.refundDisputeFee(REPORT);
    }

    // ------------------------------------------------------------------ openCase

    function testOnlyRegistryCanOpenCase() public {
        vm.prank(stranger);
        vm.expectRevert("DisputeCourt: caller is not the registry");
        court.openCase(REPORT, hunter, hunter);
    }

    function testOpenCaseDrawsDistinctPoolJurors() public {
        vm.prank(hunter);
        court.payDisputeFee(REPORT);

        uint256 courtBalance = token.balanceOf(address(court));
        mockRegistry.open(court, REPORT, hunter, hunter);

        DisputeCourt.Case memory c = court.getCase(1);
        assertEq(c.reportId, REPORT);
        assertEq(c.hunter, hunter);
        assertEq(c.programOwner, company);
        assertFalse(c.byTimeout);
        assertTrue(c.status == DisputeCourt.CaseStatus.Voting);
        assertEq(c.fee, FEE);
        assertEq(c.commitDeadline, c.openedAt + COMMIT);
        assertEq(c.revealDeadline, c.commitDeadline + REVEAL);
        assertEq(c.jurors.length, 3);
        assertEq(court.caseOfReport(REPORT), 1);
        assertEq(token.balanceOf(address(court)), courtBalance); // the fee was already inside

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(court.isInPool(c.jurors[i]));
            assertEq(court.activeCases(c.jurors[i]), 1);
            assertTrue(court.voteInfo(1, c.jurors[i]).selected);
            for (uint256 j = i + 1; j < 3; j++) {
                assertTrue(c.jurors[i] != c.jurors[j]);
            }
        }
        (address payer, uint256 amount) = court.prepaid(REPORT);
        assertEq(payer, address(0)); // prepaid record consumed
        assertEq(amount, 0);
    }

    function testHunterAndCompanyAreNeverSelected() public {
        // both stake as jurors too, so they are in the pool and must be skipped
        _fundAndStake(court, hunter, MIN_STAKE);
        _fundAndStake(court, company, MIN_STAKE);
        assertEq(court.poolSize(), 9);

        for (uint256 r = 1; r <= 12; r++) {
            vm.prevrandao(bytes32(r));
            uint256 caseId = _open(r);
            address[] memory js = court.jurorsOf(caseId);
            assertFalse(_contains(js, hunter));
            assertFalse(_contains(js, company));
        }
    }

    function testNotEnoughEligibleJurorsReverts() public {
        DisputeCourt small = new DisputeCourt(address(mockRegistry), address(token), address(treasury), _config(3));
        _fundAndStake(small, jurors[0], MIN_STAKE);
        _fundAndStake(small, jurors[1], MIN_STAKE);
        _fundAndStake(small, hunter, MIN_STAKE); // pool of 3, but the hunter cannot judge their own case

        vm.startPrank(hunter);
        token.approve(address(small), type(uint256).max);
        small.payDisputeFee(REPORT);
        vm.stopPrank();

        vm.expectRevert("DisputeCourt: not enough eligible jurors");
        mockRegistry.open(small, REPORT, hunter, hunter);

        // nothing was consumed: the hunter can still take the fee back
        vm.prank(hunter);
        small.refundDisputeFee(REPORT);
    }

    function testOpenCaseRequiresTheHunterToHavePaid() public {
        vm.expectRevert("DisputeCourt: dispute fee not paid");
        mockRegistry.open(court, REPORT, hunter, hunter);
    }

    function testFeePaidBySomeoneElseDoesNotCount() public {
        vm.prank(stranger);
        court.payDisputeFee(REPORT); // a third party paid, not the hunter
        vm.expectRevert("DisputeCourt: dispute fee not paid");
        mockRegistry.open(court, REPORT, hunter, hunter);
    }

    function testOpenCaseTwiceForSameReportReverts() public {
        _open(REPORT);
        vm.expectRevert("DisputeCourt: report already has a case");
        mockRegistry.open(court, REPORT, hunter, address(0));
    }

    function testTimeoutCaseIsPaidFromTheReserve() public {
        vm.prank(stranger);
        court.fundReserve(50 ether);

        uint256 caseId = _openTimeout(REPORT);
        DisputeCourt.Case memory c = court.getCase(caseId);
        assertTrue(c.byTimeout);
        assertEq(c.fee, FEE);
        assertEq(court.reserve(), 40 ether);
    }

    function testTimeoutCaseWithSmallReserveGetsWhatIsThere() public {
        vm.prank(stranger);
        court.fundReserve(4 ether);
        uint256 caseId = _openTimeout(REPORT);
        assertEq(court.getCase(caseId).fee, 4 ether);
        assertEq(court.reserve(), 0);
    }

    function testTimeoutCaseWithEmptyReserveHasNoFee() public {
        uint256 caseId = _openTimeout(REPORT);
        assertEq(court.getCase(caseId).fee, 0);
        assertEq(court.reserve(), 0);
    }

    function testTimeoutCaseUsesAPrepaidFeeBeforeTheReserve() public {
        vm.prank(stranger);
        court.fundReserve(50 ether);
        vm.prank(hunter);
        court.payDisputeFee(REPORT);

        mockRegistry.setOwner(REPORT, company);
        mockRegistry.open(court, REPORT, hunter, address(0));

        assertEq(court.getCase(1).fee, FEE);
        assertEq(court.reserve(), 50 ether); // untouched
    }

    function testDifferentRandomnessDrawsDifferentJurors() public {
        bytes32 firstSet;
        bool differs;
        for (uint256 r = 1; r <= 8; r++) {
            vm.prevrandao(bytes32(r * 7919));
            uint256 caseId = _open(r);
            address[] memory js = court.jurorsOf(caseId);
            bytes32 setId = keccak256(abi.encode(_sorted(js)));
            if (r == 1) firstSet = setId;
            else if (setId != firstSet) differs = true;
        }
        assertTrue(differs);
    }

    function _sorted(address[] memory input) internal pure returns (address[] memory) {
        for (uint256 i = 0; i < input.length; i++) {
            for (uint256 j = i + 1; j < input.length; j++) {
                if (input[j] < input[i]) (input[i], input[j]) = (input[j], input[i]);
            }
        }
        return input;
    }

    // ------------------------------------------------------------------ commit

    function testCommitVoteStoresTheHash() public {
        uint256 caseId = _open(REPORT);
        address juror = court.jurorsOf(caseId)[0];
        bytes32 hash = _voteHash(true, juror, caseId);

        vm.expectEmit(true, true, false, false);
        emit DisputeCourt.VoteCommitted(caseId, juror);
        vm.prank(juror);
        court.commitVote(caseId, hash);

        assertTrue(court.voteInfo(caseId, juror).committed);
        assertEq(court.voteInfo(caseId, juror).commitHash, hash);
    }

    function testNonJurorCannotCommit() public {
        uint256 caseId = _open(REPORT);
        vm.prank(stranger);
        vm.expectRevert("DisputeCourt: not a juror in this case");
        court.commitVote(caseId, keccak256("x"));
    }

    function testCommitTwiceReverts() public {
        uint256 caseId = _open(REPORT);
        address juror = court.jurorsOf(caseId)[0];
        vm.startPrank(juror);
        court.commitVote(caseId, keccak256("a"));
        vm.expectRevert("DisputeCourt: already committed");
        court.commitVote(caseId, keccak256("b"));
        vm.stopPrank();
    }

    function testCommitAfterWindowReverts() public {
        uint256 caseId = _open(REPORT);
        address juror = court.jurorsOf(caseId)[0];
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: commit window closed");
        court.commitVote(caseId, keccak256("a"));
    }

    function testCommitAtExactDeadlineStillWorks() public {
        uint256 caseId = _open(REPORT);
        address juror = court.jurorsOf(caseId)[0];
        vm.warp(court.getCase(caseId).commitDeadline);
        vm.prank(juror);
        court.commitVote(caseId, keccak256("a"));
    }

    function testCommitEmptyHashReverts() public {
        uint256 caseId = _open(REPORT);
        address juror = court.jurorsOf(caseId)[0];
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: empty vote hash");
        court.commitVote(caseId, bytes32(0));
    }

    function testCommitOnUnknownCaseReverts() public {
        vm.prank(jurors[0]);
        vm.expectRevert("DisputeCourt: case is not open for voting");
        court.commitVote(99, keccak256("a"));
    }

    // ------------------------------------------------------------------ reveal

    function testRevealCountsTheVote() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, false, true]);
        _toRevealPhase(caseId);

        address juror = court.jurorsOf(caseId)[0];
        vm.expectEmit(true, true, false, true);
        emit DisputeCourt.VoteRevealed(caseId, juror, true);
        _reveal(caseId, 0, true);

        DisputeCourt.Case memory c = court.getCase(caseId);
        assertEq(c.hunterVotes, 1);
        assertEq(c.companyVotes, 0);
        assertEq(c.revealedCount, 1);
        assertTrue(court.voteInfo(caseId, juror).revealed);
        assertTrue(court.voteInfo(caseId, juror).hunterWins);
    }

    function testRevealDuringCommitWindowReverts() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        vm.warp(court.getCase(caseId).commitDeadline); // still the commit window
        address juror = court.jurorsOf(caseId)[0];
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: reveal window not open yet");
        court.revealVote(caseId, true, _salt(juror));
    }

    function testRevealWithWrongVoteOrSaltReverts() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        _toRevealPhase(caseId);
        address juror = court.jurorsOf(caseId)[0];

        vm.startPrank(juror);
        vm.expectRevert("DisputeCourt: reveal does not match commit");
        court.revealVote(caseId, false, _salt(juror)); // changed vote
        vm.expectRevert("DisputeCourt: reveal does not match commit");
        court.revealVote(caseId, true, keccak256("wrong")); // wrong salt
        vm.stopPrank();
    }

    function testRevealWithoutCommitReverts() public {
        uint256 caseId = _open(REPORT);
        _toRevealPhase(caseId);
        address juror = court.jurorsOf(caseId)[0];
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: no vote committed");
        court.revealVote(caseId, true, _salt(juror));
    }

    function testRevealTwiceReverts() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        _toRevealPhase(caseId);
        _reveal(caseId, 0, true);
        address juror = court.jurorsOf(caseId)[0];
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: already revealed");
        court.revealVote(caseId, true, _salt(juror));
    }

    function testNonJurorCannotReveal() public {
        uint256 caseId = _open(REPORT);
        _toRevealPhase(caseId);
        vm.prank(stranger);
        vm.expectRevert("DisputeCourt: not a juror in this case");
        court.revealVote(caseId, true, keccak256("x"));
    }

    function testRevealAfterWindowReverts() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        vm.warp(court.getCase(caseId).revealDeadline + 1);
        address juror = court.jurorsOf(caseId)[0];
        vm.prank(juror);
        vm.expectRevert("DisputeCourt: reveal window closed");
        court.revealVote(caseId, true, _salt(juror));
    }

    function testRevealOnUnknownCaseReverts() public {
        vm.prank(jurors[0]);
        vm.expectRevert("DisputeCourt: case is not open for voting");
        court.revealVote(99, true, keccak256("x"));
    }

    // ------------------------------------------------------------------ resolve

    function testUnanimousForTheHunter() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, true]);

        uint256 treasuryBefore = token.balanceOf(address(treasury));
        court.resolveCase(caseId);

        // pot = the 10 BBT fee, split three ways: 3.33.. each and 1 wei of dust to the treasury
        uint256 share = FEE / 3;
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_stakeOf(caseId, i), MIN_STAKE + share);
            assertEq(court.activeCases(court.jurorsOf(caseId)[i]), 0);
        }
        assertEq(token.balanceOf(address(treasury)) - treasuryBefore, FEE - 3 * share);

        assertTrue(court.getCase(caseId).status == DisputeCourt.CaseStatus.Resolved);
        assertTrue(court.getCase(caseId).hunterWins);
        assertEq(mockRegistry.verdictCalls(), 1);
        assertEq(mockRegistry.lastReportId(), REPORT);
        assertTrue(mockRegistry.lastHunterWins());
    }

    function testTwoToOneSplitSlashesTheMinority() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, false]);
        uint256 poolBefore = court.poolSize();

        vm.expectEmit(true, true, false, true);
        emit DisputeCourt.CaseResolved(caseId, REPORT, true, 2, 1);
        court.resolveCase(caseId);

        // pot = 10 fee + 20 slashed = 30, so each of the two winners gets 15
        assertEq(_stakeOf(caseId, 0), MIN_STAKE + 15 ether);
        assertEq(_stakeOf(caseId, 1), MIN_STAKE + 15 ether);
        assertEq(_stakeOf(caseId, 2), MIN_STAKE - SLASH);
        assertTrue(mockRegistry.lastHunterWins());

        // the slashed juror fell below the minimum and left the pool
        assertEq(court.poolSize(), poolBefore - 1);
        assertFalse(court.isInPool(court.jurorsOf(caseId)[2]));
    }

    function testMajorityForTheCompany() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [false, true, false]);
        court.resolveCase(caseId);
        assertFalse(mockRegistry.lastHunterWins());
        assertEq(_stakeOf(caseId, 0), MIN_STAKE + 15 ether);
        assertEq(_stakeOf(caseId, 1), MIN_STAKE - SLASH);
    }

    function testTieAfterARejectionGoesToTheCompany() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, false, true]);
        _toRevealPhase(caseId);
        _reveal(caseId, 0, true); // hunter side
        _reveal(caseId, 1, false); // company side
        // juror 2 never reveals

        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId);

        assertFalse(mockRegistry.lastHunterWins()); // 1-1 tie, rejection case: company wins
        // coherent: only juror 1. Slashed: jurors 0 and 2. Pot = 10 + 20 + 20 = 50
        assertEq(_stakeOf(caseId, 1), MIN_STAKE + 50 ether);
        assertEq(_stakeOf(caseId, 0), MIN_STAKE - SLASH);
        assertEq(_stakeOf(caseId, 2), MIN_STAKE - SLASH);
    }

    function testTieAfterACompanyTimeoutGoesToTheHunter() public {
        vm.prank(stranger);
        court.fundReserve(FEE);
        uint256 caseId = _openTimeout(REPORT);

        _commitAll(caseId, [true, false, true]);
        _toRevealPhase(caseId);
        _reveal(caseId, 0, true);
        _reveal(caseId, 1, false);

        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId);

        assertTrue(mockRegistry.lastHunterWins()); // tie, timeout case: the silent company loses
        assertEq(_stakeOf(caseId, 0), MIN_STAKE + 50 ether);
    }

    function testNobodyRevealsEveryJurorIsSlashedAndTheTreasuryGetsThePot() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        vm.warp(court.getCase(caseId).revealDeadline + 1);

        uint256 treasuryBefore = token.balanceOf(address(treasury));
        court.resolveCase(caseId);

        assertFalse(mockRegistry.lastHunterWins()); // tie, rejection case
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_stakeOf(caseId, i), MIN_STAKE - SLASH);
        }
        assertEq(token.balanceOf(address(treasury)) - treasuryBefore, FEE + 3 * SLASH);
    }

    function testNobodyRevealsWithoutTreasuryFeedsTheReserve() public {
        DisputeCourt noTreasury = new DisputeCourt(address(mockRegistry), address(token), address(0), _config(3));
        for (uint256 i = 0; i < 3; i++) {
            _fundAndStake(noTreasury, jurors[i], MIN_STAKE);
        }
        vm.startPrank(hunter);
        token.approve(address(noTreasury), type(uint256).max);
        noTreasury.payDisputeFee(REPORT);
        vm.stopPrank();
        mockRegistry.setOwner(REPORT, company);
        mockRegistry.open(noTreasury, REPORT, hunter, hunter);

        vm.warp(noTreasury.getCase(1).revealDeadline + 1);
        noTreasury.resolveCase(1);
        assertEq(noTreasury.reserve(), FEE + 3 * SLASH);
    }

    function testResolveEarlyWhenEveryJurorHasRevealed() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, true]);
        assertLt(block.timestamp, court.getCase(caseId).revealDeadline);
        court.resolveCase(caseId); // no waiting needed
        assertTrue(court.getCase(caseId).status == DisputeCourt.CaseStatus.Resolved);
    }

    function testResolveTooEarlyReverts() public {
        uint256 caseId = _open(REPORT);
        _commitAll(caseId, [true, true, true]);
        _toRevealPhase(caseId);
        _reveal(caseId, 0, true);
        _reveal(caseId, 1, true);

        vm.expectRevert("DisputeCourt: voting still in progress");
        court.resolveCase(caseId);

        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId); // now fine, juror 2 is slashed
        assertEq(_stakeOf(caseId, 2), MIN_STAKE - SLASH);
    }

    function testResolveTwiceReverts() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, true]);
        court.resolveCase(caseId);
        vm.expectRevert("DisputeCourt: case is not open for voting");
        court.resolveCase(caseId);
    }

    function testResolveUnknownCaseReverts() public {
        vm.expectRevert("DisputeCourt: case is not open for voting");
        court.resolveCase(42);
    }

    function testAnyoneCanResolve() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, true]);
        vm.prank(stranger);
        court.resolveCase(caseId);
        assertEq(mockRegistry.verdictCalls(), 1);
    }

    function testResolveIsAtomicWhenTheRegistryReverts() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, false]);
        mockRegistry.setRevertOnVerdict(true);

        vm.expectRevert("MockRegistry: reverting");
        court.resolveCase(caseId);

        // nothing happened: still open, nobody paid or slashed yet
        assertTrue(court.getCase(caseId).status == DisputeCourt.CaseStatus.Voting);
        assertEq(_stakeOf(caseId, 2), MIN_STAKE);

        mockRegistry.setRevertOnVerdict(false);
        court.resolveCase(caseId);
        assertEq(_stakeOf(caseId, 2), MIN_STAKE - SLASH);
    }

    function testJurorsCanCollectRewardsAfterTheCase() public {
        uint256 caseId = _open(REPORT);
        _voteAll(caseId, [true, true, false]);
        court.resolveCase(caseId);

        address winner = court.jurorsOf(caseId)[0];
        uint256 before = token.balanceOf(winner);

        vm.startPrank(winner);
        court.requestUnstake();
        vm.warp(block.timestamp + COOLDOWN);
        court.withdrawStake();
        vm.stopPrank();

        assertEq(token.balanceOf(winner) - before, MIN_STAKE + 15 ether);
    }

    function testFiveJurorsThreeToTwoSplit() public {
        DisputeCourt five = new DisputeCourt(address(mockRegistry), address(token), address(treasury), _config(5));
        for (uint256 i = 0; i < 7; i++) {
            _fundAndStake(five, jurors[i], MIN_STAKE);
        }
        vm.startPrank(hunter);
        token.approve(address(five), type(uint256).max);
        five.payDisputeFee(REPORT);
        vm.stopPrank();
        mockRegistry.setOwner(REPORT, company);
        mockRegistry.open(five, REPORT, hunter, hunter);

        address[] memory js = five.jurorsOf(1);
        assertEq(js.length, 5);
        bool[5] memory votes = [true, true, true, false, false];
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(js[i]);
            five.commitVote(1, keccak256(abi.encode(votes[i], _salt(js[i]), js[i], uint256(1))));
        }
        vm.warp(five.getCase(1).commitDeadline + 1);
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(js[i]);
            five.revealVote(1, votes[i], _salt(js[i]));
        }

        uint256 treasuryBefore = token.balanceOf(address(treasury));
        five.resolveCase(1);

        // pot = 10 + 2*20 = 50 shared by 3 winners; the remainder (2 wei) goes to the treasury
        uint256 pot = 50 ether;
        uint256 share = pot / 3;
        for (uint256 i = 0; i < 3; i++) {
            assertEq(five.jurorStake(js[i]), MIN_STAKE + share);
        }
        assertEq(five.jurorStake(js[3]), MIN_STAKE - SLASH);
        assertEq(token.balanceOf(address(treasury)) - treasuryBefore, pot - 3 * share);
        assertTrue(mockRegistry.lastHunterWins());
    }

    function testSlashIsCappedAtTheJurorsRemainingStake() public {
        // slash 80 of a 100 minimum: a juror caught in two cases is slashed 80, then only 20
        DisputeCourt.Config memory cfg = _config(3);
        cfg.slashPerJuror = 80 ether;
        DisputeCourt harsh = new DisputeCourt(address(mockRegistry), address(token), address(treasury), cfg);
        for (uint256 i = 0; i < 3; i++) {
            _fundAndStake(harsh, jurors[i], MIN_STAKE);
        }
        vm.startPrank(hunter);
        token.approve(address(harsh), type(uint256).max);
        harsh.payDisputeFee(1);
        harsh.payDisputeFee(2);
        vm.stopPrank();
        mockRegistry.setOwner(1, company);
        mockRegistry.setOwner(2, company);
        mockRegistry.open(harsh, 1, hunter, hunter);
        mockRegistry.open(harsh, 2, hunter, hunter);

        address minority = harsh.jurorsOf(1)[0]; // the same juror is outvoted in both cases
        for (uint256 caseId = 1; caseId <= 2; caseId++) {
            address[] memory js = harsh.jurorsOf(caseId);
            for (uint256 i = 0; i < 3; i++) {
                vm.prank(js[i]);
                harsh.commitVote(caseId, keccak256(abi.encode(js[i] == minority, _salt(js[i]), js[i], caseId)));
            }
        }
        vm.warp(harsh.getCase(2).commitDeadline + 1);
        for (uint256 caseId = 1; caseId <= 2; caseId++) {
            address[] memory js = harsh.jurorsOf(caseId);
            for (uint256 i = 0; i < 3; i++) {
                vm.prank(js[i]);
                harsh.revealVote(caseId, js[i] == minority, _salt(js[i]));
            }
        }

        harsh.resolveCase(1);
        assertEq(harsh.jurorStake(minority), 20 ether); // 100 - 80
        harsh.resolveCase(2);
        assertEq(harsh.jurorStake(minority), 0); // only 20 left to take, so the slash is capped
        assertFalse(harsh.isInPool(minority));
    }

    // ------------------------------------------------------------------ conservation

    function _trackedTokens(address[] memory who, uint256[] memory openCases) internal view returns (uint256 total) {
        for (uint256 i = 0; i < who.length; i++) {
            total += court.jurorStake(who[i]);
        }
        for (uint256 i = 0; i < openCases.length; i++) {
            DisputeCourt.Case memory c = court.getCase(openCases[i]);
            if (c.status == DisputeCourt.CaseStatus.Voting) total += c.fee;
        }
        total += court.reserve();
    }

    function testCourtHoldsExactlyStakesPlusOpenFeesPlusReserve() public {
        vm.prank(stranger);
        court.fundReserve(25 ether);
        uint256 a = _open(1);
        uint256 b = _openTimeout(2);
        uint256[] memory cases = new uint256[](2);
        cases[0] = a;
        cases[1] = b;
        address[] memory who = new address[](jurors.length);
        for (uint256 i = 0; i < jurors.length; i++) {
            who[i] = jurors[i];
        }

        assertEq(token.balanceOf(address(court)), _trackedTokens(who, cases));

        _voteAll(a, [true, false, true]);
        court.resolveCase(a);
        assertEq(token.balanceOf(address(court)), _trackedTokens(who, cases));
    }

    function _bit(uint8 mask, uint256 index) internal pure returns (bool) {
        return ((mask >> index) & 1) == 1;
    }

    function testFuzzResolutionKeepsTokensBalanced(uint8 commitMask, uint8 revealMask, uint8 voteMask, bool timeout)
        public
    {
        if (timeout) {
            vm.prank(stranger);
            court.fundReserve(FEE);
        }
        uint256 caseId = timeout ? _openTimeout(REPORT) : _open(REPORT);
        address[] memory js = court.jurorsOf(caseId);

        uint256 hunterVotes;
        uint256 companyVotes;
        for (uint256 i = 0; i < 3; i++) {
            if (_bit(commitMask, i)) {
                vm.prank(js[i]);
                court.commitVote(caseId, _voteHash(_bit(voteMask, i), js[i], caseId));
            }
        }
        _toRevealPhase(caseId);
        for (uint256 i = 0; i < 3; i++) {
            bool committed = _bit(commitMask, i);
            if (committed && _bit(revealMask, i)) {
                bool vote = _bit(voteMask, i);
                _reveal(caseId, i, vote);
                if (vote) hunterVotes++;
                else companyVotes++;
            }
        }
        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId);

        bool expected = hunterVotes > companyVotes ? true : (hunterVotes < companyVotes ? false : timeout);
        assertEq(mockRegistry.lastHunterWins(), expected);

        address[] memory who = new address[](jurors.length);
        for (uint256 i = 0; i < jurors.length; i++) {
            who[i] = jurors[i];
        }
        uint256[] memory none = new uint256[](0);
        // everything the court holds is a juror stake, the reserve, or was sent to the treasury as dust
        assertEq(token.balanceOf(address(court)), _trackedTokens(who, none));
        for (uint256 i = 0; i < 3; i++) {
            assertEq(court.activeCases(js[i]), 0);
        }
    }

    // ------------------------------------------------------------------ views

    function testViewsOfAnUnknownCaseAreEmpty() public view {
        DisputeCourt.Case memory c = court.getCase(5);
        assertTrue(c.status == DisputeCourt.CaseStatus.None);
        assertEq(court.jurorsOf(5).length, 0);
        assertFalse(court.voteInfo(5, jurors[0]).selected);
    }
}
