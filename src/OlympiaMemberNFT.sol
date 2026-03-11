// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC5192} from "./interfaces/IERC5192.sol";

/// @title OlympiaMemberNFT
/// @notice Soulbound governance NFT for Olympia Demo v0.1 (ECIP-1113)
/// @dev One soulbound NFT = one vote. Non-transferable after mint. KYC-verified
///      accounts receive NFTs via MINTER_ROLE. Auto-delegates on mint so votes
///      are active immediately. Uses OZ default block number clock mode.
contract OlympiaMemberNFT is ERC721, ERC721Enumerable, ERC721Votes, IERC5192, AccessControl {
    /// @notice Role that can mint new membership NFTs
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Auto-incrementing token ID counter
    uint256 private _nextTokenId;

    /// @notice Transfer of soulbound tokens is not allowed
    error SoulboundTransferBlocked();

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and MINTER_ROLE
    constructor(address admin) ERC721("Olympia Member", "OLYMPIA") EIP712("Olympia Member", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    /// @notice Mint a new membership NFT to a verified address
    /// @param to The recipient address (must have passed KYC/identity verification)
    function safeMint(address to) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    /// @inheritdoc IERC5192
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @dev Soulbound enforcement + auto-delegate + ERC5192 event.
    ///      Blocks transfers (from != 0 && to != 0). Allows mint and burn.
    ///      On mint: auto-delegates to recipient and emits Locked.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
        returns (address)
    {
        address from = super._update(to, tokenId, auth);

        // Block transfers (allow mint: from==0, allow burn: to==0)
        if (from != address(0) && to != address(0)) {
            revert SoulboundTransferBlocked();
        }

        // On mint: auto-delegate so votes are active immediately
        if (from == address(0) && to != address(0)) {
            _delegate(to, to);
            emit Locked(tokenId);
        }

        return from;
    }

    /// @dev Required override for diamond inheritance (ERC721 + ERC721Enumerable + ERC721Votes)
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
    {
        super._increaseBalance(account, value);
    }

    /// @dev ERC165 interface support including IERC5192
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }
}
