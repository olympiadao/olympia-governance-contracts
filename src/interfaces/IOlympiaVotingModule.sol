// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IOlympiaVotingModule
/// @notice Modular voting power interface for OlympiaGovernor (ECIP-1113)
/// @dev Olympia Demo v0.1 uses standard OZ GovernorVotes with soulbound
///      OlympiaMemberNFT. This interface defines the swappable voting module
///      pattern for governance-gated upgrades via OIP in future releases.
interface IOlympiaVotingModule {
    /// @notice Get the voting power of an account at a specific timepoint
    /// @param account The address to query
    /// @param timepoint The block number to query (ERC-6372)
    /// @return The voting power of the account
    function votingPower(address account, uint256 timepoint) external view returns (uint256);

    /// @notice Check if an account is eligible to vote at a specific timepoint
    /// @param account The address to check
    /// @param timepoint The block number to check (ERC-6372)
    /// @return True if the account is eligible to participate in governance
    function isEligible(address account, uint256 timepoint) external view returns (bool);
}
