// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {ECFPRegistry} from "../../src/ECFPRegistry.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 03_ActivateWave1
/// @notice Two-phase script:
///         Phase A (deployer): Activates all four Wave 1 ECFPs in the ECFPRegistry.
///                             The deployer holds GOVERNOR_ROLE from the registry constructor.
///         Phase B (maintainer1): Creates four Governor proposals  --  one per ECFP.
///                                Maintainer 1 must hold an NFT (minted in script 01).
///
/// @dev Run after the 300s ECFP review period has elapsed since script 02.
///      Uses separate vm.startBroadcast() calls for each tx to produce distinct timestamps.
///
/// Run Phase A (deployer activates):
///   forge script script/seed/03_ActivateWave1.s.sol:ActivateWave1 \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv --sig "runActivate()"
///
/// Run Phase B (maintainer proposes)  --  immediately after Phase A:
///   forge script script/seed/03_ActivateWave1.s.sol:ActivateWave1 \
///     --rpc-url $MORDOR_RPC_URL --private-key $MAINTAINER_1_PRIVATE_KEY \
///     --broadcast --legacy -vvv --sig "runPropose()"
///
/// After running: wait 1 block (~13s) for voting delay, then run 04_VoteWave1.s.sol
contract ActivateWave1 is Script, SeedConfig {
    /// @notice Phase A: Deployer activates the four Wave 1 ECFPs.
    function runActivate() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 03_ActivateWave1 Phase A: Activate ECFPs (deployer) ===");
        console.log("Deployer has GOVERNOR_ROLE on ECFPRegistry from constructor.");
        console.log("");

        // Compute hashIds (must match what ACME submitted in script 02)
        bytes32 hashId1 = REGISTRY.computeHashId(ECFP_ID_P1, acme, AMOUNT_P1, META_P1);
        bytes32 hashId2 = REGISTRY.computeHashId(ECFP_ID_P2, acme, AMOUNT_P2, META_P2);
        bytes32 hashId3 = REGISTRY.computeHashId(ECFP_ID_P3, acme, AMOUNT_P3, META_P3);
        bytes32 hashId4 = REGISTRY.computeHashId(ECFP_ID_P4, acme, AMOUNT_P4, META_P4);

        vm.startBroadcast();
        console.log("Activating ECFP-001 (Go Runtime)...");
        REGISTRY.activateProposal(hashId1);
        vm.stopBroadcast();

        vm.startBroadcast();
        console.log("Activating ECFP-002 (Crypto CVEs)...");
        REGISTRY.activateProposal(hashId2);
        vm.stopBroadcast();

        vm.startBroadcast();
        console.log("Activating ECFP-003 (Dependency Security)...");
        REGISTRY.activateProposal(hashId3);
        vm.stopBroadcast();

        vm.startBroadcast();
        console.log("Activating ECFP-004 (P2P Security)...");
        REGISTRY.activateProposal(hashId4);
        vm.stopBroadcast();

        // Verify
        ECFPRegistry.Proposal memory p1 = REGISTRY.getProposal(hashId1);
        ECFPRegistry.Proposal memory p2 = REGISTRY.getProposal(hashId2);
        ECFPRegistry.Proposal memory p3 = REGISTRY.getProposal(hashId3);
        ECFPRegistry.Proposal memory p4 = REGISTRY.getProposal(hashId4);

        console.log("");
        console.log("ECFP-001 status:", uint8(p1.status), "(1 = Active)");
        console.log("ECFP-002 status:", uint8(p2.status), "(1 = Active)");
        console.log("ECFP-003 status:", uint8(p3.status), "(1 = Active)");
        console.log("ECFP-004 status:", uint8(p4.status), "(1 = Active)");
        console.log("");
        console.log("Phase A complete. Run Phase B immediately with MAINTAINER_1_PRIVATE_KEY.");
    }

    /// @notice Phase B: Maintainer 1 creates four Governor proposals.
    function runPropose() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        console.log("=== 03_ActivateWave1 Phase B: Create Governor proposals (maintainer1) ===");
        console.log("");

        // ── P1 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P1);
            string memory desc = descP1(acme);

            vm.startBroadcast();
            console.log("Proposing P1: Go 1.26 Runtime Modernization...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("  state: Pending (voting starts in 1 block)");
            console.log("");
        }

        // ── P2 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P2);
            string memory desc = descP2(acme);

            vm.startBroadcast();
            console.log("Proposing P2: Core Cryptography Hardening (4 CVEs)...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("");
        }

        // ── P3 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P3);
            string memory desc = descP3(acme);

            vm.startBroadcast();
            console.log("Proposing P3: Dependency & Protocol Security (5 CVEs)...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("");
        }

        // ── P4 ────────────────────────────────────────────────────────────────
        {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
                _proposalActions(acme, AMOUNT_P4);
            string memory desc = descP4(acme);

            vm.startBroadcast();
            console.log("Proposing P4: P2P Protocol Security (CVE-2026-26313 + RLP)...");
            uint256 proposalId = GOVERNOR.propose(targets, values, calldatas, desc);
            vm.stopBroadcast();
            console.log("  proposalId:", proposalId);
            console.log("");
        }

        console.log("=== 03_ActivateWave1 Phase B complete ===");
        console.log("4 Governor proposals created. Voting delay: 1 block (~13s).");
        console.log("");
        console.log("Next: wait 1 block, then run 04_VoteWave1.s.sol");
        console.log("      Voting window: ~22 minutes (100 blocks)");
    }
}
