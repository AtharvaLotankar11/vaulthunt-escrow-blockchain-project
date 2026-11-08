// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";
import "../src/BountyToken.sol";

contract BountyTokenTest is Test {
    BountyToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens
    uint256 constant FAUCET_AMOUNT = 100 * 10**18;
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        token = new BountyToken(INITIAL_SUPPLY);
    }
    
    function testInitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }
    
    function testTokenMetadata() public view {
        assertEq(token.name(), "BountyToken");
        assertEq(token.symbol(), "BBT");
        assertEq(token.decimals(), 18);
    }
    
    function testTransfer() public {
        uint256 transferAmount = 1000 * 10**18;
        
        token.transfer(user1, transferAmount);
        
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }
    
    function testFaucetFirstUse() public {
        vm.prank(user1);
        token.faucet();
        
        assertEq(token.balanceOf(user1), FAUCET_AMOUNT);
    }
    
    function testFaucetCooldown() public {
        vm.startPrank(user1);
        
        // First use should work
        token.faucet();
        assertEq(token.balanceOf(user1), FAUCET_AMOUNT);
        
        // Immediate second use should fail
        vm.expectRevert("BountyToken: faucet cooldown not elapsed");
        token.faucet();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Should work again
        token.faucet();
        assertEq(token.balanceOf(user1), FAUCET_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function testFaucetMultipleUsers() public {
        vm.prank(user1);
        token.faucet();
        
        vm.prank(user2);
        token.faucet();
        
        assertEq(token.balanceOf(user1), FAUCET_AMOUNT);
        assertEq(token.balanceOf(user2), FAUCET_AMOUNT);
    }
    
    function testOwnerMint() public {
        uint256 mintAmount = 5000 * 10**18;
        
        token.mint(user1, mintAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }
    
    function testNonOwnerCannotMint() public {
        uint256 mintAmount = 5000 * 10**18;
        
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, mintAmount);
    }
    
    function testBalanceChecks() public {
        uint256 amount = 500 * 10**18;
        
        token.transfer(user1, amount);
        assertEq(token.balanceOf(user1), amount);
        
        vm.prank(user1);
        token.transfer(user2, amount / 2);
        
        assertEq(token.balanceOf(user1), amount / 2);
        assertEq(token.balanceOf(user2), amount / 2);
    }
}
