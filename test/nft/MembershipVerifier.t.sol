// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MembershipVerifier} from "../../src/nft/MembershipVerifier.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MembershipVerifierTest is Test {
    MembershipVerifier public verifier;
    address public admin = makeAddr("admin");
    address public attestor = makeAddr("attestor");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function setUp() public {
        verifier = new MembershipVerifier(admin);
    }

    // --- Attestation ---

    function test_attest_setsVerified() public {
        vm.prank(admin);
        verifier.attest(alice);
        assertTrue(verifier.isVerified(alice));
    }

    function test_attest_onlyAttestorRole() public {
        bytes32 attestorRole = verifier.ATTESTOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, attestorRole)
        );
        vm.prank(alice);
        verifier.attest(alice);
    }

    function test_attest_grantedAttestorCanAttest() public {
        vm.startPrank(admin);
        verifier.grantRole(verifier.ATTESTOR_ROLE(), attestor);
        vm.stopPrank();

        vm.prank(attestor);
        verifier.attest(alice);
        assertTrue(verifier.isVerified(alice));
    }

    function test_revokeAttestation_clearsVerified() public {
        vm.startPrank(admin);
        verifier.attest(alice);
        assertTrue(verifier.isVerified(alice));
        verifier.revokeAttestation(alice);
        vm.stopPrank();
        assertFalse(verifier.isVerified(alice));
    }

    function test_revokeAttestation_onlyAttestorRole() public {
        bytes32 attestorRole = verifier.ATTESTOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, attestorRole)
        );
        vm.prank(alice);
        verifier.revokeAttestation(bob);
    }

    function test_isVerified_defaultFalse() public view {
        assertFalse(verifier.isVerified(alice));
    }

    // --- Merkle Proof ---

    function test_setMerkleRoot_onlyAdmin() public {
        bytes32 adminRole = verifier.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, adminRole)
        );
        vm.prank(alice);
        verifier.setMerkleRoot(bytes32(uint256(1)));
    }

    function test_verifyWithProof_validProof_setsVerified() public {
        // Build a simple 2-leaf merkle tree: [alice, bob]
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32 leafBob = keccak256(abi.encodePacked(bob));
        bytes32 root = _hashPair(leafAlice, leafBob);

        vm.prank(admin);
        verifier.setMerkleRoot(root);

        // Alice verifies with bob's leaf as proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafBob;
        vm.prank(alice);
        verifier.verifyWithProof(proof);

        assertTrue(verifier.isVerified(alice));
    }

    function test_verifyWithProof_invalidProof_reverts() public {
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32 leafBob = keccak256(abi.encodePacked(bob));
        bytes32 root = _hashPair(leafAlice, leafBob);

        vm.prank(admin);
        verifier.setMerkleRoot(root);

        // Carol is not in the tree — any proof should fail
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafBob;
        vm.expectRevert(MembershipVerifier.InvalidProof.selector);
        vm.prank(carol);
        verifier.verifyWithProof(proof);
    }

    function test_verifyWithProof_alreadyVerified_noOp() public {
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32 leafBob = keccak256(abi.encodePacked(bob));
        bytes32 root = _hashPair(leafAlice, leafBob);

        vm.prank(admin);
        verifier.setMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafBob;

        // Verify twice — should not revert
        vm.prank(alice);
        verifier.verifyWithProof(proof);
        vm.prank(alice);
        verifier.verifyWithProof(proof);

        assertTrue(verifier.isVerified(alice));
    }

    // --- Helper ---

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
