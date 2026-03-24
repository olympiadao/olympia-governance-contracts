// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IMembershipVerifier
/// @notice Interface for modular membership verification (ECIP-1113 sybil resistance)
/// @dev Concrete implementations decide HOW verification works (attestation, merkle proof,
///      oracle-based, etc.). The NFT contract delegates eligibility checks to this interface.
interface IMembershipVerifier {
    /// @notice Returns true if `account` has been verified as eligible for membership
    /// @param account The address to check
    function isVerified(address account) external view returns (bool);
}
