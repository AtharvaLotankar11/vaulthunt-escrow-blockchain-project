// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployBase} from "../script/DeployBase.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @notice Checks the exact wiring the Deploy script produces.
contract DeployWiringTest is Test, DeployBase {
    Deployed internal d;
    Params internal p;

    function setUp() public {
        p = _demoParams();
        d = _deploy(p);
    }

    function testEverythingIsDeployed() public view {
        assertGt(address(d.token).code.length, 0);
        assertGt(address(d.treasury).code.length, 0);
        assertGt(address(d.sbt).code.length, 0);
        assertGt(address(d.factory).code.length, 0);
        assertGt(address(d.registry).code.length, 0);
        assertGt(address(d.court).code.length, 0);
        assertGt(d.factory.implementation().code.length, 0); // the escrow logic contract
    }

    function testContractsPointAtEachOther() public view {
        assertEq(d.factory.registry(), address(d.registry));
        assertEq(d.sbt.owner(), address(d.registry));
        assertEq(d.registry.court(), address(d.court));
        assertEq(address(d.registry.factory()), address(d.factory));
        assertEq(address(d.registry.sbt()), address(d.sbt));
        assertEq(d.court.registry(), address(d.registry));
        assertEq(address(d.court.token()), address(d.token));
        assertEq(d.court.treasury(), address(d.treasury));
    }

    function testParametersAreApplied() public view {
        assertEq(d.registry.reviewPeriod(), p.reviewPeriod);
        assertEq(d.registry.revealWindow(), p.revealWindow);
        assertEq(d.registry.disputeWindow(), p.disputeWindow);
        assertEq(d.court.jurorsPerCase(), 3);
        assertEq(d.court.minStake(), 100 ether);
        assertEq(d.court.disputeFee(), 10 ether);
        assertEq(d.court.commitPeriod(), 5 minutes);
        assertEq(d.token.totalSupply(), p.initialSupply);
        assertEq(d.token.balanceOf(address(this)), p.initialSupply); // the deployer holds the supply
    }

    function testWiringCannotBeRedone() public {
        vm.expectRevert("BountyFactory: registry already set");
        d.factory.setRegistry(makeAddr("evil"));

        vm.expectRevert("ReportRegistry: court already set");
        d.registry.setCourt(makeAddr("evil"));

        // the deployer no longer owns the badge contract: only the Registry can mint
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        d.sbt.mint(address(this));
    }

    function testTheEscrowLogicContractIsLockedAndClonesObeyTheRegistry() public {
        BountyEscrow implementation = BountyEscrow(d.factory.implementation());
        uint16[4] memory bps = [uint16(500), 1500, 3000, 5000];
        vm.expectRevert(); // already initialized by its constructor lock
        implementation.initialize(address(this), address(this), bps);

        (, address escrowAddress) = d.factory.createProgram{value: 1 ether}(address(this), bps);
        assertEq(BountyEscrow(escrowAddress).registry(), address(d.registry));
    }

    function testDemoWindowsAreShortButNotZero() public view {
        assertEq(p.reviewPeriod, 10 minutes);
        assertEq(p.revealWindow, 10 minutes);
        assertEq(p.disputeWindow, 10 minutes);
        assertGt(p.court.unstakeCooldown, 0);
    }

    receive() external payable {}
}
