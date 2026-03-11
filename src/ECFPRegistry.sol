// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title ECFPRegistry
/// @notice Hash-bound funding proposal registry with GOVERNOR_ROLE-gated status transitions (ECIP-1114)
/// @dev Proposals are permissionlessly submitted; status transitions require GOVERNOR_ROLE.
contract ECFPRegistry is AccessControl {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    enum ProposalStatus {
        Draft,
        Active,
        Approved,
        Rejected,
        Executed,
        Expired
    }

    struct Proposal {
        bytes32 ecfpId;
        address recipient;
        uint256 amount;
        bytes32 metadataCID;
        address proposer;
        uint256 timestamp;
        ProposalStatus status;
    }

    mapping(bytes32 => Proposal) internal _proposals;

    event ProposalSubmitted(
        bytes32 indexed hashId, bytes32 ecfpId, address recipient, uint256 amount, bytes32 metadataCID
    );
    event ProposalActivated(bytes32 indexed hashId);
    event ProposalQueued(bytes32 indexed hashId);
    event ProposalExecuted(bytes32 indexed hashId, address recipient, uint256 amount, uint256 timestamp);
    event ProposalRejected(bytes32 indexed hashId);
    event ProposalExpired(bytes32 indexed hashId);

    error DuplicateProposal(bytes32 hashId);
    error ProposalNotFound(bytes32 hashId);
    error InvalidStatusTransition(ProposalStatus current, ProposalStatus target);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
    }

    /// @notice Submit a new funding proposal (permissionless)
    function submit(bytes32 ecfpId, address recipient, uint256 amount, bytes32 metadataCID)
        external
        returns (bytes32 hashId)
    {
        hashId = keccak256(abi.encodePacked(ecfpId, recipient, amount, metadataCID, block.chainid));
        if (_proposals[hashId].timestamp != 0) revert DuplicateProposal(hashId);

        _proposals[hashId] = Proposal({
            ecfpId: ecfpId,
            recipient: recipient,
            amount: amount,
            metadataCID: metadataCID,
            proposer: msg.sender,
            timestamp: block.timestamp,
            status: ProposalStatus.Draft
        });

        emit ProposalSubmitted(hashId, ecfpId, recipient, amount, metadataCID);
    }

    /// @notice Activate a Draft proposal (Draft → Active)
    function activateProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        if (_proposals[hashId].status != ProposalStatus.Draft) {
            revert InvalidStatusTransition(_proposals[hashId].status, ProposalStatus.Active);
        }
        _proposals[hashId].status = ProposalStatus.Active;
        emit ProposalActivated(hashId);
    }

    /// @notice Approve an Active proposal (Active → Approved)
    function approveProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        if (_proposals[hashId].status != ProposalStatus.Active) {
            revert InvalidStatusTransition(_proposals[hashId].status, ProposalStatus.Approved);
        }
        _proposals[hashId].status = ProposalStatus.Approved;
        emit ProposalQueued(hashId);
    }

    /// @notice Reject an Active proposal (Active → Rejected)
    function rejectProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        if (_proposals[hashId].status != ProposalStatus.Active) {
            revert InvalidStatusTransition(_proposals[hashId].status, ProposalStatus.Rejected);
        }
        _proposals[hashId].status = ProposalStatus.Rejected;
        emit ProposalRejected(hashId);
    }

    /// @notice Mark an Approved proposal as Executed (Approved → Executed)
    function markExecuted(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        if (_proposals[hashId].status != ProposalStatus.Approved) {
            revert InvalidStatusTransition(_proposals[hashId].status, ProposalStatus.Executed);
        }
        _proposals[hashId].status = ProposalStatus.Executed;
        Proposal storage p = _proposals[hashId];
        emit ProposalExecuted(hashId, p.recipient, p.amount, block.timestamp);
    }

    /// @notice Expire a Draft or Active proposal (Draft/Active → Expired)
    function expireProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        ProposalStatus current = _proposals[hashId].status;
        if (current != ProposalStatus.Draft && current != ProposalStatus.Active) {
            revert InvalidStatusTransition(current, ProposalStatus.Expired);
        }
        _proposals[hashId].status = ProposalStatus.Expired;
        emit ProposalExpired(hashId);
    }

    /// @notice Compute the hash-bound identifier for a proposal
    function computeHashId(bytes32 ecfpId, address recipient, uint256 amount, bytes32 metadataCID)
        external
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(ecfpId, recipient, amount, metadataCID, block.chainid));
    }

    /// @notice Get proposal data by hashId
    function getProposal(bytes32 hashId) external view returns (Proposal memory) {
        _requireExists(hashId);
        return _proposals[hashId];
    }

    function _requireExists(bytes32 hashId) internal view {
        if (_proposals[hashId].timestamp == 0) revert ProposalNotFound(hashId);
    }
}
