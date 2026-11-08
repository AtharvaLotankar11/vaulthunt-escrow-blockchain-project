// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

contract BountyFactoryTest is Test {
    BountyFactory internal factory;

    address internal registry = makeAddr("registry");
    address internal company = makeAddr("company");
    address internal otherCompany = makeAddr("otherCompany");
    address internal stranger = makeAddr("stranger");

    uint16[4] internal bps = [uint16(500), 1500, 3000, 5000];

    event RegistrySet(address indexed registry);
    event ProgramCreated(
        uint256 indexed programId, address indexed escrow, address indexed programOwner, uint16[4] payoutBps, uint256 funded
    );

    function setUp() public {
        factory = new BountyFactory();
        vm.deal(company, 100 ether);
        vm.deal(otherCompany, 100 ether);
    }

    function _linkRegistry() internal {
        factory.setRegistry(registry);
    }

    // ------------------------------------------------------------------ setup

    function testOwnerIsDeployer() public view {
        assertEq(factory.owner(), address(this));
    }

    function testImplementationIsDeployedAndLocked() public {
        address implementation = factory.implementation();
        assertGt(implementation.code.length, 0);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        BountyEscrow(implementation).initialize(registry, company, bps);
    }

    function testSetRegistryOnce() public {
        vm.expectEmit(true, false, false, false);
        emit RegistrySet(registry);
        _linkRegistry();
        assertEq(factory.registry(), registry);

        vm.expectRevert("BountyFactory: registry already set");
        factory.setRegistry(makeAddr("another"));
    }

    function testSetRegistryOnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        factory.setRegistry(registry);
    }

    function testSetRegistryZeroAddressReverts() public {
        vm.expectRevert("BountyFactory: registry is zero address");
        factory.setRegistry(address(0));
    }

    // ------------------------------------------------------------------ createProgram

    function testCreateProgramRequiresRegistry() public {
        vm.prank(company);
        vm.expectRevert("BountyFactory: registry not set");
        factory.createProgram(company, bps);
    }

    function testCreateProgramFundsAndInitializesEscrow() public {
        _linkRegistry();

        vm.expectEmit(true, false, true, true);
        emit ProgramCreated(0, address(0), company, bps, 5 ether);
        vm.prank(company);
        (uint256 programId, address escrowAddress) = factory.createProgram{value: 5 ether}(company, bps);

        assertEq(programId, 0);
        assertEq(factory.programCount(), 1);
        assertEq(factory.programs(0), escrowAddress);

        BountyEscrow escrow = BountyEscrow(escrowAddress);
        assertEq(escrow.owner(), company);
        assertEq(escrow.registry(), registry);
        assertEq(escrow.fundedAmount(), 5 ether);
        assertEq(address(escrow).balance, 5 ether);
        assertEq(escrow.payoutBps(IBountyEscrow.Severity.Critical), 5000);
    }

    function testCreateProgramWithoutFunding() public {
        _linkRegistry();
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram(company, bps);
        assertEq(BountyEscrow(escrowAddress).fundedAmount(), 0);
        assertEq(escrowAddress.balance, 0);
    }

    function testCreateMultipleProgramsGivesDistinctEscrows() public {
        _linkRegistry();

        vm.prank(company);
        (uint256 id0, address escrow0) = factory.createProgram{value: 1 ether}(company, bps);
        vm.prank(company);
        (uint256 id1, address escrow1) = factory.createProgram{value: 2 ether}(company, bps);
        vm.prank(otherCompany);
        (uint256 id2, address escrow2) = factory.createProgram{value: 3 ether}(otherCompany, bps);

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(factory.programCount(), 3);
        assertTrue(escrow0 != escrow1 && escrow1 != escrow2 && escrow0 != escrow2);

        // funds are isolated per program
        assertEq(escrow0.balance, 1 ether);
        assertEq(escrow1.balance, 2 ether);
        assertEq(escrow2.balance, 3 ether);
    }

    function testProgramsOfOwner() public {
        _linkRegistry();
        vm.startPrank(company);
        factory.createProgram(company, bps);
        factory.createProgram(company, bps);
        vm.stopPrank();
        vm.prank(otherCompany);
        factory.createProgram(otherCompany, bps);

        uint256[] memory mine = factory.programsOf(company);
        assertEq(mine.length, 2);
        assertEq(mine[0], 0);
        assertEq(mine[1], 1);

        uint256[] memory theirs = factory.programsOf(otherCompany);
        assertEq(theirs.length, 1);
        assertEq(theirs[0], 2);

        assertEq(factory.programsOf(stranger).length, 0);
    }

    function testClonesAreMinimalProxies() public {
        _linkRegistry();
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram(company, bps);
        // an EIP-1167 minimal proxy has exactly 45 bytes of runtime code
        assertEq(escrowAddress.code.length, 45);
    }

    function testCreateProgramForAnotherOwner() public {
        _linkRegistry();
        vm.prank(stranger);
        (, address escrowAddress) = factory.createProgram(company, bps);
        assertEq(BountyEscrow(escrowAddress).owner(), company);
    }

    function testCreateProgramInvalidPayoutsReverts() public {
        _linkRegistry();
        uint16[4] memory bad = [uint16(500), 1500, 1000, 5000];
        vm.prank(company);
        vm.expectRevert("BountyEscrow: payouts must not decrease");
        factory.createProgram(company, bad);
        assertEq(factory.programCount(), 0);
    }

    function testCreateProgramZeroOwnerReverts() public {
        _linkRegistry();
        vm.expectRevert("BountyEscrow: owner is zero address");
        factory.createProgram(address(0), bps);
    }

    function testClonedEscrowCannotBeReinitialized() public {
        _linkRegistry();
        vm.prank(company);
        (, address escrowAddress) = factory.createProgram(company, bps);

        vm.prank(stranger);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        BountyEscrow(escrowAddress).initialize(stranger, stranger, bps);
    }
}
