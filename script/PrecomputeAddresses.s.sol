// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OlympiaGovernor} from "../src/OlympiaGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title PrecomputeAddresses
/// @notice Computes deterministic addresses for the entire Olympia demo v0.2 deployment.
/// @dev Resolves the Treasury ↔ Executor circular dependency:
///      - Treasury uses CREATE (nonce-based) - address independent of constructor args
///      - All governance contracts use CREATE2 (salt-based) via deterministic deployer factory
///
///      Run off-chain only: `forge script script/PrecomputeAddresses.s.sol`
///      Set env vars: DEPLOYER (address), DEPLOYER_NONCE (uint - current nonce on target chain)
///
///      Why CREATE for Treasury? Both Treasury and Executor have immutable constructor args
///      pointing to each other. CREATE2 addresses depend on constructor args (part of initcode),
///      creating an unsolvable circular hash dependency. CREATE addresses depend only on
///      (deployer, nonce), breaking the cycle. Governance contracts use CREATE2 because their
///      constructor args point downward (to Treasury, not to each other).
contract PrecomputeAddresses is Script {
    // CREATE2 salt for demo v0.2
    // Uses CREATE2_FACTORY from forge-std/Base.sol (0x4e59b44847b379578588920cA78FbF26c0B4956C)
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_2");

    // Governance parameters (must match DeployGovernance.s.sol)
    uint256 constant TIMELOCK_DELAY = 3600; // 1 hour
    uint48 constant VOTING_DELAY = 1; // 1 block
    uint32 constant VOTING_PERIOD = 100; // ~22 minutes on ETC
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50; // ~11 minutes
    uint256 constant MIN_REVIEW_PERIOD = 86400; // 1 day

    function run() public view {
        address deployer = vm.envAddress("DEPLOYER");
        uint256 nonce = vm.envUint("DEPLOYER_NONCE");

        console.log("========================================");
        console.log("  Olympia Demo v0.2 - Address Precomputation");
        console.log("========================================");
        console.log("");
        console.log("Deployer:", deployer);
        console.log("Nonce:   ", nonce);
        console.log("Salt:     OLYMPIA_DEMO_V0_2");
        console.log("Factory: ", CREATE2_FACTORY);
        console.log("");

        // ─── Phase 1: Treasury (CREATE) ─────────────────────────────
        // Treasury uses CREATE to break the circular dependency with Executor.
        // CREATE address = f(deployer, nonce) - no dependency on constructor args.
        address treasury = vm.computeCreateAddress(deployer, nonce);

        console.log("--- Phase 1: Treasury (CREATE, nonce %d) ---", nonce);
        console.log("OlympiaTreasury:", treasury);
        console.log("");

        // ─── Phase 2: Foundation (CREATE2) ──────────────────────────
        // SanctionsOracle(deployer) and OlympiaMemberNFT(deployer)
        address sanctions = _computeCreate2(
            abi.encodePacked(type(SanctionsOracle).creationCode, abi.encode(deployer))
        );
        address memberNFT = _computeCreate2(
            abi.encodePacked(type(OlympiaMemberNFT).creationCode, abi.encode(deployer))
        );

        console.log("--- Phase 2: Foundation (CREATE2) ---");
        console.log("SanctionsOracle: ", sanctions);
        console.log("OlympiaMemberNFT:", memberNFT);
        console.log("");

        // ─── Phase 3: Governance (CREATE2) ──────────────────────────
        // TimelockController(delay, proposers[], executors[], admin)
        address[] memory empty = new address[](0);
        address timelock = _computeCreate2(
            abi.encodePacked(
                type(TimelockController).creationCode,
                abi.encode(TIMELOCK_DELAY, empty, empty, deployer)
            )
        );

        // OlympiaGovernor(name, votes, sanctions, timelock, params...)
        address governor = _computeCreate2(
            abi.encodePacked(
                type(OlympiaGovernor).creationCode,
                abi.encode(
                    "OlympiaGovernor",
                    IVotes(memberNFT),
                    ISanctionsOracle(sanctions),
                    TimelockController(payable(timelock)),
                    VOTING_DELAY,
                    VOTING_PERIOD,
                    QUORUM_PERCENT,
                    LATE_QUORUM_EXTENSION
                )
            )
        );

        // OlympiaExecutor(treasury, timelock, sanctionsOracle)
        // Uses Treasury address from Phase 1 (CREATE) - circular dependency resolved
        address executor = _computeCreate2(
            abi.encodePacked(
                type(OlympiaExecutor).creationCode, abi.encode(treasury, timelock, sanctions)
            )
        );

        // ECFPRegistry(admin, minReviewPeriod)
        address registry = _computeCreate2(
            abi.encodePacked(
                type(ECFPRegistry).creationCode, abi.encode(deployer, MIN_REVIEW_PERIOD)
            )
        );

        console.log("--- Phase 3: Governance (CREATE2) ---");
        console.log("TimelockController:", timelock);
        console.log("OlympiaGovernor:   ", governor);
        console.log("OlympiaExecutor:   ", executor);
        console.log("ECFPRegistry:      ", registry);
        console.log("");

        // ─── Deploy Script Constants ────────────────────────────────
        console.log("========================================");
        console.log("  Constants for Deploy Scripts");
        console.log("========================================");
        console.log("");
        console.log("Treasury repo - script/Deploy.s.sol:");
        console.log("  address constant EXECUTOR =", executor);
        console.log("  Deploy with CREATE (no salt). Nonce MUST be %d.", nonce);
        console.log("");
        console.log("Governance repo - script/DeployFoundation.s.sol:");
        console.log("  (no changes - uses deployer address from env)");
        console.log("");
        console.log("Governance repo - script/DeployGovernance.s.sol:");
        console.log("  address constant TREASURY =", treasury);
        console.log("");

        // ─── Deployment Order ───────────────────────────────────────
        console.log("========================================");
        console.log("  Deployment Order");
        console.log("========================================");
        console.log("");
        console.log("1. Deploy Treasury (CREATE, nonce %d):", nonce);
        console.log("   forge script Deploy.s.sol --broadcast --legacy");
        console.log("2. Deploy Foundation (CREATE2):");
        console.log("   forge script DeployFoundation.s.sol --broadcast --legacy");
        console.log("3. Deploy Governance (CREATE2):");
        console.log("   forge script DeployGovernance.s.sol --broadcast --legacy");
        console.log("4. Verify: treasury.executor() == %s", executor);
        console.log("5. Verify: executor.treasury() == %s", treasury);
    }

    /// @dev Compute CREATE2 address using the deterministic deployer factory
    function _computeCreate2(bytes memory initcode) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, SALT, keccak256(initcode))
                    )
                )
            )
        );
    }
}
