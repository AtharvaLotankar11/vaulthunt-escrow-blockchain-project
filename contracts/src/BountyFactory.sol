// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {BountyEscrow} from "./BountyEscrow.sol";

/// @title BountyFactory
/// @notice Creates one BountyEscrow per program as a cheap EIP-1167 clone and keeps the list
///         of all programs.
/// @dev The Registry address is set once after deployment (Registry and Factory need each
///      other's address, so one of them has to be linked afterwards).
contract BountyFactory is Ownable {
    /// @notice The escrow logic contract that every clone points to.
    address public immutable implementation;

    /// @notice The ReportRegistry; set once by the owner.
    address public registry;

    uint256 public programCount;
    mapping(uint256 programId => address escrow) public programs;
    mapping(address owner => uint256[]) private _programsByOwner;

    event RegistrySet(address indexed registry);
    event ProgramCreated(
        uint256 indexed programId, address indexed escrow, address indexed programOwner, uint16[4] payoutBps, uint256 funded
    );

    constructor() Ownable(msg.sender) {
        implementation = address(new BountyEscrow());
    }

    /// @notice One-time link to the ReportRegistry.
    function setRegistry(address registry_) external onlyOwner {
        require(registry == address(0), "BountyFactory: registry already set");
        require(registry_ != address(0), "BountyFactory: registry is zero address");
        registry = registry_;
        emit RegistrySet(registry_);
    }

    /// @notice Create a program. Any ETH sent becomes the program's first deposit.
    /// @param programOwner The company that will own the escrow.
    /// @param payoutBps Payout tiers in basis points: Low, Medium, High, Critical.
    function createProgram(address programOwner, uint16[4] calldata payoutBps)
        external
        payable
        returns (uint256 programId, address escrow)
    {
        require(registry != address(0), "BountyFactory: registry not set");

        escrow = Clones.clone(implementation);

        // Record everything first, then call the new escrow (state before external calls).
        programId = programCount;
        programCount = programId + 1;
        programs[programId] = escrow;
        _programsByOwner[programOwner].push(programId);
        emit ProgramCreated(programId, escrow, programOwner, payoutBps, msg.value);

        BountyEscrow(escrow).initialize{value: msg.value}(registry, programOwner, payoutBps);
    }

    /// @notice All program ids created for an owner.
    function programsOf(address programOwner) external view returns (uint256[] memory) {
        return _programsByOwner[programOwner];
    }
}
