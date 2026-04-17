// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC5192} from "./interfaces/IERC5192.sol";
import {IMembershipVerifier} from "./interfaces/IMembershipVerifier.sol";
import {IGovernorHasVoted} from "./interfaces/IGovernorHasVoted.sol";
import {IOlympiaDAOMemberRenderer} from "./nft/IOlympiaDAOMemberRenderer.sol";

/// @title OlympiaDAOMemberNFT
/// @notice Soulbound governance NFT for OlympiaDAO (ECIP-1113)
/// @dev One soulbound NFT = one vote. Non-transferable after mint. KYC-verified
///      accounts receive NFTs via MINTER_ROLE. Compromised or ineligible members
///      can be removed via REVOKER_ROLE. Auto-delegates on mint so votes are
///      active immediately. Uses OZ default block number clock mode.
///
///      Activity tracking (demo_v0.4):
///      - lastActivityBlock initialised to mint block
///      - Updated on explicit delegate/re-delegate via _delegate override
///      - Updated via confirmVoteActivity() after member votes on a proposal
///      - Permissionless revokeIfInactive() burns token when block.number exceeds
///        lastActivityBlock + inactivityThreshold
///
///      No modification to OlympiaDAOGovernor is required — vote witnessing reads
///      the public hasVoted() view function from the OZ Governor.
contract OlympiaDAOMemberNFT is ERC721, ERC721Enumerable, ERC721Votes, IERC5192, AccessControl {
    // =========================================================================
    // Roles
    // =========================================================================

    /// @notice Role that can mint new membership NFTs
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role that can revoke (burn) membership NFTs
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    // =========================================================================
    // State
    // =========================================================================

    /// @dev Auto-incrementing token ID counter
    uint256 private _nextTokenId;

    /// @notice Metadata renderer contract (generates on-chain SVG art)
    IOlympiaDAOMemberRenderer public renderer;

    /// @notice Membership verifier contract (sybil resistance, ECIP-1113 §2)
    IMembershipVerifier public verifier;

    /// @notice Block number at which each token was minted
    mapping(uint256 => uint256) public mintBlocks;

    /// @notice Block number of last recorded on-chain governance activity per member.
    ///         Initialised to mint block. Updated on delegation and vote confirmation.
    mapping(address => uint256) public lastActivityBlock;

    /// @notice Blocks of inactivity before permissionless revocation is allowed.
    ///         0 = inactivity revocation disabled.
    uint256 public inactivityThreshold;

    /// @notice OlympiaDAO Governor reference for vote-witness confirmation.
    ///         May be address(0) at deploy; set via setGovernor() after governance is live.
    IGovernorHasVoted public governor;

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice Transfer of soulbound tokens is not allowed
    error SoulboundTransferBlocked();

    /// @notice Address already holds a membership NFT
    error AlreadyMember(address account);

    /// @notice Address has not been verified by the membership verifier
    error NotVerified(address account);

    /// @notice Inactivity revocation is disabled (inactivityThreshold == 0)
    error InactivityDisabled();

    /// @notice Member is still within the activity window
    error StillActive(address member, uint256 lastActivity, uint256 threshold);

    /// @notice Member did not vote on the specified proposal
    error DidNotVote(uint256 proposalId, address member);

    // =========================================================================
    // Events
    // =========================================================================

    event MembershipExpiredByInactivity(
        uint256 indexed tokenId, address indexed member, uint256 lastActivityBlock
    );
    event InactivityThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event GovernorUpdated(address indexed oldGovernor, address indexed newGovernor);

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param name_               ERC721 display name (e.g. "OlympiaDAO Member v0.4")
    /// @param symbol_             ERC721 ticker symbol (e.g. "OLYMPIADAOv04")
    /// @param admin               Address that receives DEFAULT_ADMIN_ROLE, MINTER_ROLE, REVOKER_ROLE
    /// @param inactivityThreshold_ Blocks of inactivity before permissionless revocation (0 = disabled)
    /// @param governor_           Governor for vote-witness confirmation (may be address(0) at deploy)
    constructor(
        string memory name_,
        string memory symbol_,
        address admin,
        uint256 inactivityThreshold_,
        address governor_
    ) ERC721(name_, symbol_) EIP712(name_, "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(REVOKER_ROLE, admin);
        inactivityThreshold = inactivityThreshold_;
        governor = IGovernorHasVoted(governor_);
    }

    // =========================================================================
    // Minting
    // =========================================================================

    /// @notice Mint a new membership NFT to a verified address
    /// @param to The recipient address (must pass verifier check if verifier is set)
    function safeMint(address to) external onlyRole(MINTER_ROLE) {
        if (address(verifier) != address(0) && !verifier.isVerified(to)) {
            revert NotVerified(to);
        }
        if (balanceOf(to) > 0) revert AlreadyMember(to);
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    // =========================================================================
    // Activity tracking
    // =========================================================================

    /// @notice Permissionless vote-witness: confirm a member voted on a past proposal.
    ///         Anyone can call this for any member after they voted.
    ///         Reads OZ Governor's public hasVoted() view — no Governor modification required.
    /// @param proposalId Governor proposal ID the member voted on
    /// @param member     The member whose activity clock to refresh
    function confirmVoteActivity(uint256 proposalId, address member) external {
        if (address(governor) == address(0) || !governor.hasVoted(proposalId, member)) {
            revert DidNotVote(proposalId, member);
        }
        lastActivityBlock[member] = block.number;
    }

    // =========================================================================
    // Inactivity revocation
    // =========================================================================

    /// @notice Permissionless inactivity revocation.
    ///         Burns the token when the member's lastActivityBlock is older than
    ///         block.number - inactivityThreshold.
    /// @param tokenId The token to revoke
    function revokeIfInactive(uint256 tokenId) public {
        if (inactivityThreshold == 0) revert InactivityDisabled();
        address member = ownerOf(tokenId);
        uint256 lastActivity = lastActivityBlock[member];
        if (block.number < lastActivity + inactivityThreshold) {
            revert StillActive(member, lastActivity, inactivityThreshold);
        }
        emit MembershipExpiredByInactivity(tokenId, member, lastActivity);
        _burn(tokenId);
    }

    /// @notice Batch permissionless inactivity revocation
    /// @param tokenIds Array of token IDs to attempt revocation on
    function batchRevokeIfInactive(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            revokeIfInactive(tokenIds[i]);
        }
    }

    // =========================================================================
    // Admin
    // =========================================================================

    /// @notice Revoke a membership NFT (burn) via REVOKER_ROLE
    function revoke(uint256 tokenId) external onlyRole(REVOKER_ROLE) {
        _burn(tokenId);
    }

    /// @notice Set or update the membership verifier contract
    function setVerifier(address _verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        verifier = IMembershipVerifier(_verifier);
    }

    /// @notice Set or update the metadata renderer contract
    function setRenderer(address _renderer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        renderer = IOlympiaDAOMemberRenderer(_renderer);
    }

    /// @notice Update inactivity threshold (DEFAULT_ADMIN_ROLE; use OIP after governance is live)
    function setInactivityThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 old = inactivityThreshold;
        inactivityThreshold = newThreshold;
        emit InactivityThresholdUpdated(old, newThreshold);
    }

    /// @notice Update governor reference for vote-witness confirmation
    ///         (DEFAULT_ADMIN_ROLE; use OIP after governance is live)
    function setGovernor(address newGovernor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address old = address(governor);
        governor = IGovernorHasVoted(newGovernor);
        emit GovernorUpdated(old, newGovernor);
    }

    // =========================================================================
    // Metadata
    // =========================================================================

    /// @notice Returns on-chain metadata and SVG art if renderer is set
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        if (address(renderer) == address(0)) {
            return "";
        }
        address owner = ownerOf(tokenId);
        return renderer.tokenURI(tokenId, owner, mintBlocks[tokenId], lastActivityBlock[owner]);
    }

    /// @inheritdoc IERC5192
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    // =========================================================================
    // Internal overrides
    // =========================================================================

    /// @dev Soulbound enforcement + auto-delegate + ERC5192 event + activity init.
    ///      Blocks transfers (from != 0 && to != 0). Allows mint and burn.
    ///      On mint: records block, initialises lastActivityBlock, auto-delegates, emits Locked.
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

        // On mint: record block, initialise activity, auto-delegate, emit Locked
        if (from == address(0) && to != address(0)) {
            mintBlocks[tokenId] = block.number;
            lastActivityBlock[to] = block.number;
            _delegate(to, to);
            emit Locked(tokenId);
        }

        return from;
    }

    /// @dev Track explicit re-delegation as governance activity.
    ///      balanceOf guard prevents updating lastActivityBlock during the mint flow
    ///      (where _delegate is called internally before the balance is settled in
    ///      some ERC721Votes code paths). _update sets lastActivityBlock first on mint.
    function _delegate(address account, address delegatee) internal override(Votes) {
        super._delegate(account, delegatee);
        if (balanceOf(account) > 0) {
            lastActivityBlock[account] = block.number;
        }
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
