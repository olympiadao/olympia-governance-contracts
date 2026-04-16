// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 11_ExecuteWave2
/// @notice Executes the two Wave 2 proposals and marks their ECFPs as Executed in the registry.
///         Final script in the seeding sequence. After this, the DAO has 6 executed proposals
///         and 10,000 mETC disbursed to ACME Open Source Development Corp.
///
/// @dev Run at least 3600s (1 hour) after script 10 queued the proposals.
///
/// Run:
///   forge script script/seed/11_ExecuteWave2.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv
contract ExecuteWave2 is Script, SeedConfig {
    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");

        uint256 acmeBalanceBefore = address(payable(acme)).balance;

        console.log("=== 11_ExecuteWave2: Execute Wave 2 proposals ===");
        console.log("ACME balance before execution:", acmeBalanceBefore / 1 ether, "mETC");
        console.log("");

        (address[] memory t5, uint256[] memory v5, bytes[] memory c5) = _proposalActions(acme, AMOUNT_P5);
        (address[] memory t6, uint256[] memory v6, bytes[] memory c6) = _proposalActions(acme, AMOUNT_P6);

        vm.startBroadcast();

        console.log("Executing P5: ETC Chain Config & Consensus Unit Tests (1,600 mETC)...");
        GOVERNOR.execute(t5, v5, c5, keccak256(bytes(descP5(acme))));
        console.log("  P5 executed. Funds disbursed to ACME.");

        console.log("Executing P6: Live RPC Tests, Cross-Client Vectors & Repository Hygiene (2,000 mETC)...");
        GOVERNOR.execute(t6, v6, c6, keccak256(bytes(descP6(acme))));
        console.log("  P6 executed. Funds disbursed to ACME.");

        // Mark ECFPs as Executed in registry
        console.log("");
        console.log("Marking ECFPs as Executed in registry...");
        bytes32 hashId5 = REGISTRY.computeHashId(ECFP_ID_P5, acme, AMOUNT_P5, META_P5);
        bytes32 hashId6 = REGISTRY.computeHashId(ECFP_ID_P6, acme, AMOUNT_P6, META_P6);

        REGISTRY.approveProposal(hashId5);
        REGISTRY.markExecuted(hashId5);
        REGISTRY.approveProposal(hashId6);
        REGISTRY.markExecuted(hashId6);

        vm.stopBroadcast();

        uint256 acmeBalanceAfter = address(payable(acme)).balance;
        uint256 wave2Total = AMOUNT_P5 + AMOUNT_P6;
        uint256 grandTotal = AMOUNT_P1 + AMOUNT_P2 + AMOUNT_P3 + AMOUNT_P4 + AMOUNT_P5 + AMOUNT_P6;

        console.log("");
        console.log("=== 11_ExecuteWave2 complete ===");
        console.log("Wave 2 disbursement:");
        console.log("  P5: 1,600 mETC (Consensus Unit Tests)");
        console.log("  P6: 2,000 mETC (Live RPC Tests & Hygiene)");
        console.log("  Total:", wave2Total / 1 ether, "mETC");
        console.log("");
        console.log("=== SEEDING COMPLETE ===");
        console.log("");
        console.log("Olympia DAO  --  Mordor Seeding Summary");
        console.log("=====================================");
        console.log("Members minted:    3 (NFT #1, #2, #3)");
        console.log("Proposals executed: 6 (Wave 1: P1-P4, Wave 2: P5-P6)");
        console.log("Total disbursed:   ", grandTotal / 1 ether, "mETC");
        console.log("Recipient:          ACME Open Source Development Corp");
        console.log("ACME balance after:", acmeBalanceAfter / 1 ether, "mETC");
        console.log("");
        console.log("Wave 1  --  Security Infrastructure:");
        console.log("  P1: 1,200 mETC  Go 1.26 Runtime Modernization");
        console.log("  P2: 1,600 mETC  Core Cryptography Hardening (4 CVEs)");
        console.log("  P3: 1,400 mETC  Dependency & Protocol Security (5 CVEs)");
        console.log("  P4: 2,200 mETC  P2P Protocol Security (CVE-2026-26313 + RLP)");
        console.log("");
        console.log("Wave 2  --  ETC Test Infrastructure & Maintenance:");
        console.log("  P5: 1,600 mETC  ETC Chain Config & Consensus Unit Tests");
        console.log("  P6: 2,000 mETC  Live RPC Tests, Cross-Client Vectors & Repository Hygiene");
        console.log("");
        console.log("All ECFPs marked Executed in ECFPRegistry. On-chain audit trail complete.");
    }
}
