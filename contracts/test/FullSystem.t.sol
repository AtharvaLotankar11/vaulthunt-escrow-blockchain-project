// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {SystemBase} from "./SystemBase.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @notice Scenario tests on the whole platform exactly as the Deploy script wires it.

/// The good case: nobody argues.
contract FullHappyPath is SystemBase {
    function testCommitRevealReviewAcceptPaidAndBadge() public {
        uint256 id = _submit(hunter, CONTENT, SALT, CRITICAL);
        assertTrue(_status(id) == ReportRegistry.Status.Revealed);
        assertEq(escrow.totalLocked(), 5 ether); // reserved the moment it was revealed

        vm.startPrank(company);
        registry.startReview(id);
        registry.acceptReport(id, CRITICAL);
        vm.stopPrank();

        assertTrue(_status(id) == ReportRegistry.Status.Paid);
        assertEq(hunter.balance, 5 ether);
        assertEq(address(escrow).balance, 5 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(escrow.claimable(hunter), 0);

        // reputation badge: 100 XP = level 2 (Hacker)
        assertTrue(registry.hasBadge(hunter));
        assertEq(sbt.ownerOf(registry.badgeOf(hunter)), hunter);
        (uint256 level, uint256 xp) = sbt.getReputation(registry.badgeOf(hunter));
        assertEq(level, 2);
        assertEq(xp, 100);
    }

    function testTwoHuntersTwoSeveritiesPaidIndependently() public {
        uint256 a = _submit(hunter, keccak256("bug-a"), SALT, LOW);
        uint256 b = _submit(hunter2, keccak256("bug-b"), SALT, HIGH);
        vm.startPrank(company);
        registry.acceptReport(a, LOW);
        registry.acceptReport(b, HIGH);
        vm.stopPrank();

        assertEq(hunter.balance, 0.5 ether);
        assertEq(hunter2.balance, 3 ether);
        assertEq(registry.hunterXp(hunter), 10);
        assertEq(registry.hunterXp(hunter2), 50);
        assertTrue(registry.badgeOf(hunter) != registry.badgeOf(hunter2));
        assertEq(address(escrow).balance, 6.5 ether);
    }

    function testCompanyTopsUpAndTakesBackWhatIsFree() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH); // 3 ETH locked of 10
        vm.startPrank(company);
        escrow.deposit{value: 10 ether}(); // funded 20 ETH
        vm.expectRevert("BountyEscrow: exceeds unlocked funds");
        escrow.withdraw(17 ether + 1); // only 17 ETH are free
        escrow.withdraw(17 ether);
        registry.acceptReport(id, HIGH);
        vm.stopPrank();

        assertEq(hunter.balance, 3 ether); // the locked reward was untouchable
    }

    function testHunterLevelsUpToLegendAcrossManyPrograms() public {
        uint16[4] memory tiny = [uint16(1), 1, 1, 1];
        for (uint256 i = 1; i <= 7; i++) {
            vm.prank(company);
            (uint256 pid,) = factory.createProgram{value: 1 ether}(company, tiny);
            bytes32 content = keccak256(abi.encode("bug", i));
            vm.startPrank(hunter);
            uint256 id = registry.commitReport(pid, _commitHash(content, SALT, hunter));
            registry.revealReport(id, "cid", content, SALT, CRITICAL);
            vm.stopPrank();
            vm.prank(company);
            registry.acceptReport(id, CRITICAL);
        }
        (uint256 level, uint256 xp) = sbt.getReputation(registry.badgeOf(hunter));
        assertEq(xp, 700);
        assertEq(level, 4); // Legend
    }
}

