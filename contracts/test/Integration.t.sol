// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @dev Factory + Escrow together. The ReportRegistry (Phase 3) is played by an EOA called
///      "registry"; in Phase 3 this address becomes the real contract.
contract IntegrationTest is Test {
    BountyFactory internal factory;
    BountyEscrow internal escrow;

    address internal registry = makeAddr("registry");
    address internal company = makeAddr("company");
    address internal hunterA = makeAddr("hunterA");
    address internal hunterB = makeAddr("hunterB");

    uint16[4] internal bps = [uint16(500), 1500, 3000, 5000];

    IBountyEscrow.Severity internal constant LOW = IBountyEscrow.Severity.Low;
    IBountyEscrow.Severity internal constant HIGH = IBountyEscrow.Severity.High;
    IBountyEscrow.Severity internal constant CRITICAL = IBountyEscrow.Severity.Critical;

    function setUp() public {
        factory = new BountyFactory();
        factory.setRegistry(registry);

        vm.deal(company, 100 ether);
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram{value: 10 ether}(company, bps);
        escrow = BountyEscrow(escrowAddress);
    }

    function testHappyPathCompanyFundsLockAndPay() public {
        // company tops up: funded 20 ETH, so Critical = 10 ETH
        vm.prank(company);
        escrow.deposit{value: 10 ether}();
        assertEq(escrow.rewardFor(CRITICAL), 10 ether);

        // a report is under review: reward is reserved
        vm.prank(registry);
        escrow.lock(1, CRITICAL);

        // the company can take only the unlocked half
        vm.startPrank(company);
        vm.expectRevert("BountyEscrow: exceeds unlocked funds");
        escrow.withdraw(10 ether + 1);
        escrow.withdraw(10 ether);
        vm.stopPrank();
        assertEq(company.balance, 100 ether - 20 ether + 10 ether);

        // accepted: the hunter is paid
        vm.prank(registry);
        escrow.payHunter(1, hunterA, CRITICAL);
        escrow.claimFor(hunterA);

        // The hunter gets the 10 ETH that was locked for them (50% of the 20 ETH pool at lock
        // time), even though the company withdrew the free half in between.
        assertEq(hunterA.balance, 10 ether);
        assertEq(address(escrow).balance, 0);
    }

    function testRejectionPathCompanyKeepsEverything() public {
        vm.startPrank(registry);
        escrow.lock(1, HIGH);
        escrow.refundCompany(1); // dispute lost by the hunter
        vm.stopPrank();

        vm.prank(company);
        escrow.withdraw(10 ether);

        assertEq(hunterA.balance, 0);
        assertEq(address(escrow).balance, 0);
    }

    function testSeveralReportsOnOneProgram() public {
        vm.startPrank(registry);
        escrow.lock(1, LOW); // 0.5 ETH
        escrow.lock(2, HIGH); // 3 ETH
        escrow.payHunter(1, hunterA, LOW);
        escrow.payHunter(2, hunterB, HIGH);
        vm.stopPrank();
        escrow.claimFor(hunterA);
        escrow.claimFor(hunterB);

        assertEq(hunterA.balance, 0.5 ether);
        assertEq(hunterB.balance, 3 ether);
        assertEq(address(escrow).balance, 6.5 ether);
        assertEq(escrow.totalLocked(), 0);
    }

    function testProgramsDoNotShareFunds() public {
        vm.prank(company);
        (, address second) = factory.createProgram{value: 4 ether}(company, bps);

        vm.prank(registry);
        BountyEscrow(second).payHunter(1, hunterA, CRITICAL); // 2 ETH from the second program
        BountyEscrow(second).claimFor(hunterA);

        assertEq(address(escrow).balance, 10 ether);
        assertEq(second.balance, 2 ether);
    }

    function testEveryWeiIsAccountedFor() public {
        vm.startPrank(registry);
        escrow.lock(1, CRITICAL);
        escrow.payHunter(1, hunterA, CRITICAL);
        escrow.lock(2, LOW);
        escrow.refundCompany(2);
        vm.stopPrank();
        escrow.claimFor(hunterA);

        uint256 remaining = escrow.unlockedBalance(); // read first: vm.prank covers only the next call
        vm.prank(company);
        escrow.withdraw(remaining);

        // 10 ETH went in; hunter got 5, company got the other 5 back
        assertEq(hunterA.balance, 5 ether);
        assertEq(address(escrow).balance, 0);
        assertEq(company.balance, 100 ether - 10 ether + 5 ether);
    }
}
