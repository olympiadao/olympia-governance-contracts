// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaMemberRenderer} from "../../src/nft/OlympiaMemberRenderer.sol";
import {OlympiaMemberNFT} from "../../src/OlympiaMemberNFT.sol";

contract OlympiaMemberRendererTest is Test {
    OlympiaMemberRenderer public renderer;
    OlympiaMemberNFT public nft;
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");

    function setUp() public {
        renderer = new OlympiaMemberRenderer();
        nft = new OlympiaMemberNFT(admin);
        vm.prank(admin);
        nft.setRenderer(address(renderer));
    }

    // --- Standalone renderer tests ---

    function test_tokenURI_returnsDataUri() public view {
        string memory uri = renderer.tokenURI(0, alice, 100);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
    }

    function test_tokenURI_deterministicOutput() public view {
        string memory uri1 = renderer.tokenURI(7, alice, 100);
        string memory uri2 = renderer.tokenURI(7, alice, 100);
        assertEq(keccak256(bytes(uri1)), keccak256(bytes(uri2)));
    }

    function test_tokenURI_differentTokenIds_differentOutput() public view {
        string memory uri1 = renderer.tokenURI(0, alice, 100);
        string memory uri2 = renderer.tokenURI(1, alice, 100);
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)));
    }

    function test_tokenURI_containsName() public view {
        string memory uri = renderer.tokenURI(7, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Olympia v0.3 Contributor #7"));
    }

    function test_tokenURI_containsDescription() public view {
        string memory uri = renderer.tokenURI(0, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Soulbound governance NFT"));
    }

    function test_tokenURI_containsImageField() public view {
        string memory uri = renderer.tokenURI(0, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, '"image":"data:image/svg+xml;base64,'));
    }

    function test_tokenURI_containsAttributes() public view {
        string memory uri = renderer.tokenURI(42, alice, 5000);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, '"Contributor Number"'));
        assertTrue(_contains(decoded, '"Chain"'));
        assertTrue(_contains(decoded, '"Mint Block"'));
        assertTrue(_contains(decoded, '"Active"'));
    }

    function test_tokenURI_chainName_mordor() public view {
        // Default foundry chainid is 31337, so chain will be "Unknown Chain"
        string memory uri = renderer.tokenURI(0, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Unknown Chain"));
    }

    function test_tokenURI_chainName_mordorFork() public {
        vm.chainId(63);
        string memory uri = renderer.tokenURI(0, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Mordor Testnet"));
    }

    function test_tokenURI_chainName_etc() public {
        vm.chainId(61);
        string memory uri = renderer.tokenURI(0, alice, 100);
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Ethereum Classic"));
    }

    // --- Integration with NFT ---

    function test_fullPipeline_mintAndRenderTokenURI() public {
        vm.roll(42);
        vm.prank(admin);
        nft.safeMint(alice);

        string memory uri = nft.tokenURI(0);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
        string memory decoded = _decodeDataUri(uri);
        assertTrue(_contains(decoded, "Olympia v0.3 Contributor #0"));
    }

    function test_fullPipeline_multipleTokens() public {
        vm.roll(100);
        vm.prank(admin);
        nft.safeMint(alice);

        vm.roll(200);
        vm.prank(admin);
        nft.safeMint(makeAddr("bob"));

        string memory uri0 = nft.tokenURI(0);
        string memory uri1 = nft.tokenURI(1);
        assertTrue(keccak256(bytes(uri0)) != keccak256(bytes(uri1)));
    }

    function test_fullPipeline_revokedTokenReverts() public {
        vm.prank(admin);
        nft.safeMint(alice);

        vm.prank(admin);
        nft.revoke(0);

        vm.expectRevert();
        nft.tokenURI(0);
    }

    function test_fullPipeline_rendererUpgrade() public {
        vm.prank(admin);
        nft.safeMint(alice);

        string memory uri1 = nft.tokenURI(0);

        // Deploy new renderer and switch
        OlympiaMemberRenderer newRenderer = new OlympiaMemberRenderer();
        vm.prank(admin);
        nft.setRenderer(address(newRenderer));

        // Same renderer code produces same output
        string memory uri2 = nft.tokenURI(0);
        assertEq(keccak256(bytes(uri1)), keccak256(bytes(uri2)));
    }

    // --- Helpers ---

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory s = bytes(str);
        bytes memory p = bytes(prefix);
        if (p.length > s.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (s[i] != p[i]) return false;
        }
        return true;
    }

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

    /// @dev Decode a data:application/json;base64,... URI to raw JSON string
    function _decodeDataUri(string memory uri) internal pure returns (string memory) {
        bytes memory b = bytes(uri);
        uint256 prefixLen = 29; // "data:application/json;base64,"
        bytes memory encoded = new bytes(b.length - prefixLen);
        for (uint256 i = 0; i < encoded.length; i++) {
            encoded[i] = b[prefixLen + i];
        }
        return string(_base64Decode(encoded));
    }

    /// @dev Simple Base64 decoder for tests (OZ 5.1 only has encode)
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
        return 0; // '=' padding
    }
}
