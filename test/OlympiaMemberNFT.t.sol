// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {MembershipVerifier} from "../src/nft/MembershipVerifier.sol";
import {IERC5192} from "../src/interfaces/IERC5192.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract OlympiaMemberNFTTest is Test {
    OlympiaMemberNFT public nft;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        nft = new OlympiaMemberNFT(admin);
    }

    // --- Minting ---

    function test_safeMint_assignsToken() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_safeMint_emitsTransferAndLocked() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, false);
        emit IERC721.Transfer(address(0), alice, 0);
        vm.expectEmit(true, false, false, false);
        emit IERC5192.Locked(0);
        nft.safeMint(alice);
    }

    function test_safeMint_autoIncrements() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        nft.safeMint(bob);
        vm.stopPrank();
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
    }

    function test_safeMint_revertsWithoutMinterRole() public {
        bytes32 minterRole = nft.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, minterRole)
        );
        vm.prank(alice);
        nft.safeMint(alice);
    }

    // --- Auto-delegate ---

    function test_safeMint_autoDelegates() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.delegates(alice), alice);
    }

    function test_safeMint_revertsIfAlreadyMember() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        vm.expectRevert(abi.encodeWithSelector(OlympiaMemberNFT.AlreadyMember.selector, alice));
        nft.safeMint(alice);
        vm.stopPrank();
    }

    function test_safeMint_allowsRemintAfterRevoke() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        assertEq(nft.balanceOf(alice), 1);
        nft.revoke(0);
        assertEq(nft.balanceOf(alice), 0);
        nft.safeMint(alice);
        assertEq(nft.balanceOf(alice), 1);
        vm.stopPrank();
    }

    function test_safeMint_differentAddresses_allowed() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        nft.safeMint(bob);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
    }

    // --- Soulbound ---

    function test_transfer_reverts() public {
        vm.prank(admin);
        nft.safeMint(alice);

        vm.prank(alice);
        vm.expectRevert(OlympiaMemberNFT.SoulboundTransferBlocked.selector);
        nft.transferFrom(alice, bob, 0);
    }

    function test_safeTransfer_reverts() public {
        vm.prank(admin);
        nft.safeMint(alice);

        vm.prank(alice);
        vm.expectRevert(OlympiaMemberNFT.SoulboundTransferBlocked.selector);
        nft.safeTransferFrom(alice, bob, 0);
    }

    // --- ERC5192 locked ---

    function test_locked_returnsTrue() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertTrue(nft.locked(0));
    }

    function test_locked_revertsForNonexistentToken() public {
        vm.expectRevert();
        nft.locked(999);
    }

    // --- getPastVotes (snapshot) ---

    function test_getPastVotes_snapshotCorrectness() public {
        // Set explicit block to avoid via_ir block advancement ambiguity
        vm.roll(100);
        vm.prank(admin);
        nft.safeMint(alice);

        // Advance well past mint block — getPastVotes requires strictly past blocks
        vm.roll(200);

        assertEq(nft.getPastVotes(alice, 100), 1);
    }

    // --- Enumeration ---

    function test_totalSupply_increments() public {
        assertEq(nft.totalSupply(), 0);
        vm.startPrank(admin);
        nft.safeMint(alice);
        assertEq(nft.totalSupply(), 1);
        nft.safeMint(bob);
        assertEq(nft.totalSupply(), 2);
        vm.stopPrank();
    }

    function test_tokenByIndex_works() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        nft.safeMint(bob);
        vm.stopPrank();
        assertEq(nft.tokenByIndex(0), 0);
        assertEq(nft.tokenByIndex(1), 1);
    }

    function test_tokenOfOwnerByIndex_works() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        nft.safeMint(bob);
        vm.stopPrank();
        assertEq(nft.tokenOfOwnerByIndex(alice, 0), 0);
        assertEq(nft.tokenOfOwnerByIndex(bob, 0), 1);
    }

    // --- supportsInterface ---

    function test_supportsInterface_ERC721() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
    }

    function test_supportsInterface_ERC721Enumerable() public view {
        assertTrue(nft.supportsInterface(type(IERC721Enumerable).interfaceId));
    }

    function test_supportsInterface_IERC5192() public view {
        assertTrue(nft.supportsInterface(type(IERC5192).interfaceId));
    }

    function test_supportsInterface_AccessControl() public view {
        assertTrue(nft.supportsInterface(type(IAccessControl).interfaceId));
    }

    // --- Revocation ---

    function test_revoke_burnsMembership() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.totalSupply(), 1);

        vm.prank(admin);
        nft.revoke(0);

        vm.expectRevert();
        nft.ownerOf(0);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), 0);
    }

    function test_revoke_decrementsVotingPower() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.getVotes(alice), 1);

        vm.prank(admin);
        nft.revoke(0);
        assertEq(nft.getVotes(alice), 0);
    }

    function test_revoke_revertsWithoutRevokerRole() public {
        vm.prank(admin);
        nft.safeMint(alice);

        bytes32 revokerRole = nft.REVOKER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, revokerRole)
        );
        vm.prank(alice);
        nft.revoke(0);
    }

    function test_revoke_revertsForNonexistentToken() public {
        vm.prank(admin);
        vm.expectRevert();
        nft.revoke(999);
    }

    function test_revoke_adminCanGrantRevokerRole() public {
        address revoker = makeAddr("revoker");
        bytes32 revokerRole = nft.REVOKER_ROLE();
        vm.prank(admin);
        nft.grantRole(revokerRole, revoker);
        assertTrue(nft.hasRole(revokerRole, revoker));

        vm.prank(admin);
        nft.safeMint(alice);

        vm.prank(revoker);
        nft.revoke(0);
        assertEq(nft.balanceOf(alice), 0);
    }

    // --- Renderer & tokenURI ---

    function test_setRenderer_onlyAdmin() public {
        address fakeRenderer = makeAddr("renderer");
        bytes32 adminRole = nft.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, adminRole)
        );
        vm.prank(alice);
        nft.setRenderer(fakeRenderer);
    }

    function test_setRenderer_setsAddress() public {
        address fakeRenderer = makeAddr("renderer");
        vm.prank(admin);
        nft.setRenderer(fakeRenderer);
        assertEq(address(nft.renderer()), fakeRenderer);
    }

    function test_tokenURI_withoutRenderer_returnsEmpty() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.tokenURI(0), "");
    }

    function test_tokenURI_revertsForNonexistentToken() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }

    function test_mintBlock_recordedOnMint() public {
        vm.roll(42);
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.mintBlocks(0), 42);
    }

    function test_mintBlock_multipleTokens() public {
        vm.roll(100);
        vm.prank(admin);
        nft.safeMint(alice);

        vm.roll(200);
        vm.prank(admin);
        nft.safeMint(bob);

        assertEq(nft.mintBlocks(0), 100);
        assertEq(nft.mintBlocks(1), 200);
    }

    // --- Access control ---

    function test_adminCanGrantMinterRole() public {
        bytes32 minterRole = nft.MINTER_ROLE();
        vm.prank(admin);
        nft.grantRole(minterRole, minter);
        assertTrue(nft.hasRole(minterRole, minter));

        vm.prank(minter);
        nft.safeMint(alice);
        assertEq(nft.ownerOf(0), alice);
    }

    // --- Verifier integration ---

    function test_setVerifier_onlyAdmin() public {
        address fakeVerifier = makeAddr("verifier");
        bytes32 adminRole = nft.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, adminRole)
        );
        vm.prank(alice);
        nft.setVerifier(fakeVerifier);
    }

    function test_setVerifier_setsAddress() public {
        address fakeVerifier = makeAddr("verifier");
        vm.prank(admin);
        nft.setVerifier(fakeVerifier);
        assertEq(address(nft.verifier()), fakeVerifier);
    }

    function test_safeMint_succeedsWithoutVerifier() public {
        // No verifier set — should work as before (backward compat)
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.ownerOf(0), alice);
    }

    function test_safeMint_revertsIfNotVerified() public {
        MembershipVerifier verifier = new MembershipVerifier(admin);
        vm.prank(admin);
        nft.setVerifier(address(verifier));

        // Alice is not verified — mint should revert
        vm.expectRevert(abi.encodeWithSelector(OlympiaMemberNFT.NotVerified.selector, alice));
        vm.prank(admin);
        nft.safeMint(alice);
    }

    function test_safeMint_succeedsIfVerified() public {
        MembershipVerifier verifier = new MembershipVerifier(admin);
        vm.startPrank(admin);
        nft.setVerifier(address(verifier));
        verifier.attest(alice);
        vm.stopPrank();

        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.ownerOf(0), alice);
    }
}
