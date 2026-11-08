// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {ProgramDirectory} from "../src/ProgramDirectory.sol";

contract ProgramDirectoryTest is Test {
    BountyFactory internal factory;
    ProgramDirectory internal directory;
    address internal company = makeAddr("company");
    address internal otherCompany = makeAddr("otherCompany");
    address internal stranger = makeAddr("stranger");
    uint256 internal programId;

    event ProfileSet(uint256 indexed programId, address indexed programOwner, string uri, uint64 version);

    function setUp() public {
        factory = new BountyFactory();
        factory.setRegistry(makeAddr("registry"));
        directory = new ProgramDirectory(address(factory));
        vm.prank(company);
        (programId,) = factory.createProgram(company, [uint16(500), 1500, 3000, 5000]);
    }

    function testConstructorRejectsZeroFactory() public {
        vm.expectRevert("ProgramDirectory: factory is zero address");
        new ProgramDirectory(address(0));
    }

    function testUnsetProfileIsEmpty() public view {
        assertEq(directory.profileURI(programId), "");
        assertEq(directory.profileVersion(programId), 0);
    }

    function testOwnerSetsProfile() public {
        vm.expectEmit(true, true, false, true);
        emit ProfileSet(programId, company, "bafyProfile", 1);
        vm.prank(company);
        directory.setProfile(programId, "bafyProfile");

        assertEq(directory.profileURI(programId), "bafyProfile");
        assertEq(directory.profileVersion(programId), 1);
    }

    function testOwnerCanUpdateAndVersionGrows() public {
        vm.startPrank(company);
        directory.setProfile(programId, "first");
        directory.setProfile(programId, "second");
        vm.stopPrank();

        assertEq(directory.profileURI(programId), "second");
        assertEq(directory.profileVersion(programId), 2);
    }

    function testNonOwnerCannotSetProfile() public {
        vm.prank(stranger);
        vm.expectRevert("ProgramDirectory: caller is not the program owner");
        directory.setProfile(programId, "evil");

        vm.prank(otherCompany);
        vm.expectRevert("ProgramDirectory: caller is not the program owner");
        directory.setProfile(programId, "evil");
    }

    function testUnknownProgramReverts() public {
        vm.prank(company);
        vm.expectRevert("ProgramDirectory: unknown program");
        directory.setProfile(99, "x");
    }

    function testEmptyUriReverts() public {
        vm.prank(company);
        vm.expectRevert("ProgramDirectory: empty uri");
        directory.setProfile(programId, "");
    }

    function testTooLongUriReverts() public {
        bytes memory longUri = new bytes(161);
        for (uint256 i = 0; i < longUri.length; i++) {
            longUri[i] = "a";
        }
        vm.prank(company);
        vm.expectRevert("ProgramDirectory: uri too long");
        directory.setProfile(programId, string(longUri));
    }

    function testMaxLengthUriWorks() public {
        bytes memory maxUri = new bytes(160);
        for (uint256 i = 0; i < maxUri.length; i++) {
            maxUri[i] = "b";
        }
        vm.prank(company);
        directory.setProfile(programId, string(maxUri));
        assertEq(bytes(directory.profileURI(programId)).length, 160);
    }

    function testProfilesOfDifferentProgramsAreSeparate() public {
        vm.prank(otherCompany);
        (uint256 second,) = factory.createProgram(otherCompany, [uint16(100), 200, 300, 400]);

        vm.prank(company);
        directory.setProfile(programId, "mine");
        vm.prank(otherCompany);
        directory.setProfile(second, "theirs");

        assertEq(directory.profileURI(programId), "mine");
        assertEq(directory.profileURI(second), "theirs");
    }
}
