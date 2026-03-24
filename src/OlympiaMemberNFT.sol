// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC5192} from "./interfaces/IERC5192.sol";
import {IOlympiaMemberRenderer} from "./nft/IOlympiaMemberRenderer.sol";

/// @title OlympiaMemberNFT
/// @notice Soulbound governance NFT for Olympia (ECIP-1113)
/// @dev One soulbound NFT = one vote. Non-transferable after mint. KYC-verified
///      accounts receive NFTs via MINTER_ROLE. Compromised or ineligible members
///      can be removed via REVOKER_ROLE. Auto-delegates on mint so votes are
///      active immediately. Uses OZ default block number clock mode.
contract OlympiaMemberNFT is ERC721, ERC721Enumerable, ERC721Votes, IERC5192, AccessControl {
    /// @notice Role that can mint new membership NFTs
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role that can revoke (burn) membership NFTs
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    /// @dev Auto-incrementing token ID counter
    uint256 private _nextTokenId;

    /// @notice Metadata renderer contract (generates on-chain SVG art)
    IOlympiaMemberRenderer public renderer;

    /// @notice Block number at which each token was minted
    mapping(uint256 => uint256) public mintBlocks;

    /// @notice Transfer of soulbound tokens is not allowed
    error SoulboundTransferBlocked();

    /// @notice Address already holds a membership NFT
    error AlreadyMember(address account);

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and MINTER_ROLE
    constructor(address admin) ERC721("Olympia Member v0.3", "OLYMPIAv03") EIP712("Olympia Member v0.3", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(REVOKER_ROLE, admin);
    }

    /// @notice Mint a new membership NFT to a verified address
    /// @param to The recipient address (must have passed KYC/identity verification)
    function safeMint(address to) external onlyRole(MINTER_ROLE) {
        if (balanceOf(to) > 0) revert AlreadyMember(to);
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    /// @notice Revoke a membership NFT (burn). Used to remove compromised or ineligible members.
    /// @param tokenId The token to revoke
    function revoke(uint256 tokenId) external onlyRole(REVOKER_ROLE) {
        _burn(tokenId);
    }

    /// @notice Set or update the metadata renderer contract
    /// @param _renderer Address of the new renderer (or address(0) to disable)
    function setRenderer(address _renderer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        renderer = IOlympiaMemberRenderer(_renderer);
    }

    /// @notice Returns on-chain metadata and SVG art if renderer is set
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        if (address(renderer) == address(0)) {
            return "";
        }
        return renderer.tokenURI(tokenId, ownerOf(tokenId), mintBlocks[tokenId]);
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

        // On mint: record block, auto-delegate, emit Locked
        if (from == address(0) && to != address(0)) {
            mintBlocks[tokenId] = block.number;
            _delegate(to, to);
            emit Locked(tokenId);
        }

        return from;
    }

    /// @dev Required override for diamond inheritance (ERC721 + ERC721Enumerable + ERC721Votes)
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable, ERC721Votes) {
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
