// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 05_QueueWave1
/// @notice Queues all four Wave 1 proposals in the TimelockController.
///         Any address can call queue() once a proposal has Succeeded.
///         Queuing schedules execution: readyTime = block.timestamp + TIMELOCK_DELAY (3600s).
///
/// @dev Run after the voting period ends (~100 blocks from proposal creation).
///      Proposals must be in Succeeded state (state() == 4).
///
/// Run:
///   forge script script/seed/05_QueueWave1.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv
///
/// After running: timelockDelay = 3600s (1 hour).
///   - Immediately run 07_SubmitWave2ECFPs.s.sol (if not done during voting)
///   - After 1 hour, run 06_ExecuteWave1.s.sol
contract QueueWave1 is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        uint256 propId1 = _proposalId(acme, AMOUNT_P1, descP1(acme));
        uint256 propId2 = _proposalId(acme, AMOUNT_P2, descP2(acme));
        uint256 propId3 = _proposalId(acme, AMOUNT_P3, descP3(acme));
        uint256 propId4 = _proposalId(acme, AMOUNT_P4, descP4(acme));

        console.log("=== 05_QueueWave1: Queue Wave 1 proposals ===");
        console.log("Proposal states (4=Succeeded, 5=Queued, 7=Executed):");
        console.log("  P1 state:", uint8(GOVERNOR.state(propId1)));
        console.log("  P2 state:", uint8(GOVERNOR.state(propId2)));
        console.log("  P3 state:", uint8(GOVERNOR.state(propId3)));
        console.log("  P4 state:", uint8(GOVERNOR.state(propId4)));
        console.log("");

        (address[] memory t1, uint256[] memory v1, bytes[] memory c1) = _proposalActions(acme, AMOUNT_P1);
        (address[] memory t2, uint256[] memory v2, bytes[] memory c2) = _proposalActions(acme, AMOUNT_P2);
        (address[] memory t3, uint256[] memory v3, bytes[] memory c3) = _proposalActions(acme, AMOUNT_P3);
        (address[] memory t4, uint256[] memory v4, bytes[] memory c4) = _proposalActions(acme, AMOUNT_P4);

        vm.startBroadcast();

        console.log("Queueing P1...");
        GOVERNOR.queue(t1, v1, c1, keccak256(bytes(descP1(acme))));

        console.log("Queueing P2...");
        GOVERNOR.queue(t2, v2, c2, keccak256(bytes(descP2(acme))));

        console.log("Queueing P3...");
        GOVERNOR.queue(t3, v3, c3, keccak256(bytes(descP3(acme))));

        console.log("Queueing P4...");
        GOVERNOR.queue(t4, v4, c4, keccak256(bytes(descP4(acme))));

        vm.stopBroadcast();

        console.log("");
        console.log("=== 05_QueueWave1 complete ===");
        console.log("All 4 proposals queued. TimelockController delay: 3600s (1 hour).");
        console.log("Execute after:", block.timestamp + 3600, "(unix timestamp)");
        console.log("");
        console.log("While waiting for timelock:");
        console.log("  Run 07_SubmitWave2ECFPs.s.sol (ACME key) now");
        console.log("  Then 08_ActivateWave2.s.sol after 5 minutes");
        console.log("  Then 09_VoteWave2.s.sol after 1 block");
        console.log("");
        console.log("After 1 hour: run 06_ExecuteWave1.s.sol");
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
