// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IOlympiaDAOMemberRenderer
/// @notice Interface for rendering on-chain metadata and SVG art for OlympiaDAOMemberNFT
interface IOlympiaDAOMemberRenderer {
    /// @notice Generate a fully on-chain tokenURI (data:application/json;base64,...)
    /// @param tokenId          The token ID
    /// @param owner            The current owner address
    /// @param mintBlock        The block number when the token was minted
    /// @param lastActivityBlock The block number of the member's last recorded on-chain activity
    /// @return The complete data URI containing JSON metadata with embedded SVG
    function tokenURI(uint256 tokenId, address owner, uint256 mintBlock, uint256 lastActivityBlock)
        external
        view
        returns (string memory);
}
