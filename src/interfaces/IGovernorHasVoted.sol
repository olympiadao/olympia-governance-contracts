// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IGovernorHasVoted
/// @notice Minimal read-only interface for confirming that an account voted on a Governor proposal.
///         Used by OlympiaMemberNFT to witness votes without modifying OlympiaGovernor.
interface IGovernorHasVoted {
    /// @notice Returns true if `account` has cast a vote on `proposalId`
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
}
