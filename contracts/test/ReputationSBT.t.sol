// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";
import "../src/ReputationSBT.sol";

contract ReputationSBTTest is Test {
    ReputationSBT public sbt;
    address public owner;
    address public hunter1;
    address public hunter2;
    
    function setUp() public {
        owner = address(this);
        hunter1 = address(0x1);
        hunter2 = address(0x2);
        
        sbt = new ReputationSBT();
    }
    
    function testMintBadge() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        assertEq(sbt.ownerOf(tokenId), hunter1);
        assertEq(tokenId, 0);
        
        (uint256 level, uint256 xp) = sbt.getReputation(tokenId);
        assertEq(level, 1);
        assertEq(xp, 0);
    }
    
    function testMintMultipleBadges() public {
        uint256 tokenId1 = sbt.mint(hunter1);
        uint256 tokenId2 = sbt.mint(hunter2);
        
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(sbt.ownerOf(tokenId1), hunter1);
        assertEq(sbt.ownerOf(tokenId2), hunter2);
    }
    
    function testNonOwnerCannotMint() public {
        vm.prank(hunter1);
        vm.expectRevert();
        sbt.mint(hunter1);
    }
    
    function testUpdateLevel() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        sbt.updateLevel(tokenId, 5, 1200);
        
        (uint256 level, uint256 xp) = sbt.getReputation(tokenId);
        assertEq(level, 5);
        assertEq(xp, 1200);
    }
    
    function testNonOwnerCannotUpdateLevel() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        vm.prank(hunter1);
        vm.expectRevert();
        sbt.updateLevel(tokenId, 5, 1200);
    }
    
    function testTransferFromReverts() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        // Attempt transfer from hunter1 to hunter2 should revert
        vm.prank(hunter1);
        vm.expectRevert("ReputationSBT: token is soulbound and cannot be transferred");
        sbt.transferFrom(hunter1, hunter2, tokenId);
        
        // Token should still belong to hunter1
        assertEq(sbt.ownerOf(tokenId), hunter1);
    }
    
    function testSafeTransferFromReverts() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        // Attempt safe transfer should revert
        vm.prank(hunter1);
        vm.expectRevert("ReputationSBT: token is soulbound and cannot be transferred");
        sbt.safeTransferFrom(hunter1, hunter2, tokenId);
        
        // Token should still belong to hunter1
        assertEq(sbt.ownerOf(tokenId), hunter1);
    }
    
    function testApproveAndTransferReverts() public {
        uint256 tokenId = sbt.mint(hunter1);
        
        // Hunter1 approves hunter2
        vm.prank(hunter1);
        sbt.approve(hunter2, tokenId);
        
        // Approved address should be set
        assertEq(sbt.getApproved(tokenId), hunter2);
        
        // But transfer should still revert (soulbound)
        vm.prank(hunter2);
        vm.expectRevert("ReputationSBT: token is soulbound and cannot be transferred");
        sbt.transferFrom(hunter1, hunter2, tokenId);
        
        // Token should still belong to hunter1
        assertEq(sbt.ownerOf(tokenId), hunter1);
    }
    
    function testTokenMetadata() public view {
        assertEq(sbt.name(), "VaultHunt Reputation");
        assertEq(sbt.symbol(), "VHREP");
    }
    
    function testTokenURI() public {
        uint256 tokenId = sbt.mint(hunter1);
        sbt.updateLevel(tokenId, 3, 500);
        
        string memory uri = sbt.tokenURI(tokenId);
        
        // Should return a data URI (basic check)
        assertTrue(bytes(uri).length > 0);
    }
    
    function testGetReputationNonExistentToken() public {
        vm.expectRevert("ReputationSBT: token does not exist");
        sbt.getReputation(999);
    }
    
    function testUpdateNonExistentToken() public {
        vm.expectRevert("ReputationSBT: token does not exist");
        sbt.updateLevel(999, 5, 1000);
    }
}
