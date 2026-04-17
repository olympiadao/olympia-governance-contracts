// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {OlympiaDAOMemberNFT} from "../src/OlympiaDAOMemberNFT.sol";
import {OlympiaDAOMemberRenderer} from "../src/nft/OlympiaDAOMemberRenderer.sol";
import {MembershipVerifier} from "../src/nft/MembershipVerifier.sol";

/// @title DeployFoundation
/// @notice Deploys foundation contracts: SanctionsOracle, OlympiaDAOMemberNFT, Renderer, Verifier
/// @dev Uses CREATE2 for deterministic addresses. Run before DeployGovernance.
contract DeployFoundation is Script {
    // ── Version (update these 4 lines when cutting a new demo) ──────────────
    string  constant NFT_NAME   = "OlympiaDAO Member v0.4";
    string  constant NFT_SYMBOL = "OLYMPIADAOv04";
    string  constant GOV_NAME   = "OlympiaDAO Governor v0.4";
    bytes32 constant SALT       = keccak256("OLYMPIA_DEMO_V0_4");
    // ────────────────────────────────────────────────────────────────────────

    // Dev wallet for initial NFT mint + verifier attestation
    address constant DEV_WALLET = 0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537;

    function run() public {
        address deployer = msg.sender;

        console.log("=== OlympiaDAO Foundation Deployment (Demo v0.4) ===");
        console.log("Deployer:", deployer);
        console.log("Dev wallet:", DEV_WALLET);
        console.log("NFT name:", NFT_NAME);
        console.log("NFT symbol:", NFT_SYMBOL);
        console.log("");

        vm.startBroadcast();

        // Step 1: Deploy SanctionsOracle
        SanctionsOracle oracle = new SanctionsOracle{salt: SALT}(deployer);
        console.log("SanctionsOracle:", address(oracle));

        // Step 2: Deploy OlympiaDAOMemberNFT
        // governor_ = address(0) at foundation deploy; wired up via setGovernor() after governance deploy
        OlympiaDAOMemberNFT nft = new OlympiaDAOMemberNFT{salt: SALT}(
            NFT_NAME,
            NFT_SYMBOL,
            deployer,
            0,            // inactivityThreshold = 0 (disabled until DAO votes to enable)
            address(0)    // governor_ (set post-governance via setGovernor())
        );
        console.log("OlympiaDAOMemberNFT:", address(nft));

        // Step 3: Deploy OlympiaDAOMemberRenderer (on-chain SVG art, stateless)
        OlympiaDAOMemberRenderer renderer = new OlympiaDAOMemberRenderer{salt: SALT}(NFT_NAME);
        console.log("OlympiaDAOMemberRenderer:", address(renderer));

        // Step 4: Deploy MembershipVerifier (sybil resistance)
        MembershipVerifier verifier = new MembershipVerifier{salt: SALT}(deployer);
        console.log("MembershipVerifier:", address(verifier));

        // Step 5: Wire renderer + verifier into NFT
        nft.setRenderer(address(renderer));
        console.log("Renderer set on NFT");
        nft.setVerifier(address(verifier));
        console.log("Verifier set on NFT");

        // Step 6: Attest dev wallet so it can receive NFT
        verifier.attest(DEV_WALLET);
        console.log("Dev wallet attested");

        // Step 7: Mint initial NFT to dev wallet
        nft.safeMint(DEV_WALLET);
        console.log("Minted NFT #0 to dev wallet");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Foundation Deployment Complete ===");
        console.log("");
        console.log("Next steps:");
        console.log("  1. Export addresses for governance deployment:");
        console.log("     export SANCTIONS_ORACLE=", address(oracle));
        console.log("     export MEMBER_NFT=", address(nft));
        console.log("  2. Run DeployGovernance script");
        console.log("  3. Run: cast send NFT 'setGovernor(address)' GOVERNOR");
        console.log("  4. Attest + mint additional NFTs to test voters as needed");
    }
}
