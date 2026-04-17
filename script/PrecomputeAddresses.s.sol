// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OlympiaDAOGovernor} from "../src/OlympiaDAOGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {OlympiaDAOMemberNFT} from "../src/OlympiaDAOMemberNFT.sol";
import {OlympiaDAOMemberRenderer} from "../src/nft/OlympiaDAOMemberRenderer.sol";
import {MembershipVerifier} from "../src/nft/MembershipVerifier.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title PrecomputeAddresses
/// @notice Computes deterministic addresses for the entire OlympiaDAO demo v0.4 deployment.
/// @dev Resolves the Treasury ↔ Executor circular dependency:
///      - Treasury uses CREATE (nonce-based) — address independent of constructor args
///      - All governance contracts use CREATE2 (salt-based) via deterministic deployer factory
///
///      Run off-chain only: `forge script script/PrecomputeAddresses.s.sol`
///      Set env vars: DEPLOYER (address)
///
///      Why CREATE for Treasury? Both Treasury and Executor have immutable constructor args
///      pointing to each other. CREATE2 addresses depend on constructor args (part of initcode),
///      creating an unsolvable circular hash dependency. CREATE addresses depend only on
///      (deployer, nonce), breaking the cycle. Governance contracts use CREATE2 because their
///      constructor args point downward (to Treasury, not to each other).
contract PrecomputeAddresses is Script {
    // ── Version (must match DeployFoundation.s.sol and DeployGovernance.s.sol) ──
    string  constant NFT_NAME   = "OlympiaDAO Member v0.4";
    string  constant GOV_NAME   = "OlympiaDAO Governor v0.4";
    bytes32 constant SALT       = keccak256("OLYMPIA_DEMO_V0_4");
    // ─────────────────────────────────────────────────────────────────────────────

    // Governance parameters (must match DeployGovernance.s.sol exactly)
    uint256 constant TIMELOCK_DELAY = 3600;
    uint48 constant VOTING_DELAY = 1;
    uint32 constant VOTING_PERIOD = 100;
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50;
    uint256 constant MIN_REVIEW_PERIOD = 300;

    // ECFPRegistry spam protection parameters (must match DeployGovernance.s.sol)
    uint256 constant MAX_DRAFTS_PER_ADDRESS = 3;
    uint256 constant SUBMISSION_BOND = 1 ether;

    function run() public view {
        address deployer = vm.envAddress("DEPLOYER");

        // NONCE MUST BE 0. Treasury deploys via CREATE: address = keccak256(rlp(deployer, nonce)).
        // The deployer wallet must be a FRESH address (never sent a tx on this chain)
        // before running Deploy.s.sol in the treasury repo.
        uint256 nonce = 0;

        console.log("========================================");
        console.log("  OlympiaDAO Demo v0.4 - Address Precomputation");
        console.log("========================================");
        console.log("");
        console.log("Deployer:", deployer);
        console.log("Nonce:    0 (FIXED -- deployer must be a fresh address)");
        console.log("Salt:     OLYMPIA_DEMO_V0_4");
        console.log("Factory: ", CREATE2_FACTORY);
        console.log("");

        // ─── Phase 1: Treasury (CREATE) ─────────────────────────────
        address treasury = vm.computeCreateAddress(deployer, nonce);

        console.log("--- Phase 1: Treasury (CREATE, nonce %d) ---", nonce);
        console.log("OlympiaTreasury:", treasury);
        console.log("");

        // ─── Phase 2: Foundation (CREATE2) ──────────────────────────
        address sanctions = _computeCreate2(
            abi.encodePacked(type(SanctionsOracle).creationCode, abi.encode(deployer))
        );

        // OlympiaDAOMemberNFT(name_, symbol_, admin, inactivityThreshold_, governor_)
        address memberNFT = _computeCreate2(
            abi.encodePacked(
                type(OlympiaDAOMemberNFT).creationCode,
                abi.encode(NFT_NAME, "OLYMPIADAOv04", deployer, uint256(0), address(0))
            )
        );

        // OlympiaDAOMemberRenderer(nftDisplayName_)
        address renderer = _computeCreate2(
            abi.encodePacked(type(OlympiaDAOMemberRenderer).creationCode, abi.encode(NFT_NAME))
        );

        // MembershipVerifier(deployer)
        address verifier = _computeCreate2(
            abi.encodePacked(type(MembershipVerifier).creationCode, abi.encode(deployer))
        );

        console.log("--- Phase 2: Foundation (CREATE2) ---");
        console.log("SanctionsOracle:          ", sanctions);
        console.log("OlympiaDAOMemberNFT:      ", memberNFT);
        console.log("OlympiaDAOMemberRenderer: ", renderer);
        console.log("MembershipVerifier:       ", verifier);
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

        // OlympiaDAOGovernor(name_, token_, timelock_, votingDelay_, votingPeriod_, quorumPercent_, lateQuorumExtension_)
        // Note: no sanctionsOracle_ — sanctions moved to ECFPRegistry and OlympiaExecutor
        address governor = _computeCreate2(
            abi.encodePacked(
                type(OlympiaDAOGovernor).creationCode,
                abi.encode(
                    GOV_NAME,
                    IVotes(memberNFT),
                    TimelockController(payable(timelock)),
                    VOTING_DELAY,
                    VOTING_PERIOD,
                    QUORUM_PERCENT,
                    LATE_QUORUM_EXTENSION
                )
            )
        );

        // OlympiaExecutor(treasury, timelock, sanctionsOracle)
        address executor = _computeCreate2(
            abi.encodePacked(
                type(OlympiaExecutor).creationCode, abi.encode(treasury, timelock, sanctions)
            )
        );

        // ECFPRegistry(admin, minReviewPeriod, maxDraftsPerAddress, initialBond, treasury, sanctionsOracle_)
        address registry = _computeCreate2(
            abi.encodePacked(
                type(ECFPRegistry).creationCode,
                abi.encode(deployer, MIN_REVIEW_PERIOD, MAX_DRAFTS_PER_ADDRESS, SUBMISSION_BOND, treasury, sanctions)
            )
        );

        console.log("--- Phase 3: Governance (CREATE2) ---");
        console.log("TimelockController:    ", timelock);
        console.log("OlympiaDAOGovernor:    ", governor);
        console.log("OlympiaExecutor:       ", executor);
        console.log("ECFPRegistry:          ", registry);
        console.log("");

        // ─── Deploy Script Constants ────────────────────────────────
        console.log("========================================");
        console.log("  Constants for Deploy Scripts (demo v0.4)");
        console.log("========================================");
        console.log("");
        console.log("Treasury repo - script/Deploy.s.sol:");
        console.log("  address constant EXECUTOR =", executor);
        console.log("  Deploy with CREATE (no salt). Nonce MUST be %d.", nonce);
        console.log("");
        console.log("Governance repo - script/DeployGovernance.s.sol:");
        console.log("  address constant TREASURY =", treasury);
        console.log("");

        // ─── Deployment Order ───────────────────────────────────────
        console.log("========================================");
        console.log("  Deployment Order");
        console.log("========================================");
        console.log("");
        console.log("PREREQUISITE: deployer wallet must be a FRESH address (nonce=0 on target chain).");
        console.log("");
        console.log("1. Fill in EXECUTOR=%s in treasury/script/Deploy.s.sol", executor);
        console.log("2. Deploy Treasury (CREATE, nonce=0)");
        console.log("3. Deploy Foundation (CREATE2): forge script DeployFoundation.s.sol --broadcast --legacy");
        console.log("4. Deploy Governance (CREATE2): forge script DeployGovernance.s.sol --broadcast --legacy");
        console.log("   (DeployGovernance will automatically call memberNFT.setGovernor(governor))");
        console.log("5. Verify: treasury.executor() == %s", executor);
        console.log("6. Verify: executor.treasury() == %s", treasury);
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
