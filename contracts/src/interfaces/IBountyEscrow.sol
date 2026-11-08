// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title IBountyEscrow
/// @notice What the ReportRegistry (Phase 3) needs from a program's escrow.
interface IBountyEscrow {
    enum Severity {
        Low,
        Medium,
        High,
        Critical
    }

    function lock(uint256 reportId, Severity severity) external;

    function payHunter(uint256 reportId, address hunter, Severity severity) external;

    function refundCompany(uint256 reportId) external;

    /// @notice Push a hunter's credited reward to them (anyone may call; capped gas).
    function claimFor(address hunter) external;

    function owner() external view returns (address);

    function registry() external view returns (address);
}
