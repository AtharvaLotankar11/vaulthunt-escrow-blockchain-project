// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {DeployBase} from "../script/DeployBase.sol";
import {BountyToken} from "../src/BountyToken.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";
import {PlatformTreasury} from "../src/PlatformTreasury.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";

/// @notice The WHOLE platform, deployed by the same code the Deploy script uses
///         (DeployBase._deploy), with demo-length windows, plus actors and helpers.
///         Used by the scenario, fuzz and wiring tests.
abstract contract SystemBase is Test, DeployBase {
    Deployed internal d;
    BountyToken internal token;
    PlatformTreasury internal treasury;
    ReputationSBT internal sbt;
    BountyFactory internal factory;
    ReportRegistry internal registry;
    DisputeCourt internal court;
    BountyEscrow internal escrow;
    uint256 internal programId;
    Params internal params;

    address internal company = makeAddr("company");
    address internal hunter = makeAddr("hunter");
    address internal hunter2 = makeAddr("hunter2");
    address internal stranger = makeAddr("stranger");
    address[] internal jurors;

    // Low 5%, Medium 15%, High 30%, Critical 50% of the 10 ETH program: 0.5, 1.5, 3 and 5 ETH
    uint16[4] internal bps = [uint16(500), 1500, 3000, 5000];

    bytes32 internal constant CONTENT = keccak256("report-content");
    bytes32 internal constant SALT = keccak256("report-salt");

    IBountyEscrow.Severity internal constant LOW = IBountyEscrow.Severity.Low;
    IBountyEscrow.Severity internal constant MEDIUM = IBountyEscrow.Severity.Medium;
    IBountyEscrow.Severity internal constant HIGH = IBountyEscrow.Severity.High;
    IBountyEscrow.Severity internal constant CRITICAL = IBountyEscrow.Severity.Critical;

    function setUp() public virtual {
        params = _demoParams();
        d = _deploy(params);
        token = d.token;
        treasury = d.treasury;
        sbt = d.sbt;
        factory = d.factory;
        registry = d.registry;
        court = d.court;

        for (uint256 i = 0; i < 5; i++) {
            address juror = makeAddr(string.concat("juror", vm.toString(i)));
            jurors.push(juror);
            token.transfer(juror, 1000 ether);
            vm.startPrank(juror);
            token.approve(address(court), type(uint256).max);
            court.stake(params.court.minStake);
            vm.stopPrank();
        }
        _giveTokens(hunter, 1000 ether);
        _giveTokens(hunter2, 1000 ether);

        vm.deal(company, 1000 ether);
        vm.prank(company);
        address escrowAddress;
        (programId, escrowAddress) = factory.createProgram{value: 10 ether}(company, bps);
        escrow = BountyEscrow(escrowAddress);
    }

    function _giveTokens(address who, uint256 amount) internal {
        token.transfer(who, amount);
        vm.prank(who);
        token.approve(address(court), type(uint256).max);
    }

    // ------------------------------------------------------------------ report helpers

    function _commitHash(bytes32 content, bytes32 salt, address who) internal pure returns (bytes32) {
        return keccak256(abi.encode(content, salt, who));
    }

    function _submit(address who, bytes32 content, bytes32 salt, IBountyEscrow.Severity severity)
        internal
        returns (uint256 id)
    {
        vm.startPrank(who);
        id = registry.commitReport(programId, _commitHash(content, salt, who));
        registry.revealReport(id, "bafyReport", content, salt, severity);
        vm.stopPrank();
    }

    function _status(uint256 id) internal view returns (ReportRegistry.Status) {
        return registry.getReport(id).status;
    }

    // ------------------------------------------------------------------ dispute helpers

    function _jurorSalt(address juror) internal pure returns (bytes32) {
        return keccak256(abi.encode("juror-salt", juror));
    }

    function _escalateAfterRejection(uint256 reportId) internal returns (uint256 caseId) {
        vm.startPrank(hunter);
        court.payDisputeFee(reportId);
        registry.escalate(reportId);
        vm.stopPrank();
        caseId = court.caseOfReport(reportId);
    }

    /// @dev All three drawn jurors commit and reveal; votes[i] is the vote of the i-th drawn juror.
    function _juryVotes(uint256 caseId, bool[3] memory votes) internal {
        address[] memory js = court.jurorsOf(caseId);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(js[i]);
            court.commitVote(caseId, keccak256(abi.encode(votes[i], _jurorSalt(js[i]), js[i], caseId)));
        }
        vm.warp(court.getCase(caseId).commitDeadline + 1);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(js[i]);
            court.revealVote(caseId, votes[i], _jurorSalt(js[i]));
        }
    }
}
