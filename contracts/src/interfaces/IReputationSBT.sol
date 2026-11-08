// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice The two ReputationSBT functions the ReportRegistry calls (both are onlyOwner,
///         so the Registry must be made the SBT's owner at deploy time).
interface IReputationSBT {
    function mint(address hunter) external returns (uint256 tokenId);

    function updateLevel(uint256 tokenId, uint256 newLevel, uint256 newXP) external;
}
