// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @dev A hunter that can be told to refuse incoming ETH, then later claim.
contract FlakyHunter {
    bool public rejecting = true;

    function setRejecting(bool value) external {
        rejecting = value;
    }

    function claimFrom(BountyEscrow escrow) external {
        escrow.claim();
    }

    receive() external payable {
        require(!rejecting, "FlakyHunter: rejecting");
    }
}

/// @dev A hunter that burns all the gas it is given.
contract GasBurner {
    receive() external payable {
        while (true) {}
    }
}

/// @dev A hunter that tries to call back into the escrow while being paid.
contract ReentrantHunter {
    BountyEscrow public escrow;
    uint256 public reentryAttempts;
    bool public reentryBlocked;

    function setEscrow(BountyEscrow escrow_) external {
        escrow = escrow_;
    }

    function attack() external {
        escrow.claim();
    }

    receive() external payable {
        reentryAttempts++;
        try escrow.claim() {}
        catch {
            reentryBlocked = true;
        }
    }
}

contract BountyEscrowTest is Test {
    BountyEscrow internal implementation;
    BountyEscrow internal escrow;

    address internal registry = makeAddr("registry");
    address internal company = makeAddr("company");
    address internal hunter = makeAddr("hunter");
    address internal stranger = makeAddr("stranger");

    // Low 5%, Medium 15%, High 30%, Critical 50%
    uint16[4] internal bps = [uint16(500), 1500, 3000, 5000];

    IBountyEscrow.Severity internal constant LOW = IBountyEscrow.Severity.Low;
    IBountyEscrow.Severity internal constant MEDIUM = IBountyEscrow.Severity.Medium;
    IBountyEscrow.Severity internal constant HIGH = IBountyEscrow.Severity.High;
    IBountyEscrow.Severity internal constant CRITICAL = IBountyEscrow.Severity.Critical;

    event Deposited(address indexed from, uint256 amount);
    event FundsLocked(uint256 indexed reportId, uint256 amount, IBountyEscrow.Severity severity);
    event HunterCredited(uint256 indexed reportId, address indexed hunter, uint256 amount);
    event FundsReleased(uint256 indexed reportId, uint256 amount);
    event Claimed(address indexed hunter, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    function setUp() public {
        implementation = new BountyEscrow();
        escrow = _newEscrow(10 ether);
    }

    function _newEscrow(uint256 funding) internal returns (BountyEscrow clone) {
        clone = BountyEscrow(Clones.clone(address(implementation)));
        clone.initialize{value: funding}(registry, company, bps);
    }

    // ------------------------------------------------------------------ initialize

    function testInitializeSetsState() public view {
        assertEq(escrow.registry(), registry);
        assertEq(escrow.owner(), company);
        assertEq(escrow.fundedAmount(), 10 ether);
        assertEq(address(escrow).balance, 10 ether);
        assertEq(escrow.payoutBps(LOW), 500);
        assertEq(escrow.payoutBps(MEDIUM), 1500);
        assertEq(escrow.payoutBps(HIGH), 3000);
        assertEq(escrow.payoutBps(CRITICAL), 5000);
        assertEq(escrow.unlockedBalance(), 10 ether);
    }

    function testInitializeEmitsDepositEvent() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        vm.expectEmit(true, false, false, true);
        emit Deposited(company, 3 ether);
        clone.initialize{value: 3 ether}(registry, company, bps);
    }

    function testInitializeWithoutFunding() public {
        BountyEscrow clone = _newEscrow(0);
        assertEq(clone.fundedAmount(), 0);
        assertEq(address(clone).balance, 0);
    }

    function testInitializeTwiceReverts() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        escrow.initialize(registry, company, bps);
    }

    function testImplementationCannotBeInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(registry, company, bps);
    }

    function testInitializeZeroRegistryReverts() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        vm.expectRevert("BountyEscrow: registry is zero address");
        clone.initialize(address(0), company, bps);
    }

    function testInitializeZeroOwnerReverts() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        vm.expectRevert("BountyEscrow: owner is zero address");
        clone.initialize(registry, address(0), bps);
    }

    function testInitializePayoutAbove100PercentReverts() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        uint16[4] memory bad = [uint16(500), 1500, 3000, 10_001];
        vm.expectRevert("BountyEscrow: payout above 100%");
        clone.initialize(registry, company, bad);
    }

    function testInitializeDecreasingPayoutsReverts() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        uint16[4] memory bad = [uint16(500), 1500, 1000, 5000];
        vm.expectRevert("BountyEscrow: payouts must not decrease");
        clone.initialize(registry, company, bad);
    }

    function testInitializeZeroCriticalPayoutReverts() public {
        BountyEscrow clone = BountyEscrow(Clones.clone(address(implementation)));
        uint16[4] memory bad = [uint16(0), 0, 0, 0];
        vm.expectRevert("BountyEscrow: critical payout is zero");
        clone.initialize(registry, company, bad);
    }

    // ------------------------------------------------------------------ deposit / views

    function testDepositIncreasesFunding() public {
        vm.deal(company, 5 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposited(company, 5 ether);
        vm.prank(company);
        escrow.deposit{value: 5 ether}();

        assertEq(escrow.fundedAmount(), 15 ether);
        assertEq(address(escrow).balance, 15 ether);
    }

    function testDepositZeroReverts() public {
        vm.prank(company);
        vm.expectRevert("BountyEscrow: deposit is zero");
        escrow.deposit{value: 0}();
    }

    function testDepositByNonOwnerReverts() public {
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        vm.expectRevert("BountyEscrow: caller is not the owner");
        escrow.deposit{value: 1 ether}();
    }

    function testRewardForEachSeverity() public view {
        assertEq(escrow.rewardFor(LOW), 0.5 ether);
        assertEq(escrow.rewardFor(MEDIUM), 1.5 ether);
        assertEq(escrow.rewardFor(HIGH), 3 ether);
        assertEq(escrow.rewardFor(CRITICAL), 5 ether);
    }

    // ------------------------------------------------------------------ lock

    function testLockReservesFunds() public {
        vm.expectEmit(true, false, false, true);
        emit FundsLocked(1, 5 ether, CRITICAL);
        vm.prank(registry);
        escrow.lock(1, CRITICAL);

        assertEq(escrow.totalLocked(), 5 ether);
        assertEq(escrow.unlockedBalance(), 5 ether);
        (uint256 amount, bool locked, bool settled) = escrow.lockOf(1);
        assertEq(amount, 5 ether);
        assertTrue(locked);
        assertFalse(settled);
    }

    function testLockOnlyRegistry() public {
        vm.prank(stranger);
        vm.expectRevert("BountyEscrow: caller is not the registry");
        escrow.lock(1, LOW);

        vm.prank(company);
        vm.expectRevert("BountyEscrow: caller is not the registry");
        escrow.lock(1, LOW);
    }

    function testLockSameReportTwiceReverts() public {
        vm.startPrank(registry);
        escrow.lock(1, LOW);
        vm.expectRevert("BountyEscrow: report already locked or settled");
        escrow.lock(1, LOW);
        vm.stopPrank();
    }

    function testLockInsufficientUnlockedFundsReverts() public {
        vm.startPrank(registry);
        escrow.lock(1, CRITICAL); // 5 ETH
        escrow.lock(2, CRITICAL); // 5 ETH, all 10 ETH now locked
        vm.expectRevert("BountyEscrow: insufficient unlocked funds");
        escrow.lock(3, LOW);
        vm.stopPrank();
    }

    function testLockZeroRewardReverts() public {
        BountyEscrow unfunded = _newEscrow(0);
        vm.prank(registry);
        vm.expectRevert("BountyEscrow: reward is zero");
        unfunded.lock(1, LOW);
    }

    // ------------------------------------------------------------------ withdraw

    function testOwnerCannotWithdrawLockedFunds() public {
        vm.prank(registry);
        escrow.lock(1, CRITICAL); // 5 ETH locked

        vm.prank(company);
        vm.expectRevert("BountyEscrow: exceeds unlocked funds");
        escrow.withdraw(5 ether + 1);
    }

    function testOwnerWithdrawsUnlockedFunds() public {
        vm.prank(registry);
        escrow.lock(1, CRITICAL);

        uint256 before = company.balance;
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(company, 5 ether);
        vm.prank(company);
        escrow.withdraw(5 ether);

        assertEq(company.balance, before + 5 ether);
        assertEq(escrow.fundedAmount(), 5 ether);
        assertEq(escrow.unlockedBalance(), 0);
    }

    function testWithdrawZeroReverts() public {
        vm.prank(company);
        vm.expectRevert("BountyEscrow: withdraw is zero");
        escrow.withdraw(0);
    }

    function testWithdrawByNonOwnerReverts() public {
        vm.prank(stranger);
        vm.expectRevert("BountyEscrow: caller is not the owner");
        escrow.withdraw(1 ether);
    }

    function testWithdrawEverythingZeroesFundedAmount() public {
        vm.prank(company);
        escrow.withdraw(10 ether);
        assertEq(escrow.fundedAmount(), 0);
        assertEq(address(escrow).balance, 0);
    }

    function testWithdrawMoreThanFundedAmountAfterForcedEthDoesNotUnderflow() public {
        // ETH can be forced into any contract (e.g. selfdestruct); accounting must survive it.
        vm.deal(address(escrow), 12 ether);
        vm.prank(company);
        escrow.withdraw(12 ether);
        assertEq(escrow.fundedAmount(), 0);
    }

    // ------------------------------------------------------------------ payHunter

    function testPayHunterCreditsThenClaimForPays() public {
        vm.prank(registry);
        escrow.lock(1, HIGH);

        vm.expectEmit(true, true, false, true);
        emit HunterCredited(1, hunter, 3 ether);
        vm.prank(registry);
        escrow.payHunter(1, hunter, HIGH);

        // bookkeeping only: no ETH has left yet, but it is reserved for the hunter
        assertEq(hunter.balance, 0);
        assertEq(escrow.claimable(hunter), 3 ether);
        assertEq(escrow.totalClaimable(), 3 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(address(escrow).balance, 10 ether);
        assertEq(escrow.unlockedBalance(), 7 ether);
        (uint256 amount, bool locked, bool settled) = escrow.lockOf(1);
        assertEq(amount, 3 ether);
        assertFalse(locked);
        assertTrue(settled);

        // anyone can push the money to the hunter
        vm.expectEmit(true, false, false, true);
        emit Claimed(hunter, 3 ether);
        vm.prank(stranger);
        escrow.claimFor(hunter);

        assertEq(hunter.balance, 3 ether);
        assertEq(address(escrow).balance, 7 ether);
        assertEq(escrow.claimable(hunter), 0);
        assertEq(escrow.totalClaimable(), 0);
    }

    function testPayHunterWithoutPriorLock() public {
        vm.prank(registry);
        escrow.payHunter(7, hunter, LOW);
        escrow.claimFor(hunter);
        assertEq(hunter.balance, 0.5 ether);
    }

    function testPayHunterCanChangeSeverity() public {
        vm.startPrank(registry);
        escrow.lock(1, LOW); // 0.5 ETH locked
        escrow.payHunter(1, hunter, HIGH); // company decided on High: 3 ETH
        vm.stopPrank();

        assertEq(escrow.totalLocked(), 0);
        assertEq(escrow.claimable(hunter), 3 ether);

        escrow.claimFor(hunter);
        assertEq(hunter.balance, 3 ether);
        assertEq(address(escrow).balance, 7 ether);
    }

    function testWithdrawingAfterLockCannotShrinkTheReward() public {
        vm.prank(registry);
        escrow.lock(1, HIGH); // 3 ETH reserved, pool was 10 ETH

        vm.prank(company);
        escrow.withdraw(7 ether); // the company takes everything that is free: pool is now 3 ETH
        assertEq(escrow.fundedAmount(), 3 ether);

        vm.prank(registry);
        escrow.payHunter(1, hunter, HIGH);
        assertEq(escrow.claimable(hunter), 3 ether); // still 30% of the 10 ETH promised, not 0.9
    }

    function testLowerSeverityStillUsesThePoolFromLockTime() public {
        vm.prank(registry);
        escrow.lock(1, HIGH);
        vm.prank(company);
        escrow.withdraw(7 ether);

        vm.prank(registry);
        escrow.payHunter(1, hunter, LOW);
        assertEq(escrow.claimable(hunter), 0.5 ether); // 5% of 10 ETH, not 5% of 3
    }

    function testTopUpAfterLockRaisesAHigherSeverityPayment() public {
        vm.prank(registry);
        escrow.lock(1, LOW); // pool was 10 ETH
        vm.deal(company, 10 ether);
        vm.prank(company);
        escrow.deposit{value: 10 ether}(); // pool is now 20 ETH

        vm.prank(registry);
        escrow.payHunter(1, hunter, HIGH);
        assertEq(escrow.claimable(hunter), 6 ether); // 30% of the larger, current pool
    }

    function testPayHunterOnlyRegistry() public {
        vm.prank(company);
        vm.expectRevert("BountyEscrow: caller is not the registry");
        escrow.payHunter(1, hunter, LOW);
    }

    function testPayHunterTwiceReverts() public {
        vm.startPrank(registry);
        escrow.payHunter(1, hunter, LOW);
        vm.expectRevert("BountyEscrow: report already settled");
        escrow.payHunter(1, hunter, LOW);
        vm.stopPrank();
    }

    function testPayHunterZeroAddressReverts() public {
        vm.prank(registry);
        vm.expectRevert("BountyEscrow: hunter is zero address");
        escrow.payHunter(1, address(0), LOW);
    }

    function testPayHunterZeroRewardReverts() public {
        BountyEscrow unfunded = _newEscrow(0);
        vm.prank(registry);
        vm.expectRevert("BountyEscrow: reward is zero");
        unfunded.payHunter(1, hunter, LOW);
    }

    function testPayHunterInsufficientFundsReverts() public {
        vm.startPrank(registry);
        escrow.lock(1, CRITICAL);
        escrow.lock(2, CRITICAL); // everything locked
        vm.expectRevert("BountyEscrow: insufficient unlocked funds");
        escrow.payHunter(3, hunter, LOW); // report 3 has no lock of its own
        vm.stopPrank();
    }

    function testPayHunterUsesItsOwnLockEvenWhenEverythingIsLocked() public {
        vm.startPrank(registry);
        escrow.lock(1, CRITICAL);
        escrow.lock(2, CRITICAL);
        escrow.payHunter(1, hunter, CRITICAL); // releases its own lock, then credits
        vm.stopPrank();
        assertEq(escrow.claimable(hunter), 5 ether);
        assertEq(escrow.totalLocked(), 5 ether);
        assertEq(escrow.unlockedBalance(), 0);
    }

    // ------------------------------------------------------------------ pull-payment fallback

    function testRejectingHunterCanStillClaimLater() public {
        FlakyHunter flaky = new FlakyHunter();
        vm.prank(registry);
        escrow.payHunter(1, address(flaky), HIGH);

        // pushing fails while the hunter rejects ETH, but the credit is kept
        vm.expectRevert("BountyEscrow: claim failed");
        escrow.claimFor(address(flaky));
        assertEq(escrow.claimable(address(flaky)), 3 ether);
        assertEq(escrow.totalClaimable(), 3 ether);
        assertEq(escrow.unlockedBalance(), 7 ether);

        // the company cannot take the hunter's money
        vm.prank(company);
        vm.expectRevert("BountyEscrow: exceeds unlocked funds");
        escrow.withdraw(7 ether + 1);

        flaky.setRejecting(false);
        vm.expectEmit(true, false, false, true);
        emit Claimed(address(flaky), 3 ether);
        flaky.claimFrom(escrow);

        assertEq(address(flaky).balance, 3 ether);
        assertEq(escrow.claimable(address(flaky)), 0);
        assertEq(escrow.totalClaimable(), 0);
    }

    function testOwnClaimFailsWhileHunterStillRejects() public {
        FlakyHunter flaky = new FlakyHunter();
        vm.prank(registry);
        escrow.payHunter(1, address(flaky), LOW);

        vm.expectRevert("BountyEscrow: claim failed");
        flaky.claimFrom(escrow);
        assertEq(escrow.claimable(address(flaky)), 0.5 ether); // credit is kept
    }

    function testClaimNothingReverts() public {
        vm.prank(stranger);
        vm.expectRevert("BountyEscrow: nothing to claim");
        escrow.claim();

        vm.expectRevert("BountyEscrow: nothing to claim");
        escrow.claimFor(stranger);
    }

    function testGasBurningHunterCannotBlockAnyone() public {
        GasBurner burner = new GasBurner();
        vm.prank(registry);
        escrow.payHunter(1, address(burner), LOW); // crediting never calls the hunter

        uint256 gasBefore = gasleft();
        vm.expectRevert("BountyEscrow: claim failed");
        escrow.claimFor(address(burner)); // hunter gets at most PUSH_GAS, then we revert
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 200_000);
        assertEq(escrow.claimable(address(burner)), 0.5 ether);
        (, , bool settled) = escrow.lockOf(1);
        assertTrue(settled);
    }

    function testReentrancyIsBlockedDuringClaimFor() public {
        ReentrantHunter attacker = new ReentrantHunter();
        attacker.setEscrow(escrow);

        vm.prank(registry);
        escrow.payHunter(1, address(attacker), HIGH);
        escrow.claimFor(address(attacker));

        assertEq(attacker.reentryAttempts(), 1);
        assertTrue(attacker.reentryBlocked());
        assertEq(address(attacker).balance, 3 ether); // paid exactly once
        assertEq(address(escrow).balance, 7 ether);
        assertEq(escrow.claimable(address(attacker)), 0);
    }

    function testReentrancyIsBlockedDuringOwnClaim() public {
        ReentrantHunter attacker = new ReentrantHunter();
        attacker.setEscrow(escrow);

        vm.prank(registry);
        escrow.payHunter(1, address(attacker), HIGH);
        attacker.attack();

        assertEq(attacker.reentryAttempts(), 1);
        assertTrue(attacker.reentryBlocked());
        assertEq(address(attacker).balance, 3 ether);
        assertEq(address(escrow).balance, 7 ether);
    }

    // ------------------------------------------------------------------ refund

    function testRefundReleasesLock() public {
        vm.startPrank(registry);
        escrow.lock(1, CRITICAL);

        vm.expectEmit(true, false, false, true);
        emit FundsReleased(1, 5 ether);
        escrow.refundCompany(1);
        vm.stopPrank();

        assertEq(escrow.totalLocked(), 0);
        assertEq(escrow.unlockedBalance(), 10 ether);
        (, bool locked, bool settled) = escrow.lockOf(1);
        assertFalse(locked);
        assertTrue(settled);

        // the company can now take everything back
        vm.prank(company);
        escrow.withdraw(10 ether);
        assertEq(company.balance, 10 ether);
    }

    function testRefundWithoutLockClosesReport() public {
        vm.expectEmit(true, false, false, true);
        emit FundsReleased(9, 0);
        vm.prank(registry);
        escrow.refundCompany(9);

        (, , bool settled) = escrow.lockOf(9);
        assertTrue(settled);
    }

    function testRefundOnlyRegistry() public {
        vm.prank(company);
        vm.expectRevert("BountyEscrow: caller is not the registry");
        escrow.refundCompany(1);
    }

    function testRefundTwiceReverts() public {
        vm.startPrank(registry);
        escrow.refundCompany(1);
        vm.expectRevert("BountyEscrow: report already settled");
        escrow.refundCompany(1);
        vm.stopPrank();
    }

    function testSettledReportCannotBeLockedOrPaidAgain() public {
        vm.startPrank(registry);
        escrow.refundCompany(1);
        vm.expectRevert("BountyEscrow: report already locked or settled");
        escrow.lock(1, LOW);
        vm.expectRevert("BountyEscrow: report already settled");
        escrow.payHunter(1, hunter, LOW);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------ fuzz

    function testFuzzLockAndPayConserveFunds(uint96 funding, uint8 severityIndex) public {
        funding = uint96(bound(funding, 1 ether, 10_000 ether));
        IBountyEscrow.Severity severity = IBountyEscrow.Severity(bound(severityIndex, 0, 3));

        BountyEscrow clone = _newEscrow(0);
        vm.deal(company, funding);
        vm.prank(company);
        clone.deposit{value: funding}();

        uint256 reward = clone.rewardFor(severity);
        vm.prank(registry);
        clone.lock(1, severity);

        assertEq(clone.totalLocked(), reward);
        assertEq(clone.unlockedBalance() + clone.totalLocked(), address(clone).balance);

        vm.prank(registry);
        clone.payHunter(1, hunter, severity);
        assertEq(clone.claimable(hunter), reward);
        assertEq(clone.unlockedBalance() + clone.totalClaimable(), address(clone).balance);

        clone.claimFor(hunter);

        assertEq(hunter.balance, reward);
        assertEq(address(clone).balance + hunter.balance, funding);
        assertEq(clone.totalLocked(), 0);
    }
}
