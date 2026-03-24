// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title OlympiaSVG
/// @notice Generates on-chain SVG artwork for Olympia governance membership NFTs.
///         Dark-first aesthetic with brand green (#00ffae) holographic gradients,
///         CRT scanlines, ETC diamond mark, and contributor data badges.
library OlympiaSVG {
    using Strings for uint256;
    using Strings for address;

    string private constant FONT = "'JetBrains Mono', 'Courier New', monospace";

    struct SVGParams {
        uint256 tokenId;
        address owner;
        uint256 mintBlock;
        string color0;      // Background base (6 hex chars)
        string color1;      // Gradient circle 1
        string color2;      // Gradient circle 2
        string color3;      // Gradient circle 3
        string x1;
        string y1;
        string x2;
        string y2;
        string x3;
        string y3;
        uint8 borderStyle;  // 0-5
        uint8 glowColor;    // 0-5
        uint8 textureIdx;   // 0-5
        string chain;       // "Ethereum Classic" or "Mordor Testnet"
    }

    // =========================================================================
    // Main entry
    // =========================================================================

    function generateSVG(SVGParams memory params) internal pure returns (string memory) {
        return string(abi.encodePacked(
            _generateDefs(params),
            _generateBackground(params),
            _etcLogo(),
            _generateBorderText(params.tokenId),
            _generateCardMantle(params.tokenId),
            _generateDataBadges(params),
            _generateCornerInfo(params),
            '</svg>'
        ));
    }

    // =========================================================================
    // SVG Defs: filter chain, clip paths, vignette
    // =========================================================================

    function _generateDefs(SVGParams memory params) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<svg width="500" height="500" viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg"'
            " xmlns:xlink='http://www.w3.org/1999/xlink'>",
            '<defs>'
            '<filter id="f1"><feImage result="p0" xlink:href="data:image/svg+xml;base64,',
            Base64.encode(bytes(string(abi.encodePacked(
                "<svg width='500' height='500' viewBox='0 0 500 500' xmlns='http://www.w3.org/2000/svg'>"
                "<rect width='500' height='500' fill='#", params.color0, "'/></svg>"
            )))),
            '"/><feImage result="p1" xlink:href="data:image/svg+xml;base64,',
            _circleImage(params.x1, params.y1, "120", params.color1),
            '"/><feImage result="p2" xlink:href="data:image/svg+xml;base64,',
            _circleImage(params.x2, params.y2, "120", params.color2),
            '"/><feImage result="p3" xlink:href="data:image/svg+xml;base64,',
            _circleImage(params.x3, params.y3, "100", params.color3),
            _defsEnd()
        ));
    }

    function _circleImage(
        string memory cx, string memory cy,
        string memory r, string memory color
    ) private pure returns (string memory) {
        return Base64.encode(bytes(string(abi.encodePacked(
            "<svg width='500' height='500' viewBox='0 0 500 500' xmlns='http://www.w3.org/2000/svg'>"
            "<circle cx='", cx, "' cy='", cy, "' r='", r, "px' fill='#", color, "' opacity='0.6'/></svg>"
        ))));
    }

    function _defsEnd() private pure returns (string memory) {
        return string(abi.encodePacked(
            '"/>'
            '<feBlend mode="overlay" in="p0" in2="p1"/>'
            '<feBlend mode="soft-light" in2="p2"/>'
            '<feBlend mode="overlay" in2="p3" result="blendOut"/>'
            '<feGaussianBlur in="blendOut" stdDeviation="28"/>'
            '</filter>'
            '<clipPath id="corners"><rect width="500" height="500" rx="42" ry="42"/></clipPath>'
            '<path id="text-path-a" d="M40 12 H460 A28 28 0 0 1 488 40 V460 A28 28 0 0 1 460 488 H40 A28 28 0 0 1 12 460 V40 A28 28 0 0 1 40 12 z"/>'
            '<filter id="top-region-blur"><feGaussianBlur in="SourceGraphic" stdDeviation="24"/></filter>'
            '<radialGradient id="vignette" cx="50%" cy="50%" r="60%">'
            '<stop offset="50%" stop-color="transparent"/>'
            '<stop offset="100%" stop-color="rgba(0,0,0,0.35)"/>'
            '</radialGradient>'
            '</defs>'
        ));
    }

    // =========================================================================
    // Background: base + holographic filter + vignette + texture + border
    // =========================================================================

    function _generateBackground(SVGParams memory params) private pure returns (string memory) {
        (string memory borderStroke, string memory accentStroke) = _borderPalette(params.borderStyle);
        return string(abi.encodePacked(
            _outerGlow(params.glowColor),
            '<g clip-path="url(#corners)">'
            '<rect fill="#', params.color0, '" x="0" y="0" width="500" height="500"/>'
            '<rect style="filter: url(#f1)" x="0" y="0" width="500" height="500"/>'
            '<g style="filter:url(#top-region-blur); transform:scale(1.5); transform-origin:center top;">'
            '<rect fill="none" x="0" y="0" width="500" height="500"/>'
            '<ellipse cx="50%" cy="0px" rx="280px" ry="120px" fill="#000" opacity="0.85"/>'
            '</g>',
            _textureSvg(params.textureIdx),
            _bgEnd(borderStroke, accentStroke)
        ));
    }

    function _bgEnd(string memory borderStroke, string memory accentStroke) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect width="500" height="500" fill="url(#vignette)" rx="42" ry="42"/>'
            '<rect x="0" y="0" width="500" height="500" rx="42" ry="42" fill="rgba(0,0,0,0)" stroke="', borderStroke, '"/>'
            '</g>'
            '<rect x="16" y="16" width="468" height="468" rx="26" ry="26" fill="rgba(0,0,0,0)" stroke="', accentStroke, '"/>'
        ));
    }

    function _outerGlow(uint8 idx) private pure returns (string memory) {
        string memory color = _glowColorHex(idx);
        if (bytes(color).length == 0) return "";
        return string(abi.encodePacked(
            '<rect x="-4" y="-4" width="508" height="508" rx="46" ry="46" fill="none" stroke="',
            color, '" stroke-width="2" opacity=".15">'
            '<animate attributeName="opacity" values=".1;.25;.1" dur="3s" repeatCount="indefinite"/>'
            '</rect>'
        ));
    }

    function _glowColorHex(uint8 idx) private pure returns (string memory) {
        if (idx == 0) return "#00ffae"; // Brand green
        if (idx == 1) return "#14f1b4"; // Green hover
        if (idx == 2) return "#00cc8a"; // Green active
        if (idx == 3) return "#007a53"; // Green muted
        if (idx == 4) return "#2CCFB2"; // Teal
        return "";                       // 5 = none
    }

    function _borderPalette(uint8 idx) private pure returns (string memory stroke, string memory accent) {
        if (idx == 0) return ("rgba(0,255,174,0.20)", "rgba(0,255,174,0.12)");
        if (idx == 1) return ("rgba(0,255,174,0.30)", "rgba(0,255,174,0.18)");
        if (idx == 2) return ("rgba(20,241,180,0.30)", "rgba(20,241,180,0.18)");
        if (idx == 3) return ("rgba(0,204,138,0.25)", "rgba(0,204,138,0.15)");
        if (idx == 4) return ("rgba(0,122,83,0.25)", "rgba(0,122,83,0.15)");
        return ("rgba(44,207,178,0.25)", "rgba(44,207,178,0.15)");
    }

    // =========================================================================
    // Textures: CRT scanlines + brand-tinted patterns
    // =========================================================================

    function _textureSvg(uint8 idx) private pure returns (string memory) {
        if (idx == 0) return
            '<defs><pattern id="tex" width="4" height="2" patternUnits="userSpaceOnUse">'
            '<line x1="0" y1="0" x2="4" y2="0" stroke="#000" stroke-width="1" opacity=".06"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
        if (idx == 1) return
            '<defs><pattern id="tex" width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
            '<line x1="0" y1="0" x2="12" y2="0" stroke="#00ffae" stroke-width=".5" opacity=".03"/>'
            '<line x1="0" y1="0" x2="0" y2="12" stroke="#00ffae" stroke-width=".5" opacity=".03"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
        if (idx == 2) return
            '<defs><pattern id="tex" width="16" height="16" patternUnits="userSpaceOnUse">'
            '<circle cx="8" cy="8" r="1.5" fill="#00ffae" opacity=".025"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
        if (idx == 3) return
            '<defs><pattern id="tex" width="20" height="8" patternUnits="userSpaceOnUse">'
            '<line x1="0" y1="4" x2="20" y2="4" stroke="#00ffae" stroke-width=".5" opacity=".05"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
        if (idx == 4) return
            '<defs><pattern id="tex" width="16" height="16" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
            '<rect width="8" height="8" fill="#00ffae" opacity=".015"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
        return
            '<defs><pattern id="tex" width="24" height="24" patternUnits="userSpaceOnUse">'
            '<line x1="0" y1="12" x2="12" y2="12" stroke="#00ffae" stroke-width=".4" opacity=".05"/>'
            '<line x1="12" y1="0" x2="12" y2="12" stroke="#00ffae" stroke-width=".4" opacity=".05"/>'
            '<circle cx="12" cy="12" r="1.5" fill="#00ffae" opacity=".06"/>'
            '</pattern></defs><rect width="500" height="500" fill="url(#tex)"/>';
    }

    // =========================================================================
    // ETC diamond logo (top-left) — Ethereum Classic identity
    // =========================================================================

    function _etcLogo() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<g style="transform:translate(34px, 32px) scale(0.25)" opacity="0.85">'
            '<g transform="translate(24, 14) scale(0.0156)">'
            '<g transform="translate(0,5120) scale(1,-1)" fill="#00ffae" stroke="none">',
            _etcLogoPaths(),
            '</g></g></g>'
        ));
    }

    function _etcLogoPaths() private pure returns (string memory) {
        return
            '<path d="M2551 5071 c-6 -11 -125 -193 -263 -403 -138 -211 -340 -518 -448'
            ' -683 -108 -165 -321 -490 -474 -723 -153 -233 -276 -425 -274 -427 1 -1 154'
            ' 61 338 139 884 374 1126 476 1137 476 7 0 330 -142 719 -316 388 -173 708'
            ' -314 710 -312 3 3 -1417 2253 -1430 2266 -3 2 -9 -6 -15 -17z"/>'
            '<path d="M2485 3110 c-376 -157 -1450 -612 -1452 -614 -2 -2 99 -60 224 -130'
            ' 126 -69 473 -263 773 -430 l545 -303 40 23 c22 12 357 200 745 418 387 217'
            ' 706 399 708 405 2 6 -1 11 -7 11 -10 0 -175 73 -1036 457 -203 91 -388 173'
            ' -410 183 l-41 18 -89 -38z"/>'
            '<path d="M1119 2083 c16 -21 308 -427 648 -903 341 -476 661 -923 712 -994 51'
            ' -70 95 -135 98 -143 4 -10 10 -6 23 15 10 16 145 206 301 423 155 217 378'
            ' 527 494 689 116 162 316 441 444 619 206 287 253 359 209 324 -7 -6 -343'
            ' -198 -746 -427 l-732 -417 -128 74 c-1304 758 -1336 777 -1346 777 -4 0 6'
            ' -17 23 -37z"/>';
    }

    // =========================================================================
    // Animated border text — Olympia governance branding
    // =========================================================================

    function _generateBorderText(uint256) private pure returns (string memory) {
        string memory line1 = unicode"ethereum classic core contributor \u2022 olympia dao";
        return string(abi.encodePacked(
            '<text text-rendering="optimizeSpeed">'
            '<textPath startOffset="-100%" fill="#00ffae" font-family="', FONT, '" font-size="10px" xlink:href="#text-path-a">',
            line1,
            ' <animate additive="sum" attributeName="startOffset" from="0%" to="100%" begin="0s" dur="30s" repeatCount="indefinite"/>'
            '</textPath>'
            '<textPath startOffset="0%" fill="#00ffae" font-family="', FONT, '" font-size="10px" xlink:href="#text-path-a">',
            line1,
            ' <animate additive="sum" attributeName="startOffset" from="0%" to="100%" begin="0s" dur="30s" repeatCount="indefinite"/>'
            '</textPath>',
            _borderTextSecondHalf()
        ));
    }

    function _borderTextSecondHalf() private pure returns (string memory) {
        string memory line2 = unicode"core software \u2022 critical infrastructure \u2022 network security";
        return string(abi.encodePacked(
            '<textPath startOffset="50%" fill="#00ffae" font-family="', FONT, '" font-size="10px" xlink:href="#text-path-a">',
            line2,
            ' <animate additive="sum" attributeName="startOffset" from="0%" to="100%" begin="0s" dur="30s" repeatCount="indefinite"/>'
            '</textPath>'
            '<textPath startOffset="-50%" fill="#00ffae" font-family="', FONT, '" font-size="10px" xlink:href="#text-path-a">',
            line2,
            ' <animate additive="sum" attributeName="startOffset" from="0%" to="100%" begin="0s" dur="30s" repeatCount="indefinite"/>'
            '</textPath></text>'
        ));
    }

    // =========================================================================
    // Card mantle: large OLYMPIA DAO text + Verified ETC Core Contributor #N
    // =========================================================================

    function _generateCardMantle(uint256 tokenId) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="250" y="190" text-anchor="middle" fill="white" font-family="', FONT,
            '" font-weight="200" font-size="56px" letter-spacing="8">'
            '<tspan x="250">OLYMPIA</tspan>'
            '<tspan x="250" dy="50">DAO</tspan></text>'
            '<text y="270" x="250" text-anchor="middle" fill="#00ffae" opacity=".6" font-family="', FONT,
            '" font-size="14px" font-weight="bold" letter-spacing="1">'
            '<tspan x="250">Verified Ethereum Classic</tspan>'
            '<tspan x="250" dy="20">Core Contributor #',
            tokenId.toString(),
            '</tspan></text>'
        ));
    }

    // =========================================================================
    // Data badges (bottom-left) — Contributor #, Address, Block, Status
    // =========================================================================

    function _generateDataBadges(SVGParams memory params) private pure returns (string memory) {
        return string(abi.encodePacked(
            _dataBadge("350", "Contributor: ", string(abi.encodePacked("#", params.tokenId.toString()))),
            _dataBadge("374", "Address: ", _truncateAddress(params.owner)),
            _dataBadge("398", "Minted: ", string(abi.encodePacked("Block ", params.mintBlock.toString()))),
            _dataBadge("420", "Status: ", "Active")
        ));
    }

    function _dataBadge(string memory yPos, string memory labelText, string memory valueText) private pure returns (string memory) {
        uint256 width = 7 * (bytes(labelText).length + bytes(valueText).length + 4);
        return string(abi.encodePacked(
            '<g style="transform:translate(34px, ', yPos, 'px)">'
            '<rect width="', width.toString(), 'px" height="26px" rx="8px" ry="8px" fill="rgba(10,15,16,0.7)"/>'
            '<text x="12px" y="17px" font-family="', FONT, '" font-size="12px" fill="#E8E8E8">'
            '<tspan fill="rgba(0,255,174,0.6)">', labelText, '</tspan>',
            valueText,
            '</text></g>'
        ));
    }

    /// @dev Truncates an address to 0xABCD...1234 format
    function _truncateAddress(address addr) private pure returns (string memory) {
        string memory full = Strings.toHexString(addr);
        bytes memory b = bytes(full);
        // full is "0x" + 40 hex chars = 42 bytes
        // We want "0xABCD...1234" = first 6 chars + "..." + last 4 chars
        bytes memory result = new bytes(13);
        for (uint256 i = 0; i < 6; i++) {
            result[i] = b[i];
        }
        result[6] = '.';
        result[7] = '.';
        result[8] = '.';
        for (uint256 i = 0; i < 4; i++) {
            result[9 + i] = b[38 + i];
        }
        return string(result);
    }

    // =========================================================================
    // Corner info: chain (top-right)
    // =========================================================================

    function _generateCornerInfo(SVGParams memory params) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="452" y="44" text-anchor="end" fill="rgba(0,255,174,0.4)" font-family="', FONT, '" font-size="10px">',
            params.chain,
            '</text>'
            '<text x="452" y="56" text-anchor="end" fill="rgba(0,255,174,0.25)" font-family="', FONT, '" font-size="8px">',
            'Demo Contract v0.3',
            '</text>'
        ));
    }

    // =========================================================================
    // Color palettes
    // =========================================================================

    /// @dev 5 dark background colors (Olympia brand dark palette)
    function backgroundPalette(uint8 idx) internal pure returns (string memory) {
        if (idx == 0) return "0a0f10"; // brand bg-primary
        if (idx == 1) return "0f1614"; // brand bg-surface
        if (idx == 2) return "0d1412"; // deep dark
        if (idx == 3) return "111a18"; // dark forest
        return "162420";               // brand bg-elevated
    }

    /// @dev 8 gradient circle colors (Olympia green spectrum)
    function circlePalette(uint8 idx) internal pure returns (string memory) {
        if (idx == 0) return "0a2e22"; // abyssal
        if (idx == 1) return "0d3d2e"; // deep shadow
        if (idx == 2) return "132f25"; // dark emerald
        if (idx == 3) return "1a4a38"; // forest
        if (idx == 4) return "1a6b50"; // mid forest
        if (idx == 5) return "007a53"; // brand muted
        if (idx == 6) return "00cc8a"; // brand active
        return "00ffae";               // brand primary
    }
}
