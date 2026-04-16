// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 10_QueueWave2
/// @notice Queues the two Wave 2 proposals in the TimelockController.
///
/// @dev Run after voting period ends for Wave 2 proposals.
///
/// Run:
///   forge script script/seed/10_QueueWave2.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv
///
/// After: wait 1 hour (3600s), then run 11_ExecuteWave2.s.sol
contract QueueWave2 is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        uint256 propId5 = _proposalId(acme, AMOUNT_P5, descP5(acme));
        uint256 propId6 = _proposalId(acme, AMOUNT_P6, descP6(acme));

        console.log("=== 10_QueueWave2: Queue Wave 2 proposals ===");
        console.log("P5 state:", uint8(GOVERNOR.state(propId5)), "(4=Succeeded)");
        console.log("P6 state:", uint8(GOVERNOR.state(propId6)), "(4=Succeeded)");
        console.log("");

        (address[] memory t5, uint256[] memory v5, bytes[] memory c5) = _proposalActions(acme, AMOUNT_P5);
        (address[] memory t6, uint256[] memory v6, bytes[] memory c6) = _proposalActions(acme, AMOUNT_P6);

        vm.startBroadcast();
        console.log("Queueing P5...");
        GOVERNOR.queue(t5, v5, c5, keccak256(bytes(descP5(acme))));
        console.log("Queueing P6...");
        GOVERNOR.queue(t6, v6, c6, keccak256(bytes(descP6(acme))));
        vm.stopBroadcast();

        console.log("");
        console.log("=== 10_QueueWave2 complete ===");
        console.log("Both Wave 2 proposals queued. TimelockController delay: 3600s (1 hour).");
        console.log("Execute after:", block.timestamp + 3600, "(unix timestamp)");
        console.log("");
        console.log("After 1 hour: run 11_ExecuteWave2.s.sol");
    }

    function _proposalId(address acme, uint256 amount, string memory desc)
        internal
        view
        returns (uint256)
    {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _proposalActions(acme, amount);
        return GOVERNOR.hashProposal(targets, values, calldatas, keccak256(bytes(desc)));
    }
}
