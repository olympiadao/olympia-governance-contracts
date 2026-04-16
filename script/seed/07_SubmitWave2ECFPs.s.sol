// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";

/// @title 07_SubmitWave2ECFPs
/// @notice ACME Open Source Development Corp submits two Wave 2 funding proposals.
///         Run during the Wave 1 timelock wait period to keep governance activity flowing.
///
/// @dev Broadcasts from ACME_PRIVATE_KEY. Permissionless  --  no NFT required.
///
/// Run:
///   forge script script/seed/07_SubmitWave2ECFPs.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $ACME_PRIVATE_KEY \
///     --broadcast --legacy -vvv
///
/// After running: wait 5 minutes (300s review period), then run 08_ActivateWave2.s.sol
contract SubmitWave2ECFPs is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 07_SubmitWave2ECFPs: ACME submits Wave 2 funding proposals ===");
        console.log("ACME address:", acme);
        console.log("(Wave 1 timelock is running in parallel  --  governance is active.)");
        console.log("");

        // ── P5: ETC Chain Config & Consensus Unit Tests ───────────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-005: ETC Chain Config & Consensus Unit Tests...");
        bytes32 hashId5 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P5, acme, AMOUNT_P5, META_P5);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId5));
        console.log("  amount:", AMOUNT_P5 / 1 ether, "mETC");
        console.log("");

        // ── P6: Live RPC Tests, Vectors & Repository Hygiene ─────────────────
        vm.startBroadcast();
        console.log("Submitting ECFP-006: Live RPC Tests, Cross-Client Vectors & Repository Hygiene...");
        bytes32 hashId6 = REGISTRY.submit{value: SUBMISSION_BOND}(ECFP_ID_P6, acme, AMOUNT_P6, META_P6);
        vm.stopBroadcast();
        console.log("  hashId:", vm.toString(hashId6));
        console.log("  amount:", AMOUNT_P6 / 1 ether, "mETC");
        console.log("");

        console.log("=== 07_SubmitWave2ECFPs complete ===");
        console.log("2 ECFPs submitted in Draft status.");
        console.log("minReviewPeriod = 300s (5 minutes)");
        console.log("");
        console.log("Next: wait 5 minutes, then run 08_ActivateWave2.s.sol (DEPLOYER + MAINTAINER_1 keys)");
    }
}
