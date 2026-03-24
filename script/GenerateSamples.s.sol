// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {OlympiaMemberRenderer} from "../src/nft/OlympiaMemberRenderer.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title GenerateSamples
/// @notice Generates sample NFT SVGs for visual review.
///         Run: forge script script/GenerateSamples.s.sol -vv
///         Then open samples/*.svg in a browser.
contract GenerateSamples is Script {
    function run() external {
        // Deploy contracts locally
        address admin = address(0xAd1);
        vm.startPrank(admin);
        OlympiaMemberNFT nft = new OlympiaMemberNFT(admin);
        OlympiaMemberRenderer renderer = new OlympiaMemberRenderer();
        nft.setRenderer(address(renderer));

        // Mint 10 sample tokens to different addresses
        address[10] memory recipients;
        for (uint256 i = 0; i < 10; i++) {
            recipients[i] = address(uint160(0x1000 + i * 0x1111));
            vm.roll(1000 + i * 500);
            nft.safeMint(recipients[i]);
        }
        vm.stopPrank();

        // Generate and write SVGs
        string memory samplesDir = "samples";
        vm.createDir(samplesDir, true);

        for (uint256 i = 0; i < 10; i++) {
            string memory uri = nft.tokenURI(i);
            // Extract JSON from data URI, then extract SVG base64 from JSON
            string memory json = _extractJson(uri);
            string memory svgBase64 = _extractSvgBase64(json);
            bytes memory svg = _base64Decode(bytes(svgBase64));

            string memory filename = string(abi.encodePacked(samplesDir, "/member-", vm.toString(i), ".svg"));
            vm.writeFile(filename, string(svg));
            console.log("Generated:", filename);
        }

        // Also write an HTML gallery
        string memory html = _buildGallery();
        vm.writeFile(string(abi.encodePacked(samplesDir, "/gallery.html")), html);
        console.log("Generated: samples/gallery.html");
    }

    function _extractJson(string memory dataUri) internal pure returns (string memory) {
        bytes memory b = bytes(dataUri);
        // Skip "data:application/json;base64,"
        uint256 prefixLen = 29;
        bytes memory encoded = new bytes(b.length - prefixLen);
        for (uint256 i = 0; i < encoded.length; i++) {
            encoded[i] = b[prefixLen + i];
        }
        return string(_base64Decode(encoded));
    }

    function _extractSvgBase64(string memory json) internal pure returns (string memory) {
        bytes memory j = bytes(json);
        // Find "image":"data:image/svg+xml;base64, and extract until next "
        bytes memory marker = bytes('"image":"data:image/svg+xml;base64,');
        uint256 start = 0;
        for (uint256 i = 0; i <= j.length - marker.length; i++) {
            bool found = true;
            for (uint256 k = 0; k < marker.length; k++) {
                if (j[i + k] != marker[k]) { found = false; break; }
            }
            if (found) { start = i + marker.length; break; }
        }
        require(start > 0, "SVG not found in JSON");

        // Find closing quote
        uint256 end = start;
        while (end < j.length && j[end] != '"') { end++; }

        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = j[start + i];
        }
        return string(result);
    }

    function _buildGallery() internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<!DOCTYPE html><html><head><title>Olympia Member NFT Samples</title>'
            '<style>body{background:#0a0f10;color:#fff;font-family:monospace;padding:20px}'
            '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}'
            'img{width:100%;border-radius:12px;border:1px solid rgba(0,255,174,0.2)}'
            'h1{color:#00ffae}h2{color:#c3c5cb;font-size:14px}</style></head>'
            '<body><h1>Olympia Member NFT v0.3 - Sample Gallery</h1><div class="grid">',
            _galleryItems(),
            '</div></body></html>'
        ));
    }

    function _galleryItems() internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<div><h2>Member #0</h2><img src="member-0.svg"/></div>'
            '<div><h2>Member #1</h2><img src="member-1.svg"/></div>'
            '<div><h2>Member #2</h2><img src="member-2.svg"/></div>'
            '<div><h2>Member #3</h2><img src="member-3.svg"/></div>'
            '<div><h2>Member #4</h2><img src="member-4.svg"/></div>'
            '<div><h2>Member #5</h2><img src="member-5.svg"/></div>'
            '<div><h2>Member #6</h2><img src="member-6.svg"/></div>'
            '<div><h2>Member #7</h2><img src="member-7.svg"/></div>'
            '<div><h2>Member #8</h2><img src="member-8.svg"/></div>'
            '<div><h2>Member #9</h2><img src="member-9.svg"/></div>'
        ));
    }

    // --- Base64 decode (OZ 5.1 only has encode) ---

    function _base64Decode(bytes memory data) internal pure returns (bytes memory) {
        if (data.length == 0) return "";
        uint256 decodedLen = (data.length * 3) / 4;
        if (data[data.length - 1] == '=') decodedLen--;
        if (data.length > 1 && data[data.length - 2] == '=') decodedLen--;
        bytes memory result = new bytes(decodedLen);
        uint256 j = 0;
        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 a = _b64val(data[i]);
            uint256 b_ = _b64val(data[i + 1]);
            uint256 c = i + 2 < data.length ? _b64val(data[i + 2]) : 0;
            uint256 d = i + 3 < data.length ? _b64val(data[i + 3]) : 0;
            uint256 triple = (a << 18) | (b_ << 12) | (c << 6) | d;
            if (j < decodedLen) result[j++] = bytes1(uint8((triple >> 16) & 0xFF));
            if (j < decodedLen) result[j++] = bytes1(uint8((triple >> 8) & 0xFF));
            if (j < decodedLen) result[j++] = bytes1(uint8(triple & 0xFF));
        }
        return result;
    }

    function _b64val(bytes1 c) internal pure returns (uint256) {
        if (c >= 'A' && c <= 'Z') return uint8(c) - 65;
        if (c >= 'a' && c <= 'z') return uint8(c) - 71;
        if (c >= '0' && c <= '9') return uint8(c) + 4;
        if (c == '+') return 62;
        if (c == '/') return 63;
        return 0;
    }
}
