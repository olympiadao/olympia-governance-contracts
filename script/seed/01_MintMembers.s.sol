// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";

/// @title 01_MintMembers
/// @notice Attests and mints membership NFTs to the three core maintainer accounts.
///         Run once. Each mint is a separate broadcast to produce distinct block timestamps.
///
/// @dev Deployer must hold ATTESTOR_ROLE on MembershipVerifier and MINTER_ROLE on OlympiaMemberNFT.
///      Deployer (0x3b0952...) already holds NFT #0 from the foundation deployment.
///      This script mints NFTs #1, #2, #3.
///
/// Run:
///   forge script script/seed/01_MintMembers.s.sol \
///     --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast --legacy -vvv
contract MintMembers is Script, SeedConfig {
    function run() public {
        address maintainer1 = vm.envAddress("MAINTAINER_1_ADDRESS");
        address maintainer2 = vm.envAddress("MAINTAINER_2_ADDRESS");
        address maintainer3 = vm.envAddress("MAINTAINER_3_ADDRESS");

        console.log("=== 01_MintMembers: Olympia DAO Seeding ===");
        console.log("Maintainer 1:", maintainer1);
        console.log("Maintainer 2:", maintainer2);
        console.log("Maintainer 3:", maintainer3);
        console.log("");

        // ── Maintainer 1 ──────────────────────────────────────────────────────
        vm.startBroadcast();
        console.log("Attesting and minting NFT for Maintainer 1...");
        VERIFIER.attest(maintainer1);
        MEMBER_NFT.safeMint(maintainer1);
        vm.stopBroadcast();

        console.log("NFT minted: tokenId =", MEMBER_NFT.totalSupply() - 1);
        console.log("");

        // ── Maintainer 2 ──────────────────────────────────────────────────────
        vm.startBroadcast();
        console.log("Attesting and minting NFT for Maintainer 2...");
        VERIFIER.attest(maintainer2);
        MEMBER_NFT.safeMint(maintainer2);
        vm.stopBroadcast();

        console.log("NFT minted: tokenId =", MEMBER_NFT.totalSupply() - 1);
        console.log("");

        // ── Maintainer 3 ──────────────────────────────────────────────────────
        vm.startBroadcast();
        console.log("Attesting and minting NFT for Maintainer 3...");
        VERIFIER.attest(maintainer3);
        MEMBER_NFT.safeMint(maintainer3);
        vm.stopBroadcast();

        console.log("NFT minted: tokenId =", MEMBER_NFT.totalSupply() - 1);
        console.log("");

        console.log("=== 01_MintMembers complete ===");
        console.log("Total NFT supply:", MEMBER_NFT.totalSupply());
        console.log("Voting power M1:", MEMBER_NFT.getVotes(maintainer1));
        console.log("Voting power M2:", MEMBER_NFT.getVotes(maintainer2));
        console.log("Voting power M3:", MEMBER_NFT.getVotes(maintainer3));
        console.log("");
        console.log("Next: wait a few minutes, then run 02_SubmitWave1ECFPs.s.sol (ACME key)");
    }
}
