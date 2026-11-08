// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {BountyToken} from "../src/BountyToken.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";
import {PlatformTreasury} from "../src/PlatformTreasury.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @dev The whole platform, real contracts only: Factory, Escrow, Registry, Court, token,
///      treasury and badge. Shows disputes end to end, including the money.
contract DisputeScenarios is Test {
    BountyToken internal token;
    PlatformTreasury internal treasury;
    BountyFactory internal factory;
    ReputationSBT internal sbt;
    ReportRegistry internal registry;
    DisputeCourt internal court;
    BountyEscrow internal escrow;
    uint256 internal programId;

    address internal company = makeAddr("company");
    address internal hunter = makeAddr("hunter");
    address[] internal jurors;

    uint64 internal constant PERIOD = 7 days;
    uint256 internal constant MIN_STAKE = 100 ether;
    uint256 internal constant SLASH = 20 ether;
    uint256 internal constant FEE = 10 ether;

    bytes32 internal constant CONTENT = keccak256("sql injection");
    bytes32 internal constant SALT = keccak256("salt");

    IBountyEscrow.Severity internal constant HIGH = IBountyEscrow.Severity.High; // 3 ETH of 10

    function setUp() public {
        token = new BountyToken(1_000_000 ether);
        treasury = new PlatformTreasury();
        factory = new BountyFactory();
        sbt = new ReputationSBT();
        registry = new ReportRegistry(address(factory), address(sbt), PERIOD, PERIOD, PERIOD);
        factory.setRegistry(address(registry));
        sbt.transferOwnership(address(registry));

        court = new DisputeCourt(
            address(registry),
            address(token),
            address(treasury),
            DisputeCourt.Config({
                jurorsPerCase: 3,
                minStake: MIN_STAKE,
                slashPerJuror: SLASH,
                disputeFee: FEE,
                commitPeriod: 1 days,
                revealPeriod: 1 days,
                unstakeCooldown: 3 days
            })
        );
        registry.setCourt(address(court));

        uint16[4] memory bps = [uint16(500), 1500, 3000, 5000];
        vm.deal(company, 100 ether);
        vm.prank(company);
        (uint256 id, address escrowAddress) = factory.createProgram{value: 10 ether}(company, bps);
        programId = id;
        escrow = BountyEscrow(escrowAddress);

        for (uint256 i = 0; i < 5; i++) {
            address juror = makeAddr(string.concat("juror", vm.toString(i)));
            jurors.push(juror);
            token.transfer(juror, 1000 ether);
            vm.startPrank(juror);
            token.approve(address(court), type(uint256).max);
            court.stake(MIN_STAKE);
            vm.stopPrank();
        }

        token.transfer(hunter, 500 ether);
        vm.prank(hunter);
        token.approve(address(court), type(uint256).max);
    }

    // ------------------------------------------------------------------ helpers

    function _submit() internal returns (uint256 id) {
        vm.startPrank(hunter);
        id = registry.commitReport(programId, keccak256(abi.encode(CONTENT, SALT, hunter)));
        registry.revealReport(id, "bafyReport", CONTENT, SALT, HIGH);
        vm.stopPrank();
    }

    function _rejectAndEscalate() internal returns (uint256 reportId, uint256 caseId) {
        reportId = _submit();
        vm.prank(company);
        registry.rejectReport(reportId);

        vm.startPrank(hunter);
        court.payDisputeFee(reportId);
        registry.escalate(reportId);
        vm.stopPrank();

        caseId = court.caseOfReport(reportId);
    }

    function _vote(uint256 caseId, bool[3] memory votes) internal {
        address[] memory js = court.jurorsOf(caseId);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(js[i]);
            court.commitVote(caseId, keccak256(abi.encode(votes[i], keccak256(abi.encode(js[i])), js[i], caseId)));
        }
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(js[i]);
            court.revealVote(caseId, votes[i], keccak256(abi.encode(js[i])));
        }
    }

    function _totalStakes() internal view returns (uint256 total) {
        for (uint256 i = 0; i < jurors.length; i++) {
            total += court.jurorStake(jurors[i]);
        }
    }

    // ------------------------------------------------------------------ stories

    function testRejectedReportHunterWinsAndIsPaid() public {
        (uint256 reportId, uint256 caseId) = _rejectAndEscalate();
        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Disputed);
        assertEq(escrow.totalLocked(), 3 ether); // still reserved while the jury decides

        _vote(caseId, [true, true, true]);
        court.resolveCase(caseId);

        // the hunter is paid at the severity they claimed, and gets a badge
        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Paid);
        assertEq(hunter.balance, 3 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(sbt.ownerOf(registry.badgeOf(hunter)), hunter);

        // the fee paid by the hunter went to the three jurors (rounding dust to the treasury)
        address[] memory js = court.jurorsOf(caseId);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(court.jurorStake(js[i]), MIN_STAKE + FEE / 3);
            assertEq(court.activeCases(js[i]), 0);
        }
        assertEq(token.balanceOf(address(treasury)), FEE - 3 * (FEE / 3));
    }

    function testRejectedReportCompanyWinsAndKeepsItsMoney() public {
        (uint256 reportId, uint256 caseId) = _rejectAndEscalate();
        _vote(caseId, [false, false, true]); // 2-1 for the company
        court.resolveCase(caseId);

        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Refunded);
        assertEq(hunter.balance, 0);
        assertFalse(registry.hasBadge(hunter));

        vm.prank(company);
        escrow.withdraw(10 ether); // the lock is gone, everything is the company's again
        assertEq(address(escrow).balance, 0);

        // the hunter's fee plus the outvoted juror's slash went to the two winners
        address[] memory js = court.jurorsOf(caseId);
        assertEq(court.jurorStake(js[0]), MIN_STAKE + 15 ether);
        assertEq(court.jurorStake(js[1]), MIN_STAKE + 15 ether);
        assertEq(court.jurorStake(js[2]), MIN_STAKE - SLASH);
    }

    function testCompanyTimeoutGoesToTheJuryAndTheHunterWinsATie() public {
        token.approve(address(court), type(uint256).max);
        court.fundReserve(FEE); // the platform pays the fee of a timeout case

        uint256 reportId = _submit();
        vm.warp(block.timestamp + PERIOD + 1); // the company never answers
        registry.escalateAfterTimeout(reportId); // anyone may call it

        uint256 caseId = court.caseOfReport(reportId);
        assertTrue(court.getCase(caseId).byTimeout);
        assertEq(court.getCase(caseId).fee, FEE);
        assertEq(court.reserve(), 0);

        // one juror for each side, the third never votes: a tie, and the silent company loses it
        address[] memory js = court.jurorsOf(caseId);
        vm.prank(js[0]);
        court.commitVote(caseId, keccak256(abi.encode(true, keccak256(abi.encode(js[0])), js[0], caseId)));
        vm.prank(js[1]);
        court.commitVote(caseId, keccak256(abi.encode(false, keccak256(abi.encode(js[1])), js[1], caseId)));
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        vm.prank(js[0]);
        court.revealVote(caseId, true, keccak256(abi.encode(js[0])));
        vm.prank(js[1]);
        court.revealVote(caseId, false, keccak256(abi.encode(js[1])));
        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId);

        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Paid);
        assertEq(hunter.balance, 3 ether);
    }

    function testEscalateWithoutPayingTheFeeFailsAndKeepsTheRejection() public {
        uint256 reportId = _submit();
        vm.prank(company);
        registry.rejectReport(reportId);

        vm.prank(hunter);
        vm.expectRevert("DisputeCourt: dispute fee not paid");
        registry.escalate(reportId);
        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Rejected);

        // paying afterwards works
        vm.startPrank(hunter);
        court.payDisputeFee(reportId);
        registry.escalate(reportId);
        vm.stopPrank();
        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Disputed);
    }

    function testEscalateFailsWhenTooFewJurorsAreLeft() public {
        uint256 reportId = _submit();
        vm.prank(company);
        registry.rejectReport(reportId);

        // three jurors leave the pool, so only two are left for a three-juror case
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(jurors[i]);
            court.requestUnstake();
        }

        vm.startPrank(hunter);
        court.payDisputeFee(reportId);
        vm.expectRevert("DisputeCourt: not enough eligible jurors");
        registry.escalate(reportId);
        vm.stopPrank();

        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Rejected);
        assertEq(court.caseCount(), 0);
    }

    function testCompanyCannotBeDrawnAsJurorInItsOwnCase() public {
        token.transfer(company, 200 ether);
        vm.startPrank(company);
        token.approve(address(court), type(uint256).max);
        court.stake(MIN_STAKE);
        vm.stopPrank();
        assertEq(court.poolSize(), 6);

        for (uint256 r = 0; r < 4; r++) {
            vm.prevrandao(bytes32(r + 1));
            vm.prank(hunter);
            uint256 id = registry.commitReport(programId, keccak256(abi.encode(CONTENT, bytes32(r), hunter)));
            vm.prank(hunter);
            registry.revealReport(id, "cid", CONTENT, bytes32(r), IBountyEscrow.Severity.Low);
            vm.prank(company);
            registry.rejectReport(id);
            vm.startPrank(hunter);
            court.payDisputeFee(id);
            registry.escalate(id);
            vm.stopPrank();

            address[] memory js = court.jurorsOf(court.caseOfReport(id));
            for (uint256 i = 0; i < js.length; i++) {
                assertTrue(js[i] != company);
                assertTrue(js[i] != hunter);
            }
        }
    }

    function testWinningJurorCanWithdrawTheirReward() public {
        (, uint256 caseId) = _rejectAndEscalate();
        _vote(caseId, [true, true, true]);
        court.resolveCase(caseId);

        address juror = court.jurorsOf(caseId)[0];
        uint256 before = token.balanceOf(juror);
        vm.startPrank(juror);
        court.requestUnstake();
        vm.warp(block.timestamp + 3 days);
        court.withdrawStake();
        vm.stopPrank();
        assertEq(token.balanceOf(juror) - before, MIN_STAKE + FEE / 3);
    }

    function testNoValueIsCreatedOrLostAcrossTheWholeSystem() public {
        uint256 tokenSupplyBefore = token.totalSupply();
        (uint256 reportId, uint256 caseId) = _rejectAndEscalate();
        _vote(caseId, [true, false, true]);
        court.resolveCase(caseId);

        // tokens: the court holds exactly the stakes (fees were handed to jurors and the dust
        // to the treasury); nothing was minted or burned
        assertEq(token.balanceOf(address(court)), _totalStakes());
        assertEq(token.totalSupply(), tokenSupplyBefore);

        // ETH: 10 in; the hunter got 3, 7 are still the company's
        assertEq(hunter.balance, 3 ether);
        assertEq(address(escrow).balance, 7 ether);
        assertEq(escrow.unlockedBalance(), 7 ether);
        assertTrue(registry.getReport(reportId).status == ReportRegistry.Status.Paid);
    }
}
