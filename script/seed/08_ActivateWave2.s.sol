// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {ECFPRegistry} from "../../src/ECFPRegistry.sol";

/// @title 08_ActivateWave2
/// @notice Two-phase script for Wave 2:
///         Phase A (deployer): Activates both Wave 2 ECFPs.
///         Phase B (maintainer1): Creates two Governor proposals.
///
/// Run Phase A:
///   forge script script/seed/08_ActivateWave2.s.sol:ActivateWave2 \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv --sig "runActivate()"
///
/// Run Phase B immediately after:
///   forge script script/seed/08_ActivateWave2.s.sol:ActivateWave2 \
///     --rpc-url $MORDOR_RPC_URL --private-key $MAINTAINER_1_PRIVATE_KEY \
///     --broadcast --legacy -vvv --sig "runPropose()"
///
/// After: wait 1 block, then run 09_VoteWave2.s.sol
contract ActivateWave2 is Script, SeedConfig {
    function runActivate() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 08_ActivateWave2 Phase A: Activate ECFPs (deployer) ===");

        bytes32 hashId5 = REGISTRY.computeHashId(ECFP_ID_P5, acme, AMOUNT_P5, META_P5);
        bytes32 hashId6 = REGISTRY.computeHashId(ECFP_ID_P6, acme, AMOUNT_P6, META_P6);

        vm.startBroadcast();
        console.log("Activating ECFP-005 (Consensus Unit Tests)...");
        REGISTRY.activateProposal(hashId5);
        vm.stopBroadcast();

        vm.startBroadcast();
        console.log("Activating ECFP-006 (Live RPC Tests & Hygiene)...");
        REGISTRY.activateProposal(hashId6);
        vm.stopBroadcast();

        ECFPRegistry.Proposal memory p5 = REGISTRY.getProposal(hashId5);
        ECFPRegistry.Proposal memory p6 = REGISTRY.getProposal(hashId6);

        console.log("");
        console.log("ECFP-005 status:", uint8(p5.status), "(1 = Active)");
        console.log("ECFP-006 status:", uint8(p6.status), "(1 = Active)");
        console.log("");
        console.log("Phase A complete. Run Phase B immediately with MAINTAINER_1_PRIVATE_KEY.");
    }

    function runPropose() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 08_ActivateWave2 Phase B: Create Governor proposals (maintainer1) ===");
        console.log("");

        // ── P5 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P5);
            string memory desc = descP5(acme);

            vm.startBroadcast();
            console.log("Proposing P5: ETC Chain Config & Consensus Unit Tests...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("");
        }

        // ── P6 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P6);
            string memory desc = descP6(acme);

            vm.startBroadcast();
            console.log("Proposing P6: Live RPC Tests, Cross-Client Vectors & Repository Hygiene...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("");
        }

        console.log("=== 08_ActivateWave2 Phase B complete ===");
        console.log("2 Governor proposals created. Voting delay: 1 block (~13s).");
        console.log("");
        console.log("Next: wait 1 block, then run 09_VoteWave2.s.sol");
    }
}
