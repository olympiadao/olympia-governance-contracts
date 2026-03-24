// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IOlympiaMemberRenderer
/// @notice Interface for rendering on-chain metadata and SVG art for OlympiaMemberNFT
interface IOlympiaMemberRenderer {
    /// @notice Generate a fully on-chain tokenURI (data:application/json;base64,...)
    /// @param tokenId The token ID
    /// @param owner The current owner address
    /// @param mintBlock The block number when the token was minted
    /// @return The complete data URI containing JSON metadata with embedded SVG
    function tokenURI(uint256 tokenId, address owner, uint256 mintBlock) external view returns (string memory);
}
