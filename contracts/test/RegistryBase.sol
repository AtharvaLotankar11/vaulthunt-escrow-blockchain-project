// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";
import {IDisputeCourt} from "../src/interfaces/IDisputeCourt.sol";

/// @dev Stand-in for the Phase 4 DisputeCourt: records what the Registry sends it, and lets a
///      test play the jury's verdict.
contract MockCourt is IDisputeCourt {
    uint256 public calls;
    uint256 public lastReportId;
    address public lastHunter;
    address public lastFeePayer;
    bool public shouldRevert;

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function openCase(uint256 reportId, address hunter, address feePayer) external {
        require(!shouldRevert, "MockCourt: reverting");
        calls++;
        lastReportId = reportId;
        lastHunter = hunter;
        lastFeePayer = feePayer;
    }

    function verdict(ReportRegistry registry, uint256 reportId, bool hunterWins) external {
        registry.applyVerdict(reportId, hunterWins);
    }
}

/// @dev A hunter that is a smart contract: it can refuse ETH (toggle) and cannot receive NFTs
///      (no onERC721Received), so it exercises the "payment must never be blocked" paths.
contract ContractHunter {
    bool public rejecting = true;

    function setRejecting(bool value) external {
        rejecting = value;
    }

    function commit(ReportRegistry registry, uint256 programId, bytes32 commitHash) external returns (uint256) {
        return registry.commitReport(programId, commitHash);
    }

    function reveal(
        ReportRegistry registry,
        uint256 reportId,
        bytes32 contentHash,
        bytes32 salt,
        IBountyEscrow.Severity severity
    ) external {
        registry.revealReport(reportId, "bafyContractHunter", contentHash, salt, severity);
    }

    function claimFrom(BountyEscrow escrow) external {
        escrow.claim();
    }

    receive() external payable {
        require(!rejecting, "ContractHunter: rejecting");
    }
}

/// @dev A hunter whose NFT-receive hook burns all the gas it is given.
contract GasBurnReceiver is IERC721Receiver {
    function commit(ReportRegistry registry, uint256 programId, bytes32 commitHash) external returns (uint256) {
        return registry.commitReport(programId, commitHash);
    }

    function reveal(
        ReportRegistry registry,
        uint256 reportId,
        bytes32 contentHash,
        bytes32 salt,
        IBountyEscrow.Severity severity
    ) external {
        registry.revealReport(reportId, "bafyGasBurner", contentHash, salt, severity);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4 selector) {
        selector = bytes4(0);
        while (true) {}
    }

    receive() external payable {}
}

/// @notice Shared setup and helpers for the Registry tests.
abstract contract RegistryBase is Test {
    struct Env {
        ReportRegistry registry;
        BountyFactory factory;
        ReputationSBT sbt;
        BountyEscrow escrow;
        MockCourt court;
        uint256 programId;
    }

    uint64 internal constant PERIOD = 7 days;

    BountyFactory internal factory;
    ReputationSBT internal sbt;
    ReportRegistry internal registry;
    MockCourt internal court;
    BountyEscrow internal escrow;
    uint256 internal programId;

    address internal company = makeAddr("company");
    address internal hunter = makeAddr("hunter");
    address internal hunter2 = makeAddr("hunter2");
    address internal stranger = makeAddr("stranger");

    // Low 5%, Medium 15%, High 30%, Critical 50% of the funded amount (10 ETH):
    // 0.5, 1.5, 3 and 5 ETH.
    uint16[4] internal bps = [uint16(500), 1500, 3000, 5000];

    bytes32 internal constant CONTENT = keccak256("report-content");
    bytes32 internal constant SALT = keccak256("report-salt");

    IBountyEscrow.Severity internal constant LOW = IBountyEscrow.Severity.Low;
    IBountyEscrow.Severity internal constant MEDIUM = IBountyEscrow.Severity.Medium;
    IBountyEscrow.Severity internal constant HIGH = IBountyEscrow.Severity.High;
    IBountyEscrow.Severity internal constant CRITICAL = IBountyEscrow.Severity.Critical;

    function setUp() public virtual {
        Env memory e = _newEnvironment(bps, true, true);
        factory = e.factory;
        sbt = e.sbt;
        registry = e.registry;
        court = e.court;
        escrow = e.escrow;
        programId = e.programId;
    }

    /// @dev Builds a complete, separate deployment (used by the default setUp and by tests that
    ///      need a different configuration).
    function _newEnvironment(uint16[4] memory payout, bool linkCourt, bool giveSbtToRegistry)
        internal
        returns (Env memory e)
    {
        e.factory = new BountyFactory();
        e.sbt = new ReputationSBT();
        e.registry = new ReportRegistry(address(e.factory), address(e.sbt), PERIOD, PERIOD, PERIOD);
        e.factory.setRegistry(address(e.registry));
        if (giveSbtToRegistry) e.sbt.transferOwnership(address(e.registry));

        e.court = new MockCourt();
        if (linkCourt) e.registry.setCourt(address(e.court));

        vm.deal(company, 1000 ether);
        vm.prank(company);
        address escrowAddress;
        (e.programId, escrowAddress) = e.factory.createProgram{value: 10 ether}(company, payout);
        e.escrow = BountyEscrow(escrowAddress);
    }

    function _commitHash(bytes32 content, bytes32 salt, address who) internal pure returns (bytes32) {
        return keccak256(abi.encode(content, salt, who));
    }

    function _commitOn(ReportRegistry reg, uint256 pid, address who, bytes32 content, bytes32 salt)
        internal
        returns (uint256 id)
    {
        vm.prank(who);
        id = reg.commitReport(pid, _commitHash(content, salt, who));
    }

    function _revealOn(
        ReportRegistry reg,
        address who,
        uint256 id,
        bytes32 content,
        bytes32 salt,
        IBountyEscrow.Severity severity
    ) internal {
        vm.prank(who);
        reg.revealReport(id, "bafyTestCid", content, salt, severity);
    }

    function _commit(address who, bytes32 content, bytes32 salt) internal returns (uint256) {
        return _commitOn(registry, programId, who, content, salt);
    }

    function _reveal(address who, uint256 id, bytes32 content, bytes32 salt, IBountyEscrow.Severity severity) internal {
        _revealOn(registry, who, id, content, salt, severity);
    }

    /// @dev Commit then reveal in one go.
    function _submit(address who, bytes32 content, bytes32 salt, IBountyEscrow.Severity severity)
        internal
        returns (uint256 id)
    {
        id = _commit(who, content, salt);
        _reveal(who, id, content, salt, severity);
    }

    function _statusOf(uint256 id) internal view returns (ReportRegistry.Status) {
        return registry.getReport(id).status;
    }
}
