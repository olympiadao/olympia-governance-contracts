// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OlympiaGovernor} from "../src/OlympiaGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeployGovernance
/// @notice Deploys the governance pipeline: TimelockController, OlympiaGovernor, OlympiaExecutor, ECFPRegistry
/// @dev Uses CREATE2 for deterministic addresses. Resolves circular dependency between Timelock and Governor
///      by precomputing the Governor address before deploying the Timelock.
contract DeployGovernance is Script {
    // CREATE2 salt — Demo v0.2 (pre-Olympia Mordor testing)
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_2");

    // Mordor testnet parameters
    uint256 constant TIMELOCK_DELAY = 3600; // 1 hour
    uint48 constant VOTING_DELAY = 1; // 1 block
    uint32 constant VOTING_PERIOD = 100; // ~22 minutes on ETC
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50; // ~11 minutes
    uint256 constant MIN_REVIEW_PERIOD = 86400; // 1 day

    // Treasury (demo v0.2, pure Solidity immutable executor)
    // Set after deploying Treasury with PrecomputeAddresses.s.sol
    address constant TREASURY = 0x035b2e3c189B772e52F4C3DA6c45c84A3bB871bf;

    function run() public {
        address deployer = msg.sender;

        // These must be set as environment variables or script args
        address sanctionsOracle = vm.envAddress("SANCTIONS_ORACLE");
        address memberNFT = vm.envAddress("MEMBER_NFT");

        console.log("=== Olympia Governance Deployment (Demo v0.2) ===");
        console.log("Deployer:", deployer);
        console.log("SanctionsOracle:", sanctionsOracle);
        console.log("MemberNFT:", memberNFT);
        console.log("Treasury:", TREASURY);
        console.log("");

        vm.startBroadcast();

        // Step 1: Deploy TimelockController
        // Governor will be granted roles after deployment
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        TimelockController timelock = new TimelockController{salt: SALT}(TIMELOCK_DELAY, proposers, executors, deployer);
        console.log("TimelockController:", address(timelock));

        // Step 2: Deploy OlympiaGovernor
        OlympiaGovernor governor = new OlympiaGovernor{salt: SALT}(
            "OlympiaGovernor",
            IVotes(memberNFT),
            ISanctionsOracle(sanctionsOracle),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );
        console.log("OlympiaGovernor:", address(governor));

        // Step 3: Grant timelock roles to Governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Step 4: Deploy OlympiaExecutor
        OlympiaExecutor executor = new OlympiaExecutor{salt: SALT}(TREASURY, address(timelock), sanctionsOracle);
        console.log("OlympiaExecutor:", address(executor));

        // Step 5: Deploy ECFPRegistry
        ECFPRegistry registry = new ECFPRegistry{salt: SALT}(deployer, MIN_REVIEW_PERIOD);
        console.log("ECFPRegistry:", address(registry));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("");
        console.log("Next steps:");
        console.log("  1. Verify OlympiaExecutor address matches Treasury's immutable executor");
        console.log("  2. Grant GOVERNOR_ROLE on ECFPRegistry to Timelock (for governance-gated transitions):");
        console.log("     cast send REGISTRY 'grantRole(bytes32,address)' <GOVERNOR_ROLE> <TIMELOCK>");
        console.log("  3. Optionally renounce deployer's PROPOSER/EXECUTOR/CANCELLER roles on Timelock");
        console.log("  4. Optionally renounce deployer's DEFAULT_ADMIN_ROLE on Timelock (makes roles permanent)");
    }
}
