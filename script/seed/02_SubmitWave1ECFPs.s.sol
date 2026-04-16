// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";

/// @title 02_SubmitWave1ECFPs
/// @notice ACME Open Source Development Corp submits four funding proposals (ECFPs) for Wave 1.
///         ECFPRegistry.submit() is PERMISSIONLESS  --  no NFT or governance role required.
///         This demonstrates that any qualified open-source contributor can submit to Olympia DAO.
///
/// @dev Broadcasts from ACME_PRIVATE_KEY. Each proposal is submitted in a separate broadcast
///      to produce distinct block timestamps (authentic-looking submission history).
///
/// Run:
///   forge script script/seed/02_SubmitWave1ECFPs.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $ACME_PRIVATE_KEY \
///     --broadcast --legacy -vvv
///
/// After running: wait 5 minutes (minReviewPeriod = 300s), then run 03_ActivateWave1.s.sol
contract SubmitWave1ECFPs is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 02_SubmitWave1ECFPs: ACME submits Wave 1 funding proposals ===");
        console.log("ACME address (submitter + recipient):", acme);
        console.log("");
        console.log("Note: ECFPRegistry.submit() is permissionless. No NFT or governance role required.");
        console.log("");

        // ── P1: Go 1.26 Runtime Modernization ────────────────────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-001: Go 1.26 Runtime Modernization...");
        bytes32 hashId1 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P1, acme, AMOUNT_P1, META_P1);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId1));
        console.log("  amount:", AMOUNT_P1 / 1 ether, "mETC");
        console.log("");

        // ── P2: Core Cryptography Hardening ──────────────────────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-002: Core Cryptography Hardening (4 CVEs)...");
        bytes32 hashId2 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P2, acme, AMOUNT_P2, META_P2);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId2));
        console.log("  amount:", AMOUNT_P2 / 1 ether, "mETC");
        console.log("");

        // ── P3: Dependency & Protocol Security ───────────────────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-003: Dependency & Protocol Security (5 CVEs)...");
        bytes32 hashId3 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P3, acme, AMOUNT_P3, META_P3);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId3));
        console.log("  amount:", AMOUNT_P3 / 1 ether, "mETC");
        console.log("");

        // ── P4: P2P Protocol Security ─────────────────────────────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-004: P2P Protocol Security (CVE-2026-26313 + RLP)...");
        bytes32 hashId4 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P4, acme, AMOUNT_P4, META_P4);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId4));
        console.log("  amount:", AMOUNT_P4 / 1 ether, "mETC");
        console.log("");

        console.log("=== 02_SubmitWave1ECFPs complete ===");
        console.log("4 ECFPs submitted in Draft status.");
        console.log("minReviewPeriod = 300s (5 minutes)");
        console.log("");
        console.log("Next: wait 5 minutes, then run 03_ActivateWave1.s.sol (DEPLOYER key)");
    }
}
