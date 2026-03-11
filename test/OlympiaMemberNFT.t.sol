// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
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

    function test_safeMint_multipleMintsAccumulateVotes() public {
        vm.startPrank(admin);
        nft.safeMint(alice);
        nft.safeMint(alice);
        vm.stopPrank();
        assertEq(nft.getVotes(alice), 2);
        assertEq(nft.balanceOf(alice), 2);
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
        vm.prank(admin);
        nft.safeMint(alice);

        uint256 mintBlock = block.number;
        vm.roll(mintBlock + 1);

        assertEq(nft.getPastVotes(alice, mintBlock), 1);
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
        nft.safeMint(alice);
        vm.stopPrank();
        assertEq(nft.tokenOfOwnerByIndex(alice, 0), 0);
        assertEq(nft.tokenOfOwnerByIndex(alice, 1), 1);
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
}
