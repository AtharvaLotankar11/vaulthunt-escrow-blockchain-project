// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {BountyToken} from "../src/BountyToken.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {DisputeCourt} from "../src/DisputeCourt.sol";

/// @notice Fills a LOCAL Anvil chain with demo data so the app can be tried at once:
///         tokens for everybody, five staked jurors, a funded court reserve, one funded program.
///
/// Run after Deploy.s.sol, on Anvil only:
///   forge script script/Seed.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
///
/// It uses Anvil's built-in test accounts (their keys are public and worthless outside
/// Anvil), derived from Anvil's default mnemonic, so no key needs to be passed in.
///   0 deployer   1 company   2 hunter   3 hunter2   4..8 jurors
contract Seed is Script {
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";

    function run() external {
        require(block.chainid == 31337, "Seed: local Anvil chain only");

        string memory json = vm.readFile("./deployments/31337.json");
        BountyToken token = BountyToken(vm.parseJsonAddress(json, ".token"));
        BountyFactory factory = BountyFactory(vm.parseJsonAddress(json, ".factory"));
        DisputeCourt court = DisputeCourt(vm.parseJsonAddress(json, ".court"));

        uint256 deployerKey = vm.deriveKey(MNEMONIC, 0);
        uint256 companyKey = vm.deriveKey(MNEMONIC, 1);
        address company = vm.addr(companyKey);

        // 1. the deployer (who holds all the BBT) hands out tokens and funds the court reserve
        vm.startBroadcast(deployerKey);
        for (uint32 i = 2; i <= 8; i++) {
            token.transfer(vm.addr(vm.deriveKey(MNEMONIC, i)), 1000 ether);
        }
        token.approve(address(court), 200 ether);
        court.fundReserve(200 ether);
        vm.stopBroadcast();

        // 2. the two hunters approve the court (they pay dispute fees with BBT)
        for (uint32 i = 2; i <= 3; i++) {
            vm.startBroadcast(vm.deriveKey(MNEMONIC, i));
            token.approve(address(court), type(uint256).max);
            vm.stopBroadcast();
        }

        // 3. five jurors stake the minimum
        uint256 minStake = court.minStake();
        for (uint32 i = 4; i <= 8; i++) {
            vm.startBroadcast(vm.deriveKey(MNEMONIC, i));
            token.approve(address(court), type(uint256).max);
            court.stake(minStake);
            vm.stopBroadcast();
        }

        // 4. the company opens one funded demo program (Low 5%, Medium 15%, High 30%, Critical 50%)
        vm.startBroadcast(companyKey);
        factory.createProgram{value: 10 ether}(company, [uint16(500), 1500, 3000, 5000]);
        vm.stopBroadcast();

        console.log("Seeded. Anvil accounts: 0 deployer, 1 company, 2 hunter, 3 hunter2, 4-8 jurors");
        console.log("Company  ", company);
        console.log("Hunter   ", vm.addr(vm.deriveKey(MNEMONIC, 2)));
        console.log("Hunter 2 ", vm.addr(vm.deriveKey(MNEMONIC, 3)));
        console.log("Court pool size", court.poolSize());
        console.log("Demo programs  ", factory.programCount());
    }
}
