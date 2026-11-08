// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";
import {SystemBase} from "./SystemBase.sol";

/// @notice Random-input tests for the escrow: whatever the funding, tiers and order of events,
///         the money rules hold.
contract EscrowFuzz is Test {
    BountyFactory internal factory;
    address internal registry = makeAddr("registry");
    address internal company = makeAddr("company");
    address internal hunter = makeAddr("hunter");

    function setUp() public {
        factory = new BountyFactory();
        factory.setRegistry(registry);
    }

    /// @dev Turns four random numbers into valid tiers: each 1..10000 bps, non-decreasing.
    function _tiers(uint16 a, uint16 b, uint16 c, uint16 e) internal pure returns (uint16[4] memory t) {
        t = [uint16(1 + (uint256(a) % 10_000)), uint16(1 + (uint256(b) % 10_000)), uint16(1 + (uint256(c) % 10_000)), uint16(1 + (uint256(e) % 10_000))];
        for (uint256 i = 0; i < 4; i++) {
            for (uint256 j = i + 1; j < 4; j++) {
                if (t[j] < t[i]) (t[i], t[j]) = (t[j], t[i]);
            }
        }
    }

    function _program(uint256 funding, uint16 a, uint16 b, uint16 c, uint16 e) internal returns (BountyEscrow esc) {
        funding = bound(funding, 1e6, 1e27);
        vm.deal(company, funding);
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram{value: funding}(company, _tiers(a, b, c, e));
        esc = BountyEscrow(escrowAddress);
    }

    function testFuzz_RewardsNeverExceedFundingAndGrowWithSeverity(
        uint256 funding,
        uint16 a,
        uint16 b,
        uint16 c,
        uint16 e
    ) public {
        BountyEscrow esc = _program(funding, a, b, c, e);
        uint256 low = esc.rewardFor(IBountyEscrow.Severity.Low);
        uint256 medium = esc.rewardFor(IBountyEscrow.Severity.Medium);
        uint256 high = esc.rewardFor(IBountyEscrow.Severity.High);
        uint256 critical = esc.rewardFor(IBountyEscrow.Severity.Critical);

        assertLe(critical, esc.fundedAmount());
        assertLe(low, medium);
        assertLe(medium, high);
        assertLe(high, critical);
    }

    function testFuzz_LockedFundsCanNeverBeWithdrawn(
        uint256 funding,
        uint16 a,
        uint16 b,
        uint16 c,
        uint16 e,
        uint8 severityIndex,
        uint256 withdrawAmount
    ) public {
        BountyEscrow esc = _program(funding, a, b, c, e);
        IBountyEscrow.Severity severity = IBountyEscrow.Severity(bound(severityIndex, 0, 3));

        vm.prank(registry);
        try esc.lock(1, severity) {} catch {}

        uint256 locked = esc.totalLocked();
        withdrawAmount = bound(withdrawAmount, 1, address(esc).balance + 1);
        vm.prank(company);
        try esc.withdraw(withdrawAmount) {} catch {}

        assertGe(address(esc).balance, locked); // whatever happened, the reserved part is still there
    }

    /// @dev Regression test for the bug found in Phase 5: withdrawing free funds after a lock
    ///      must never make the hunter's reward smaller than what was locked.
    function testFuzz_RewardNeverFallsBelowTheLockEvenIfTheCompanyWithdraws(
        uint256 funding,
        uint16 a,
        uint16 b,
        uint16 c,
        uint16 e,
        uint8 severityIndex,
        uint256 withdrawAmount
    ) public {
        BountyEscrow esc = _program(funding, a, b, c, e);
        IBountyEscrow.Severity severity = IBountyEscrow.Severity(bound(severityIndex, 0, 3));

        vm.prank(registry);
        try esc.lock(1, severity) {}
        catch {
            return; // the tiers gave a zero reward for this funding: nothing to test
        }
        (uint256 lockedAmount,,) = esc.lockOf(1);

        withdrawAmount = bound(withdrawAmount, 1, esc.unlockedBalance() + 1);
        vm.prank(company);
        try esc.withdraw(withdrawAmount) {} catch {}

        vm.prank(registry);
        esc.payHunter(1, hunter, severity);
        assertEq(esc.claimable(hunter), lockedAmount);
    }

    function testFuzz_SolvencySurvivesAnySequenceOfEvents(uint256 funding, uint256 seed) public {
        BountyEscrow esc = _program(funding, 500, 1500, 3000, 5000);

        for (uint256 step = 0; step < 24; step++) {
            uint256 r = uint256(keccak256(abi.encode(seed, step)));
            uint256 reportId = 1 + (r >> 8) % 6;
            IBountyEscrow.Severity severity = IBountyEscrow.Severity((r >> 16) % 4);
            uint256 action = r % 6;

            if (action == 0) {
                vm.prank(registry);
                try esc.lock(reportId, severity) {} catch {}
            } else if (action == 1) {
                vm.prank(registry);
                try esc.payHunter(reportId, hunter, severity) {} catch {}
            } else if (action == 2) {
                vm.prank(registry);
                try esc.refundCompany(reportId) {} catch {}
            } else if (action == 3) {
                vm.prank(company);
                try esc.withdraw(1 + (r >> 24) % 1e18) {} catch {}
            } else if (action == 4) {
                try esc.claimFor(hunter) {} catch {}
            } else {
                vm.deal(company, 1e18);
                vm.prank(company);
                try esc.deposit{value: 1 + (r >> 24) % 1e18}() {} catch {}
            }

            assertGe(address(esc).balance, esc.totalLocked() + esc.totalClaimable());
        }
    }
}

