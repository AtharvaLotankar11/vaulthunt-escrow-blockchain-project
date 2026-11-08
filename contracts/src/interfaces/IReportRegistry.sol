// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice What the DisputeCourt needs from the ReportRegistry.
interface IReportRegistry {
    /// @notice Apply the jury's decision (only the Court may call it).
    function applyVerdict(uint256 reportId, bool hunterWins) external;

    /// @notice The company that owns the program a report was filed against.
    function programOwnerOf(uint256 reportId) external view returns (address);
}
