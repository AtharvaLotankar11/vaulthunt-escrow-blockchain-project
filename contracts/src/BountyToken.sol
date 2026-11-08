// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BountyToken
 * @notice ERC-20 token for staking, fees, and jury participation
 * @dev Includes a faucet function for testnet use
 */
contract BountyToken is ERC20, Ownable {
    uint256 public constant FAUCET_AMOUNT = 100 * 10**18; // 100 tokens
    uint256 public constant FAUCET_COOLDOWN = 1 days;
    
    mapping(address => uint256) public lastFaucetTime;
    
    event FaucetUsed(address indexed user, uint256 amount);
    
    /**
     * @notice Constructor mints initial supply to deployer
     * @param initialSupply Initial token supply (in wei units)
     */
    constructor(uint256 initialSupply) ERC20("BountyToken", "BBT") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @notice Faucet function for testnet - mints tokens to caller
     * @dev Rate-limited to once per FAUCET_COOLDOWN period
     */
    function faucet() external {
        require(
            lastFaucetTime[msg.sender] == 0 || block.timestamp >= lastFaucetTime[msg.sender] + FAUCET_COOLDOWN,
            "BountyToken: faucet cooldown not elapsed"
        );
        
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
        
        emit FaucetUsed(msg.sender, FAUCET_AMOUNT);
    }
    
    /**
     * @notice Owner can mint additional tokens if needed
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