/// @notice Random-input tests for commit-reveal and payment through the whole deployed system.
contract RegistryFuzz is SystemBase {
    function testFuzz_CommitRevealRoundTrip(bytes32 content, bytes32 salt, uint8 severityIndex) public {
        IBountyEscrow.Severity severity = IBountyEscrow.Severity(bound(severityIndex, 0, 3));
        uint256 id = _submit(hunter, content, salt, severity);

        assertTrue(_status(id) == ReportRegistry.Status.Revealed);
        assertEq(escrow.totalLocked(), escrow.rewardFor(severity));
        assertEq(registry.getReport(id).contentHash, content);
    }

    function testFuzz_AnyTamperingBreaksTheReveal(bytes32 content, bytes32 salt, bytes32 wrongContent, bytes32 wrongSalt)
        public
    {
        vm.assume(wrongContent != content || wrongSalt != salt);
        vm.startPrank(hunter);
        uint256 id = registry.commitReport(programId, _commitHash(content, salt, hunter));
        vm.expectRevert("ReportRegistry: reveal does not match commit");
        registry.revealReport(id, "cid", wrongContent, wrongSalt, HIGH);
        vm.stopPrank();
    }

    function testFuzz_OnlyTheCommittingHunterCanReveal(address other, bytes32 content, bytes32 salt) public {
        vm.assume(other != hunter);
        vm.prank(hunter);
        uint256 id = registry.commitReport(programId, _commitHash(content, salt, hunter));

        vm.prank(other);
        vm.expectRevert("ReportRegistry: caller is not the hunter");
        registry.revealReport(id, "cid", content, salt, HIGH);
    }

    function testFuzz_ACopiedCommitIsUselessToAnotherHunter(address copier, bytes32 content, bytes32 salt) public {
        vm.assume(copier != hunter);
        bytes32 original = _commitHash(content, salt, hunter);
        vm.prank(hunter);
        registry.commitReport(programId, original);

        // the copier cannot reuse the hash, and the same content gives them a different hash
        vm.prank(copier);
        vm.expectRevert("ReportRegistry: commit hash already used");
        registry.commitReport(programId, original);
        assertTrue(_commitHash(content, salt, copier) != original);
    }

    function testFuzz_AcceptNeverPaysMoreThanTheProgramHolds(uint8 claimedIndex, uint8 acceptedIndex) public {
        IBountyEscrow.Severity claimed = IBountyEscrow.Severity(bound(claimedIndex, 0, 3));
        IBountyEscrow.Severity accepted = IBountyEscrow.Severity(bound(acceptedIndex, 0, 3));
        uint256 id = _submit(hunter, CONTENT, SALT, claimed);

        vm.prank(company);
        registry.acceptReport(id, accepted);

        assertLe(hunter.balance, 10 ether);
        assertEq(address(escrow).balance + hunter.balance, 10 ether); // every wei is somewhere
        assertEq(hunter.balance, escrow.rewardFor(accepted));
    }
}
