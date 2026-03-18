// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ISanctionsOracle
/// @notice Interface for querying sanctioned addresses (ECIP-1119)
/// @dev Olympia Demo v0.2 — used by OlympiaGovernor for 3-layer sanctions defense
interface ISanctionsOracle {
    /// @notice Emitted when an address is added to the sanctions list
    event AddressAdded(address indexed account);

    /// @notice Emitted when an address is removed from the sanctions list
    event AddressRemoved(address indexed account);

    /// @notice Check if an address is sanctioned
    /// @param account The address to check
    /// @return True if the address is sanctioned
    function isSanctioned(address account) external view returns (bool);
}
