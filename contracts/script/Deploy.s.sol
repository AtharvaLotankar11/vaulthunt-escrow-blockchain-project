// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "./DeployBase.sol";

/// @notice Deploys the whole platform and writes the addresses to deployments/<chainId>.json.
///
/// Local Anvil (start `anvil` first, it prints test accounts and their private keys):
///   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <anvil account 0 key>
///
/// Sepolia (use a keystore account instead of pasting a key; see SECURITY.md):
///   forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify --account deployer
///
/// Optional environment overrides (seconds): REVIEW_PERIOD, REVEAL_WINDOW, DISPUTE_WINDOW,
/// COMMIT_PERIOD, COURT_REVEAL_PERIOD, UNSTAKE_COOLDOWN.
contract Deploy is Script, DeployBase {
    function run() external returns (Deployed memory d) {
        Params memory p = _paramsFromEnvironment();

        vm.startBroadcast();
        d = _deploy(p);
        vm.stopBroadcast();

        _log(d);
        _write(d);
    }

    function _paramsFromEnvironment() internal view returns (Params memory p) {
        p = _demoParams();
        p.reviewPeriod = _seconds("REVIEW_PERIOD", p.reviewPeriod);
        p.revealWindow = _seconds("REVEAL_WINDOW", p.revealWindow);
        p.disputeWindow = _seconds("DISPUTE_WINDOW", p.disputeWindow);
        p.court.commitPeriod = _seconds("COMMIT_PERIOD", p.court.commitPeriod);
        p.court.revealPeriod = _seconds("COURT_REVEAL_PERIOD", p.court.revealPeriod);
        p.court.unstakeCooldown = _seconds("UNSTAKE_COOLDOWN", p.court.unstakeCooldown);
    }

    function _seconds(string memory name, uint64 fallbackValue) internal view returns (uint64) {
        uint256 value = vm.envOr(name, uint256(fallbackValue));
        require(value > 0 && value <= type(uint64).max, "Deploy: period out of range");
        return uint64(value);
    }

    function _log(Deployed memory d) internal view {
        console.log("BountyToken      ", address(d.token));
        console.log("PlatformTreasury ", address(d.treasury));
        console.log("ReputationSBT    ", address(d.sbt));
        console.log("BountyFactory    ", address(d.factory));
        console.log("BountyEscrow impl", d.factory.implementation());
        console.log("ReportRegistry   ", address(d.registry));
        console.log("DisputeCourt     ", address(d.court));
        console.log("ProgramDirectory ", address(d.directory));
    }

    function _write(Deployed memory d) internal {
        string memory key = "deployment";
        vm.serializeUint(key, "chainId", block.chainid);
        vm.serializeUint(key, "deploymentBlock", block.number); // the app reads events from here
        vm.serializeAddress(key, "deployer", d.token.owner());
        vm.serializeAddress(key, "token", address(d.token));
        vm.serializeAddress(key, "treasury", address(d.treasury));
        vm.serializeAddress(key, "sbt", address(d.sbt));
        vm.serializeAddress(key, "factory", address(d.factory));
        vm.serializeAddress(key, "escrowImplementation", d.factory.implementation());
        vm.serializeAddress(key, "registry", address(d.registry));
        vm.serializeAddress(key, "court", address(d.court));
        string memory json = vm.serializeAddress(key, "directory", address(d.directory));

        string memory path = string.concat("./deployments/", vm.toString(block.chainid), ".json");
        vm.writeJson(json, path);
        console.log("Addresses written to", path);
    }
}
