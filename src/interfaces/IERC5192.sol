// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC5192 — Minimal Soulbound NFTs
/// @notice Interface for EIP-5192 soulbound (non-transferable) tokens
/// @dev Not included in OZ v5.6.0. Manually implemented per EIP-5192 spec.
interface IERC5192 {
    /// @notice Emitted when a token is locked (made soulbound)
    event Locked(uint256 tokenId);

    /// @notice Emitted when a token is unlocked (transferable)
    event Unlocked(uint256 tokenId);

    /// @notice Check if a token is locked (soulbound)
    /// @param tokenId The token to check
    /// @return True if the token is locked
    function locked(uint256 tokenId) external view returns (bool);
}
