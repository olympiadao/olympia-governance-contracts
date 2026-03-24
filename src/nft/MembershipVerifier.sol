// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMembershipVerifier} from "../interfaces/IMembershipVerifier.sol";

/// @title MembershipVerifier
/// @notice Concrete membership verifier for Olympia demo v0.3 (ECIP-1113 sybil resistance)
/// @dev Two verification modes:
///      Mode A — Admin attestation: ATTESTOR_ROLE marks addresses as verified (off-chain KYC flow)
///      Mode B — Merkle proof allowlist: anyone can self-verify with a valid proof against a published root
///      Both modes write to the same `verified` mapping. Either mode can independently verify an address.
contract MembershipVerifier is IMembershipVerifier, AccessControl {
    /// @notice Role that can attest and revoke attestations
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");

    /// @notice Verified status for each address
    mapping(address => bool) public verified;

    /// @notice Merkle root for allowlist-based verification
    bytes32 public merkleRoot;

    /// @notice Emitted when an address is attested by an attestor
    event Attested(address indexed account);

    /// @notice Emitted when an attestation is revoked
    event AttestationRevoked(address indexed account);

    /// @notice Emitted when an address self-verifies via merkle proof
    event VerifiedByProof(address indexed account);

    /// @notice Emitted when the merkle root is updated
    event MerkleRootUpdated(bytes32 newRoot);

    /// @notice Invalid merkle proof
    error InvalidProof();

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and ATTESTOR_ROLE
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ATTESTOR_ROLE, admin);
    }

    // --- Mode A: Admin Attestation ---

    /// @notice Mark an address as verified (off-chain KYC attestation flow)
    /// @param account The address to attest
    function attest(address account) external onlyRole(ATTESTOR_ROLE) {
        verified[account] = true;
        emit Attested(account);
    }

    /// @notice Remove verification from an address
    /// @param account The address to revoke attestation for
    function revokeAttestation(address account) external onlyRole(ATTESTOR_ROLE) {
        verified[account] = false;
        emit AttestationRevoked(account);
    }

    // --- Mode B: Merkle Proof Allowlist ---

    /// @notice Set or update the merkle root for allowlist verification
    /// @param root The new merkle root (or bytes32(0) to disable merkle verification)
    function setMerkleRoot(bytes32 root) external onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = root;
        emit MerkleRootUpdated(root);
    }

    /// @notice Self-verify using a merkle proof against the published allowlist
    /// @param proof The merkle proof for msg.sender
    function verifyWithProof(bytes32[] calldata proof) external {
        if (!MerkleProof.verifyCalldata(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))) {
            revert InvalidProof();
        }
        verified[msg.sender] = true;
        emit VerifiedByProof(msg.sender);
    }

    // --- IMembershipVerifier ---

    /// @inheritdoc IMembershipVerifier
    function isVerified(address account) external view override returns (bool) {
        return verified[account];
    }
}
