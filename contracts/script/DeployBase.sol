// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {BountyToken} from "../src/BountyToken.sol";
import {PlatformTreasury} from "../src/PlatformTreasury.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";
import {ProgramDirectory} from "../src/ProgramDirectory.sol";

/// @notice The deployment logic, shared by the Deploy script and by the tests, so the tests
///         check the very same wiring that gets deployed.
///
/// The eight contracts: BountyToken, PlatformTreasury, ReputationSBT, BountyFactory,
/// ReportRegistry, DisputeCourt, ProgramDirectory and the BountyEscrow logic contract (created
/// by the Factory; every program is a cheap clone of it).
abstract contract DeployBase {
    struct Params {
        uint256 initialSupply; // BBT minted to the deployer
        uint64 reviewPeriod; // seconds a company has to answer a revealed report
        uint64 revealWindow; // seconds a hunter has to reveal after committing
        uint64 disputeWindow; // seconds a hunter has to escalate after a rejection
        DisputeCourt.Config court;
    }

    struct Deployed {
        BountyToken token;
        PlatformTreasury treasury;
        ReputationSBT sbt;
        BountyFactory factory;
        ReportRegistry registry;
        DisputeCourt court;
        ProgramDirectory directory;
    }

    /// @dev Short windows so a live demo does not have to wait days. For anything real, use
    ///      days (see SECURITY.md).
    function _demoParams() internal pure returns (Params memory p) {
        p.initialSupply = 1_000_000 ether;
        p.reviewPeriod = 10 minutes;
        p.revealWindow = 10 minutes;
        p.disputeWindow = 10 minutes;
        p.court = DisputeCourt.Config({
            jurorsPerCase: 3,
            minStake: 100 ether,
            slashPerJuror: 20 ether,
            disputeFee: 10 ether,
            commitPeriod: 5 minutes,
            revealPeriod: 5 minutes,
            unstakeCooldown: 10 minutes
        });
    }

    /// @dev Deploys everything and wires it together. The caller becomes the owner of the token,
    ///      the factory and the registry.
    function _deploy(Params memory p) internal returns (Deployed memory d) {
        d.token = new BountyToken(p.initialSupply);
        d.treasury = new PlatformTreasury();
        d.sbt = new ReputationSBT();
        d.factory = new BountyFactory();
        d.registry = new ReportRegistry(
            address(d.factory), address(d.sbt), p.reviewPeriod, p.revealWindow, p.disputeWindow
        );
        d.court = new DisputeCourt(address(d.registry), address(d.token), address(d.treasury), p.court);

        // Wiring (each of these can only be done once):
        d.factory.setRegistry(address(d.registry)); // programs obey only this Registry
        d.sbt.transferOwnership(address(d.registry)); // only the Registry mints and updates badges
        d.registry.setCourt(address(d.court)); // only this Court may deliver verdicts

        // Last on purpose: adding it did not move the addresses of the contracts above.
        d.directory = new ProgramDirectory(address(d.factory));
    }
}
