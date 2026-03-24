// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {OlympiaMemberRenderer} from "../src/nft/OlympiaMemberRenderer.sol";
import {MembershipVerifier} from "../src/nft/MembershipVerifier.sol";

/// @title DeployFoundation
/// @notice Deploys foundation contracts: SanctionsOracle, OlympiaMemberNFT, Renderer, Verifier
/// @dev Uses CREATE2 for deterministic addresses. Run before DeployGovernance.
contract DeployFoundation is Script {
    // CREATE2 salt — Demo v0.3 (on-chain SVG, verifier, one-per-address)
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_3");

    // Dev wallet for initial NFT mint + verifier attestation
    address constant DEV_WALLET = 0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537;

    function run() public {
        address deployer = msg.sender;

        // Precompute Renderer CREATE2 address (no constructor args — same address regardless of deployer)
        address rendererAddr = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            CREATE2_FACTORY,
                            SALT,
                            keccak256(type(OlympiaMemberRenderer).creationCode)
                        )
                    )
                )
            )
        );

        console.log("=== Olympia Foundation Deployment (Demo v0.3) ===");
        console.log("Deployer:", deployer);
        console.log("Dev wallet:", DEV_WALLET);
        console.log("");

        vm.startBroadcast();

        // Step 1: Deploy SanctionsOracle
        // Deployer gets DEFAULT_ADMIN_ROLE + MANAGER_ROLE
        SanctionsOracle oracle = new SanctionsOracle{salt: SALT}(deployer);
        console.log("SanctionsOracle:", address(oracle));

        // Step 2: Deploy OlympiaMemberNFT
        // Deployer gets DEFAULT_ADMIN_ROLE + MINTER_ROLE + REVOKER_ROLE
        OlympiaMemberNFT nft = new OlympiaMemberNFT{salt: SALT}(deployer);
        console.log("OlympiaMemberNFT:", address(nft));

        // Step 3: Deploy OlympiaMemberRenderer (on-chain SVG art, stateless)
        // Skip if already deployed (same bytecode + salt = same address regardless of deployer)
        if (rendererAddr.code.length == 0) {
            new OlympiaMemberRenderer{salt: SALT}();
            console.log("OlympiaMemberRenderer: deployed at", rendererAddr);
        } else {
            console.log("OlympiaMemberRenderer: reusing existing at", rendererAddr);
        }

        // Step 4: Deploy MembershipVerifier (sybil resistance)
        // Deployer gets DEFAULT_ADMIN_ROLE + ATTESTOR_ROLE
        MembershipVerifier verifier = new MembershipVerifier{salt: SALT}(deployer);
        console.log("MembershipVerifier:", address(verifier));

        // Step 5: Wire renderer + verifier into NFT
        nft.setRenderer(rendererAddr);
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
        console.log("  3. Attest + mint additional NFTs to test voters as needed");
    }
}
