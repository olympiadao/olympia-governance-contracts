// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaSVG} from "../../src/nft/OlympiaSVG.sol";

/// @dev Thin wrapper to expose library functions for testing
contract OlympiaSVGHarness {
    function generateSVG(OlympiaSVG.SVGParams memory params) external pure returns (string memory) {
        return OlympiaSVG.generateSVG(params);
    }

    function backgroundPalette(uint8 idx) external pure returns (string memory) {
        return OlympiaSVG.backgroundPalette(idx);
    }

    function circlePalette(uint8 idx) external pure returns (string memory) {
        return OlympiaSVG.circlePalette(idx);
    }
}

contract OlympiaSVGTest is Test {
    OlympiaSVGHarness public harness;

    function setUp() public {
        harness = new OlympiaSVGHarness();
    }

    function _defaultParams() internal pure returns (OlympiaSVG.SVGParams memory) {
        return OlympiaSVG.SVGParams({
            tokenId: 7,
            owner: address(0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537),
            mintBlock: 4821337,
            color0: "0a0f10",
            color1: "007a53",
            color2: "00cc8a",
            color3: "00ffae",
            x1: "120",
            y1: "200",
            x2: "350",
            y2: "100",
            x3: "250",
            y3: "380",
            borderStyle: 0,
            glowColor: 0,
            textureIdx: 0,
            chain: "Mordor Testnet"
        });
    }

    function test_generateSVG_doesNotRevert() public view {
        harness.generateSVG(_defaultParams());
    }

    function test_generateSVG_containsSvgTag() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "<svg"));
        assertTrue(_contains(svg, "</svg>"));
    }

    function test_generateSVG_containsBrandColor() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "00ffae"));
    }

    function test_generateSVG_containsContributorNumber() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "Core Contributor #7"));
    }

    function test_generateSVG_containsOlympiaText() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "OLYMPIA"));
    }

    function test_generateSVG_containsChainName() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "Mordor Testnet"));
    }

    function test_generateSVG_containsTruncatedAddress() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "0x3b09"));
        assertTrue(_contains(svg, "1537"));
    }

    function test_generateSVG_containsMintBlock() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "Block 4821337"));
    }

    function test_generateSVG_containsStatusActive() public view {
        string memory svg = harness.generateSVG(_defaultParams());
        assertTrue(_contains(svg, "Active"));
    }

    function test_differentTokenIds_differentOutput() public view {
        OlympiaSVG.SVGParams memory p1 = _defaultParams();
        OlympiaSVG.SVGParams memory p2 = _defaultParams();
        p2.tokenId = 42;
        p2.color1 = "00ffae";
        p2.color2 = "0a2e22";

        string memory svg1 = harness.generateSVG(p1);
        string memory svg2 = harness.generateSVG(p2);
        assertTrue(keccak256(bytes(svg1)) != keccak256(bytes(svg2)));
    }

    function test_backgroundPalette_returnsValidColors() public view {
        for (uint8 i = 0; i < 5; i++) {
            string memory color = harness.backgroundPalette(i);
            assertEq(bytes(color).length, 6);
        }
    }

    function test_circlePalette_returnsValidColors() public view {
        for (uint8 i = 0; i < 8; i++) {
            string memory color = harness.circlePalette(i);
            assertEq(bytes(color).length, 6);
        }
    }

    // --- Helpers ---

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
