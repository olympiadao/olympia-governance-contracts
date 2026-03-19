// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";

/// @title DeployFoundation
/// @notice Deploys Phase 2A foundation contracts: SanctionsOracle + OlympiaMemberNFT
/// @dev Uses CREATE2 for deterministic addresses. Run before DeployGovernance.
contract DeployFoundation is Script {
    // CREATE2 salt — Demo v0.2 (pre-Olympia Mordor testing)
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_2");

    // Dev wallet for initial NFT mint
    address constant DEV_WALLET = 0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537;

    function run() public {
        address deployer = msg.sender;

        console.log("=== Olympia Foundation Deployment (Demo v0.2) ===");
        console.log("Deployer:", deployer);
        console.log("Dev wallet:", DEV_WALLET);
        console.log("");

        vm.startBroadcast();

        // Step 1: Deploy SanctionsOracle
        // Deployer gets DEFAULT_ADMIN_ROLE + MANAGER_ROLE
        SanctionsOracle oracle = new SanctionsOracle{salt: SALT}(deployer);
        console.log("SanctionsOracle:", address(oracle));

        // Step 2: Deploy OlympiaMemberNFT
        // Deployer gets DEFAULT_ADMIN_ROLE + MINTER_ROLE
        OlympiaMemberNFT nft = new OlympiaMemberNFT{salt: SALT}(deployer);
        console.log("OlympiaMemberNFT:", address(nft));

        // Step 3: Mint initial NFT to dev wallet
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
        console.log("  3. Mint additional NFTs to test voters as needed");
    }
}
