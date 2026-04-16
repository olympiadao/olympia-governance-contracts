// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 06_ExecuteWave1
/// @notice Executes all four Wave 1 proposals after the TimelockController delay has elapsed.
///         Execution calls OlympiaExecutor.executeTreasury() which performs the Layer 3
///         sanctions check and then calls OlympiaTreasury.withdraw() to disburse funds to ACME.
///
/// @dev Run at least 3600s (1 hour) after script 05 queued the proposals.
///      Any address can call execute(). Also marks all ECFPs as Executed in the registry.
///
/// Run:
///   forge script script/seed/06_ExecuteWave1.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv
contract ExecuteWave1 is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        uint256 acmeBalanceBefore = address(payable(acme)).balance;

        console.log("=== 06_ExecuteWave1: Execute Wave 1 proposals ===");
        console.log("ACME balance before execution:", acmeBalanceBefore / 1 ether, "mETC");
        console.log("");

        (address[] memory t1, uint256[] memory v1, bytes[] memory c1) = _proposalActions(acme, AMOUNT_P1);
        (address[] memory t2, uint256[] memory v2, bytes[] memory c2) = _proposalActions(acme, AMOUNT_P2);
        (address[] memory t3, uint256[] memory v3, bytes[] memory c3) = _proposalActions(acme, AMOUNT_P3);
        (address[] memory t4, uint256[] memory v4, bytes[] memory c4) = _proposalActions(acme, AMOUNT_P4);

        vm.startBroadcast();

        console.log("Executing P1: Go 1.26 Runtime Modernization (1,200 mETC)...");
        GOVERNOR.execute(t1, v1, c1, keccak256(bytes(descP1(acme))));
        console.log("  P1 executed. Funds disbursed to ACME.");

        console.log("Executing P2: Core Cryptography Hardening (1,600 mETC)...");
        GOVERNOR.execute(t2, v2, c2, keccak256(bytes(descP2(acme))));
        console.log("  P2 executed. Funds disbursed to ACME.");

        console.log("Executing P3: Dependency & Protocol Security (1,400 mETC)...");
        GOVERNOR.execute(t3, v3, c3, keccak256(bytes(descP3(acme))));
        console.log("  P3 executed. Funds disbursed to ACME.");

        console.log("Executing P4: P2P Protocol Security (2,200 mETC)...");
        GOVERNOR.execute(t4, v4, c4, keccak256(bytes(descP4(acme))));
        console.log("  P4 executed. Funds disbursed to ACME.");

        // Mark ECFPs as Executed in registry (deployer has GOVERNOR_ROLE)
        console.log("");
        console.log("Marking ECFPs as Executed in registry...");
        bytes32 hashId1 = REGISTRY.computeHashId(ECFP_ID_P1, acme, AMOUNT_P1, META_P1);
        bytes32 hashId2 = REGISTRY.computeHashId(ECFP_ID_P2, acme, AMOUNT_P2, META_P2);
        bytes32 hashId3 = REGISTRY.computeHashId(ECFP_ID_P3, acme, AMOUNT_P3, META_P3);
        bytes32 hashId4 = REGISTRY.computeHashId(ECFP_ID_P4, acme, AMOUNT_P4, META_P4);

        // First approve (Active -> Approved), then mark executed (Approved -> Executed)
        REGISTRY.approveProposal(hashId1);
        REGISTRY.markExecuted(hashId1);
        REGISTRY.approveProposal(hashId2);
        REGISTRY.markExecuted(hashId2);
        REGISTRY.approveProposal(hashId3);
        REGISTRY.markExecuted(hashId3);
        REGISTRY.approveProposal(hashId4);
        REGISTRY.markExecuted(hashId4);

        vm.stopBroadcast();

        uint256 acmeBalanceAfter = address(payable(acme)).balance;
        uint256 wave1Total = AMOUNT_P1 + AMOUNT_P2 + AMOUNT_P3 + AMOUNT_P4;

        console.log("");
        console.log("=== 06_ExecuteWave1 complete ===");
        console.log("Wave 1 disbursement:");
        console.log("  P1: 1,200 mETC (Go 1.26 Runtime)");
        console.log("  P2: 1,600 mETC (Crypto CVEs)");
        console.log("  P3: 1,400 mETC (Dependency Security)");
        console.log("  P4: 2,200 mETC (P2P Security)");
        console.log("  Total:", wave1Total / 1 ether, "mETC");
        console.log("");
        console.log("ACME balance before:", acmeBalanceBefore / 1 ether, "mETC");
        console.log("ACME balance after: ", acmeBalanceAfter / 1 ether, "mETC");
        console.log("");
        console.log("All 4 ECFPs marked Executed in registry.");
        console.log("");
        console.log("Next: run 10_QueueWave2.s.sol, then 11_ExecuteWave2.s.sol after 1 hour");
    }
}
