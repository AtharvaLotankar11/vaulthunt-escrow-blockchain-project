// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";
import "../src/PlatformTreasury.sol";
import "../src/BountyToken.sol";

contract PlatformTreasuryTest is Test {
    PlatformTreasury public treasury;
    BountyToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        treasury = new PlatformTreasury();
        token = new BountyToken(1_000_000 * 10**18);
        
        // Fund user1 with some ETH and tokens
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        token.transfer(user1, 10000 * 10**18);
    }
    
    receive() external payable {}
    
    function testDepositEthViaReceive() public {
        vm.prank(user1);
        (bool success, ) = address(treasury).call{value: 1 ether}("");
        
        assertTrue(success);
        assertEq(treasury.getEthBalance(), 1 ether);
    }
    
    function testDepositEthViaFunction() public {
        vm.prank(user1);
        treasury.depositEth{value: 2 ether}();
        
        assertEq(treasury.getEthBalance(), 2 ether);
    }
    
    function testDepositEthZeroAmountReverts() public {
        vm.prank(user1);
        vm.expectRevert("PlatformTreasury: deposit amount must be greater than zero");
        treasury.depositEth{value: 0}();
    }
    
    function testWithdrawEth() public {
        // Deposit ETH
        vm.prank(user1);
        treasury.depositEth{value: 5 ether}();
        
        uint256 initialBalance = user2.balance;
        
        // Owner withdraws to user2
        treasury.withdrawEth(payable(user2), 3 ether);
        
        assertEq(treasury.getEthBalance(), 2 ether);
        assertEq(user2.balance, initialBalance + 3 ether);
    }
    
    function testWithdrawEthInsufficientBalance() public {
        vm.prank(user1);
        treasury.depositEth{value: 1 ether}();
        
        vm.expectRevert("PlatformTreasury: insufficient ETH balance");
        treasury.withdrawEth(payable(user2), 2 ether);
    }
    
    function testNonOwnerCannotWithdrawEth() public {
        vm.prank(user1);
        treasury.depositEth{value: 1 ether}();
        
        vm.prank(user1);
        vm.expectRevert();
        treasury.withdrawEth(payable(user1), 1 ether);
    }
    
    function testDepositToken() public {
        uint256 depositAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        token.approve(address(treasury), depositAmount);
        treasury.depositToken(address(token), depositAmount);
        vm.stopPrank();
        
        assertEq(treasury.getTokenBalance(address(token)), depositAmount);
        assertEq(token.balanceOf(user1), 9000 * 10**18);
    }
    
    function testDepositTokenZeroAmountReverts() public {
        vm.prank(user1);
        vm.expectRevert("PlatformTreasury: deposit amount must be greater than zero");
        treasury.depositToken(address(token), 0);
    }
    
    function testWithdrawToken() public {
        uint256 depositAmount = 5000 * 10**18;
        
        vm.startPrank(user1);
        token.approve(address(treasury), depositAmount);
        treasury.depositToken(address(token), depositAmount);
        vm.stopPrank();
        
        // Owner withdraws tokens to user2
        treasury.withdrawToken(address(token), user2, 2000 * 10**18);
        
        assertEq(treasury.getTokenBalance(address(token)), 3000 * 10**18);
        assertEq(token.balanceOf(user2), 2000 * 10**18);
    }
    
    function testNonOwnerCannotWithdrawToken() public {
        uint256 depositAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        token.approve(address(treasury), depositAmount);
        treasury.depositToken(address(token), depositAmount);
        
        vm.expectRevert();
        treasury.withdrawToken(address(token), user1, depositAmount);
        vm.stopPrank();
    }
    
    function testMultipleDepositsAndWithdrawals() public {
        // Multiple ETH deposits
        vm.prank(user1);
        treasury.depositEth{value: 1 ether}();
        
        vm.prank(user2);
        treasury.depositEth{value: 2 ether}();
        
        assertEq(treasury.getEthBalance(), 3 ether);
        
        // Partial withdrawal
        treasury.withdrawEth(payable(owner), 1.5 ether);
        
        assertEq(treasury.getEthBalance(), 1.5 ether);
    }
    
    function testGetBalances() public {
        assertEq(treasury.getEthBalance(), 0);
        assertEq(treasury.getTokenBalance(address(token)), 0);
        
        vm.prank(user1);
        treasury.depositEth{value: 1 ether}();
        
        assertEq(treasury.getEthBalance(), 1 ether);
    }
}
