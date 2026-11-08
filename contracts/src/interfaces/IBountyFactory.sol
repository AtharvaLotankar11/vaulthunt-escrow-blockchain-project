// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice The one thing the ReportRegistry needs from BountyFactory.
interface IBountyFactory {
    function programs(uint256 programId) external view returns (address escrow);
}
