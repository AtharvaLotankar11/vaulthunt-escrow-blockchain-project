// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {ReportRegistry} from "../src/ReportRegistry.sol";
import {RegistryBase} from "./RegistryBase.sol";

/// @dev End-to-end stories across Factory, Escrow, Registry, badge and a mock Court.
contract RegistryIntegration is RegistryBase {
    function testHappyPathCommitRevealReviewAcceptPaidBadge() public {
        uint256 hunterBefore = hunter.balance;

        uint256 id = _commit(hunter, CONTENT, SALT); // 1. prove you found it
        _reveal(hunter, id, CONTENT, SALT, CRITICAL); // 2. reveal + reward is reserved
        assertEq(escrow.unlockedBalance(), 5 ether);

        vm.startPrank(company);
        registry.startReview(id); // 3. company looks at it
        registry.acceptReport(id, CRITICAL); // 4. accepted: paid + badge
        vm.stopPrank();

        assertEq(hunter.balance - hunterBefore, 5 ether);
        assertEq(address(escrow).balance, 5 ether);
        assertEq(sbt.ownerOf(registry.badgeOf(hunter)), hunter);
        assertTrue(registry.getReport(id).status == ReportRegistry.Status.Paid);
    }

    function testRejectedThenDisputedThenHunterWins() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        vm.prank(hunter);
        registry.escalate(id);
        assertEq(court.lastFeePayer(), hunter);

        court.verdict(registry, id, true);

        assertEq(hunter.balance, 3 ether);
        assertEq(registry.hunterXp(hunter), 50);
    }

    function testCompanySilentThenTimeoutThenCompanyWins() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + PERIOD + 1);
        registry.escalateAfterTimeout(id);
        court.verdict(registry, id, false);

        assertEq(hunter.balance, 0);
        vm.prank(company);
        escrow.withdraw(10 ether);
        assertEq(address(escrow).balance, 0);
    }

    function testDuplicateReportsEarliestCommitWinsTheReward() public {
        // two hunters find the same bug; hunter commits first, hunter2 a day later
        uint256 first = _commit(hunter, CONTENT, SALT);
        vm.warp(block.timestamp + 1 days);
        uint256 second = _commit(hunter2, CONTENT, SALT);
        _reveal(hunter, first, CONTENT, SALT, HIGH);
        _reveal(hunter2, second, CONTENT, SALT, HIGH);

        // the company compares the timestamps on-chain and accepts the earlier report only
        assertLt(registry.getReport(first).committedAt, registry.getReport(second).committedAt);
        vm.startPrank(company);
        registry.acceptReport(first, HIGH);
        registry.rejectReport(second);
        vm.stopPrank();

        // nobody disputes the duplicate, so after the window the company gets that lock back
        vm.warp(block.timestamp + PERIOD + 1);
        registry.finalizeRejection(second);

        assertEq(hunter.balance, 3 ether);
        assertEq(hunter2.balance, 0);
        assertEq(escrow.totalLocked(), 0);
    }

    function testEveryWeiIsAccountedFor() public {
        uint256 a = _submit(hunter, keccak256("a"), SALT, HIGH); // paid
        uint256 b = _submit(hunter2, keccak256("b"), SALT, LOW); // rejected, refunded
        vm.startPrank(company);
        registry.acceptReport(a, HIGH);
        registry.rejectReport(b);
        vm.stopPrank();
        vm.warp(block.timestamp + PERIOD + 1);
        registry.finalizeRejection(b);

        uint256 remaining = escrow.unlockedBalance();
        vm.prank(company);
        escrow.withdraw(remaining);

        // 10 ETH in: hunter 3, company got the other 7 back, escrow is empty
        assertEq(hunter.balance, 3 ether);
        assertEq(address(escrow).balance, 0);
        assertEq(company.balance, 1000 ether - 10 ether + 7 ether);
    }
}
