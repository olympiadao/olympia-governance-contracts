// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OlympiaGovernor} from "../src/OlympiaGovernor.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title RepairGovernor
/// @notice Redeploys OlympiaGovernor with CREATE2 after initial deployment failed
///         due to gas estimation. Uses original salt (address not burned — failed
///         CREATE2 doesn't deploy code). Requires via_ir=true in foundry.toml to
///         reduce bytecode below 8M gas limit. Use with --slow --gas-estimate-multiplier 130.
contract RepairGovernor is Script {
    // Original salt — address not burned since CREATE2 reverted (no code deployed)
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_1");

    // Mordor testnet parameters
    uint48 constant VOTING_DELAY = 1;
    uint32 constant VOTING_PERIOD = 100;
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50;

    // Deployed addresses from initial batch
    TimelockController constant TIMELOCK = TimelockController(payable(0x1E0fADee5540a77012f1944fcce58677fC087f6e));
    address constant SANCTIONS_ORACLE = 0xEeeb33c8b7C936bD8e72A859a3e1F9cc8A26f3B4;
    address constant MEMBER_NFT = 0x720676EBfe45DECfC43c8E9870C64413a2480EE0;

    function run() public {
        console.log("=== Repair: Deploy OlympiaGovernor (CREATE2, via_ir bytecode) ===");

        vm.startBroadcast();

        // Step 1: Deploy Governor with CREATE2
        OlympiaGovernor governor = new OlympiaGovernor{salt: SALT}(
            "OlympiaGovernor",
            IVotes(MEMBER_NFT),
            ISanctionsOracle(SANCTIONS_ORACLE),
            TIMELOCK,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );
        console.log("OlympiaGovernor:", address(governor));

        // Step 2: Grant timelock roles to Governor
        // (Roles were previously granted to the same address but CREATE2 failed,
        //  so the address has the roles but no code. Re-granting is a no-op but
        //  included for completeness if roles were revoked.)
        bytes32 proposerRole = TIMELOCK.PROPOSER_ROLE();
        bytes32 executorRole = TIMELOCK.EXECUTOR_ROLE();
        bytes32 cancellerRole = TIMELOCK.CANCELLER_ROLE();

        TIMELOCK.grantRole(proposerRole, address(governor));
        TIMELOCK.grantRole(executorRole, address(governor));
        TIMELOCK.grantRole(cancellerRole, address(governor));
        console.log("Timelock roles confirmed for Governor");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Governor Deployment Complete ===");
        console.log("OlympiaGovernor:", address(governor));
    }
}
