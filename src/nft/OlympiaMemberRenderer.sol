// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IOlympiaMemberRenderer} from "./IOlympiaMemberRenderer.sol";
import {OlympiaSVG} from "./OlympiaSVG.sol";

/// @title OlympiaMemberRenderer
/// @notice Generates fully on-chain metadata and SVG art for Olympia membership NFTs.
///         Deterministic visual traits derived from tokenId hash.
contract OlympiaMemberRenderer is IOlympiaMemberRenderer {
    using Strings for uint256;

    /// @inheritdoc IOlympiaMemberRenderer
    function tokenURI(uint256 tokenId, address owner, uint256 mintBlock) external view returns (string memory) {
        OlympiaSVG.SVGParams memory params = _deriveParams(tokenId, owner, mintBlock);
        string memory svg = OlympiaSVG.generateSVG(params);
        string memory svgBase64 = Base64.encode(bytes(svg));
        string memory json = _buildJSON(tokenId, mintBlock, params.chain, svgBase64);
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // =========================================================================
    // Trait derivation — deterministic from tokenId hash
    // =========================================================================

    function _deriveParams(uint256 tokenId, address owner, uint256 mintBlock)
        internal
        view
        returns (OlympiaSVG.SVGParams memory)
    {
        bytes32 hash = keccak256(abi.encodePacked(tokenId));

        return OlympiaSVG.SVGParams({
            tokenId: tokenId,
            owner: owner,
            mintBlock: mintBlock,
            color0: OlympiaSVG.backgroundPalette(_extractByte(hash, 0) % 5),
            color1: OlympiaSVG.circlePalette(_extractByte(hash, 1) % 8),
            color2: OlympiaSVG.circlePalette(_extractByte(hash, 2) % 8),
            color3: OlympiaSVG.circlePalette(_extractByte(hash, 3) % 8),
            x1: _coordToString(hash, 4),
            y1: _coordToString(hash, 5),
            x2: _coordToString(hash, 6),
            y2: _coordToString(hash, 7),
            x3: _coordToString(hash, 8),
            y3: _coordToString(hash, 9),
            borderStyle: _extractByte(hash, 10) % 6,
            glowColor: _extractByte(hash, 11) % 6,
            textureIdx: _extractByte(hash, 12) % 6,
            chain: _chainName()
        });
    }

    /// @dev Extract a single byte from a bytes32 hash at the given offset
    function _extractByte(bytes32 hash, uint256 offset) private pure returns (uint8) {
        return uint8(hash[offset]);
    }

    /// @dev Map a hash byte to a coordinate in the 16-484 range (padded from 500px canvas)
    function _coordToString(bytes32 hash, uint256 offset) private pure returns (string memory) {
        uint256 val = uint256(uint8(hash[offset]));
        uint256 coord = 16 + (val * 468) / 255;
        return coord.toString();
    }

    /// @dev Detect chain name from block.chainid
    function _chainName() private view returns (string memory) {
        uint256 id = block.chainid;
        if (id == 61) return "Ethereum Classic";
        if (id == 63) return "Mordor Testnet";
        return "Unknown Chain";
    }

    // =========================================================================
    // JSON metadata construction
    // =========================================================================

    function _buildJSON(
        uint256 tokenId,
        uint256 mintBlock,
        string memory chain,
        string memory svgBase64
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '{"name":"Olympia v0.3 Contributor #', tokenId.toString(),
            '","description":"Verified Ethereum Classic Core Contributor. Soulbound governance NFT for Olympia (ECIP-1113). One NFT = one vote."',
            ',"image":"data:image/svg+xml;base64,', svgBase64,
            '","animation_url":"data:image/svg+xml;base64,', svgBase64,
            '","attributes":', _buildAttributes(tokenId, mintBlock, chain),
            '}'
        ));
    }

    function _buildAttributes(uint256 tokenId, uint256 mintBlock, string memory chain)
        private
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(
            '[{"trait_type":"Contributor Number","display_type":"number","value":', tokenId.toString(),
            '},{"trait_type":"Chain","value":"', chain,
            '"},{"trait_type":"Mint Block","display_type":"number","value":', mintBlock.toString(),
            '},{"trait_type":"Status","value":"Active"}]'
        ));
    }
}
