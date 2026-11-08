// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice What the ReportRegistry needs from the DisputeCourt (built in Phase 4).
interface IDisputeCourt {
    /// @param reportId The disputed report.
    /// @param hunter The hunter who raised the dispute.
    /// @param feePayer Who pays the dispute fee in BBT: the hunter after a rejection, or
    ///        address(0) when the company simply did not answer before the deadline.
    function openCase(uint256 reportId, address hunter, address feePayer) external;
}
