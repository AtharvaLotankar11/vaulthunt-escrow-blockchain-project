// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PlatformTreasury
 * @notice Holds platform fees and slashed stakes
 * @dev Owner-controlled vault for ETH and ERC20 tokens
 */
contract PlatformTreasury is Ownable {
    using SafeERC20 for IERC20;
    
    event EthDeposited(address indexed from, uint256 amount);
    event EthWithdrawn(address indexed to, uint256 amount);
    event TokenDeposited(address indexed token, address indexed from, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    
    /**
     * @notice Constructor
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Receive ETH deposits
     */
    receive() external payable {
        emit EthDeposited(msg.sender, msg.value);
    }
    
    /**
     * @notice Deposit ETH to treasury
     */
    function depositEth() external payable {
        require(msg.value > 0, "PlatformTreasury: deposit amount must be greater than zero");
        emit EthDeposited(msg.sender, msg.value);
    }
    
    /**
     * @notice Deposit ERC20 tokens to treasury
     * @param token Token address
     * @param amount Amount to deposit
     */
    function depositToken(address token, uint256 amount) external {
        require(amount > 0, "PlatformTreasury: deposit amount must be greater than zero");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        emit TokenDeposited(token, msg.sender, amount);
    }
    
    /**
     * @notice Withdraw ETH from treasury (owner only)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawEth(address payable to, uint256 amount) external onlyOwner {
        require(amount > 0, "PlatformTreasury: withdraw amount must be greater than zero");
        require(address(this).balance >= amount, "PlatformTreasury: insufficient ETH balance");
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "PlatformTreasury: ETH transfer failed");
        
        emit EthWithdrawn(to, amount);
    }
    
    /**
     * @notice Withdraw ERC20 tokens from treasury (owner only)
     * @param token Token address
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        require(amount > 0, "PlatformTreasury: withdraw amount must be greater than zero");
        
        IERC20(token).safeTransfer(to, amount);
        
        emit TokenWithdrawn(token, to, amount);
    }
    
    /**
     * @notice Get ETH balance of treasury
     * @return ETH balance
     */
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Get ERC20 token balance of treasury
     * @param token Token address
     * @return Token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