/// A report is rejected and the hunter either gives up or goes to the jury.
contract RejectionAndDispute is SystemBase {
    function testHunterWinsTheDispute() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        assertEq(escrow.totalLocked(), 3 ether); // still reserved

        uint256 caseId = _escalateAfterRejection(id);
        assertTrue(_status(id) == ReportRegistry.Status.Disputed);
        _juryVotes(caseId, [true, true, true]);
        court.resolveCase(caseId);

        assertTrue(_status(id) == ReportRegistry.Status.Paid);
        assertEq(hunter.balance, 3 ether);
        assertTrue(registry.hasBadge(hunter));
        address[] memory js = court.jurorsOf(caseId);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(court.jurorStake(js[i]), params.court.minStake + params.court.disputeFee / 3);
        }
    }

    function testCompanyWinsTheDispute() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        uint256 caseId = _escalateAfterRejection(id);
        _juryVotes(caseId, [false, false, true]);
        court.resolveCase(caseId);

        assertTrue(_status(id) == ReportRegistry.Status.Refunded);
        assertEq(hunter.balance, 0);
        assertFalse(registry.hasBadge(hunter));
        assertEq(escrow.totalLocked(), 0);

        vm.prank(company);
        escrow.withdraw(10 ether);

        address[] memory js = court.jurorsOf(caseId);
        assertEq(court.jurorStake(js[2]), params.court.minStake - params.court.slashPerJuror); // outvoted
        assertEq(court.jurorStake(js[0]), params.court.minStake + 15 ether);
    }

    function testNobodyDisputesTheRejection() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);

        vm.warp(block.timestamp + params.disputeWindow + 1);
        vm.prank(stranger);
        registry.finalizeRejection(id);

        assertTrue(_status(id) == ReportRegistry.Status.Refunded);
        assertEq(escrow.unlockedBalance(), 10 ether);

        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: report is not rejected"); // too late
        registry.escalate(id);
    }

    function testEscalationNeedsTheFeeAndTheApproval() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);

        vm.prank(hunter);
        vm.expectRevert("DisputeCourt: dispute fee not paid");
        registry.escalate(id);

        // a hunter who never approved the court cannot pay the fee either
        address broke = makeAddr("broke");
        vm.prank(broke);
        vm.expectRevert();
        court.payDisputeFee(id);

        _escalateAfterRejection(id); // the proper way works
        assertTrue(_status(id) == ReportRegistry.Status.Disputed);
    }

    function testTheCompanyNeverJudgesItsOwnCase() public {
        token.transfer(company, 200 ether);
        vm.startPrank(company);
        token.approve(address(court), type(uint256).max);
        court.stake(params.court.minStake);
        vm.stopPrank();

        for (uint256 r = 1; r <= 6; r++) {
            vm.prevrandao(bytes32(r));
            uint256 id = _submit(hunter, keccak256(abi.encode("bug", r)), SALT, LOW);
            vm.prank(company);
            registry.rejectReport(id);
            uint256 caseId = _escalateAfterRejection(id);
            address[] memory js = court.jurorsOf(caseId);
            for (uint256 i = 0; i < js.length; i++) {
                assertTrue(js[i] != company);
            }
        }
    }
}

/// The company never answers.
contract TimeoutEscalation is SystemBase {
    function _fundReserve(uint256 amount) internal {
        token.approve(address(court), amount);
        court.fundReserve(amount);
    }

    function testSilentCompanyTimesOutAndTheHunterWinsATie() public {
        _fundReserve(params.court.disputeFee);
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);

        vm.warp(block.timestamp + params.reviewPeriod + 1);
        vm.prank(stranger); // anyone may trigger it
        registry.escalateAfterTimeout(id);

        uint256 caseId = court.caseOfReport(id);
        assertTrue(court.getCase(caseId).byTimeout);
        assertEq(court.getCase(caseId).fee, params.court.disputeFee);
        assertEq(court.reserve(), 0);

        // one juror each side, the third never reveals: a tie, which the silent company loses
        address[] memory js = court.jurorsOf(caseId);
        vm.prank(js[0]);
        court.commitVote(caseId, keccak256(abi.encode(true, _jurorSalt(js[0]), js[0], caseId)));
        vm.prank(js[1]);
        court.commitVote(caseId, keccak256(abi.encode(false, _jurorSalt(js[1]), js[1], caseId)));
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        vm.prank(js[0]);
        court.revealVote(caseId, true, _jurorSalt(js[0]));
        vm.prank(js[1]);
        court.revealVote(caseId, false, _jurorSalt(js[1]));
        vm.warp(court.getCase(caseId).revealDeadline + 1);
        court.resolveCase(caseId);

        assertTrue(_status(id) == ReportRegistry.Status.Paid);
        assertEq(hunter.balance, 3 ether);
    }

    function testSilentCompanyButTheJuryFindsForTheCompany() public {
        _fundReserve(params.court.disputeFee);
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + params.reviewPeriod + 1);
        registry.escalateAfterTimeout(id);

        uint256 caseId = court.caseOfReport(id);
        _juryVotes(caseId, [false, false, true]);
        court.resolveCase(caseId);

        assertTrue(_status(id) == ReportRegistry.Status.Refunded);
        assertEq(hunter.balance, 0);
    }

    function testTimeoutCaseStillWorksWithAnEmptyReserve() public {
        uint256 id = _submit(hunter, CONTENT, SALT, LOW);
        vm.warp(block.timestamp + params.reviewPeriod + 1);
        registry.escalateAfterTimeout(id);
        uint256 caseId = court.caseOfReport(id);
        assertEq(court.getCase(caseId).fee, 0); // nobody pays, jurors only earn slashed stakes

        _juryVotes(caseId, [true, true, true]);
        court.resolveCase(caseId);
        assertEq(hunter.balance, 0.5 ether);
    }

    function testEscalationBeforeTheDeadlineIsRefused() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + params.reviewPeriod); // exactly at the deadline
        vm.expectRevert("ReportRegistry: review deadline not reached");
        registry.escalateAfterTimeout(id);
    }

    function testALateAcceptBeatsAnEscalationThatNobodyStarted() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + params.reviewPeriod + 1 days);
        vm.prank(company);
        registry.acceptReport(id, HIGH); // still allowed: nobody escalated yet

        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.escalateAfterTimeout(id);
        assertEq(hunter.balance, 3 ether);
    }
}
