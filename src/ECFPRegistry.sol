// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title ECFPRegistry
/// @notice Hash-bound funding proposal registry with GOVERNOR_ROLE-gated status transitions (ECIP-1114)
/// @dev Proposals are permissionlessly submitted subject to a draft cap and submission bond.
///      Slashed bonds (expired spam/low-quality drafts) are forwarded to OlympiaTreasury.
///      Legitimate proposals have their bonds returned via a pull-refund pattern on activation.
///      See docs/ATTRIBUTION.md for design pattern attribution.
contract ECFPRegistry is AccessControl, ReentrancyGuard {
    using Address for address payable;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    enum ProposalStatus {
        Draft,
        Active,
        Approved,
        Rejected,
        Executed,
        Expired,
        Withdrawn
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

    uint256 public immutable minReviewPeriod;

    /// @notice Maximum simultaneous Draft proposals per address. Immutable — cannot be governance-attacked post-deploy.
    uint256 public immutable maxDraftsPerAddress;

    /// @notice Number of active (unresolved) Draft proposals per address.
    mapping(address => uint256) public activeDraftCount;

    /// @notice Submission bond amount in wei. Mutable via setSubmissionBond() (DEFAULT_ADMIN_ROLE = TimelockController).
    uint256 public submissionBond;

    /// @notice Bond held per proposal hashId. Set at submit, cleared at resolution.
    mapping(bytes32 => uint256) public bondOf;

    /// @notice Pending bond refunds for proposers (pull payment pattern).
    mapping(address => uint256) public pendingRefunds;

    /// @notice OlympiaTreasury address. Slashed bonds are forwarded here.
    address private immutable _treasury;

    mapping(bytes32 => Proposal) internal _proposals;

    event ProposalSubmitted(
        bytes32 indexed hashId, bytes32 ecfpId, address recipient, uint256 amount, bytes32 metadataCID
    );
    event ProposalActivated(bytes32 indexed hashId);
    event ProposalQueued(bytes32 indexed hashId);
    event ProposalExecuted(
        uint256 indexed ecfpId, bytes32 indexed hashId, address recipient, uint256 amount, uint256 timestamp
    );
    event ProposalRejected(bytes32 indexed hashId);
    event ProposalExpired(bytes32 indexed hashId);
    event DraftUpdated(uint256 indexed ecfpId, bytes32 indexed oldHashId, bytes32 indexed newHashId);
    event DraftWithdrawn(uint256 indexed ecfpId, bytes32 indexed hashId);
    event SubmissionBondUpdated(uint256 oldBond, uint256 newBond);
    event RefundPending(address indexed proposer, uint256 amount);
    event RefundClaimed(address indexed proposer, uint256 amount);

    error DuplicateProposal(bytes32 hashId);
    error ProposalNotFound(bytes32 hashId);
    error InvalidStatusTransition(ProposalStatus current, ProposalStatus target);
    error ZeroRecipient();
    error ZeroAmount();
    error EmptyMetadata();
    error EmptyEcfpId();
    error NotSubmitter();
    error ReviewPeriodActive();
    error TooManyActiveDrafts(address submitter, uint256 cap);
    error IncorrectBond(uint256 required, uint256 sent);
    error NoRefundPending();
    error ZeroTreasury();
    error ZeroMaxDrafts();

    constructor(
        address admin,
        uint256 _minReviewPeriod,
        uint256 _maxDraftsPerAddress,
        uint256 _initialSubmissionBond,
        address treasuryAddress
    ) {
        if (treasuryAddress == address(0)) revert ZeroTreasury();
        if (_maxDraftsPerAddress == 0) revert ZeroMaxDrafts();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
        minReviewPeriod = _minReviewPeriod;
        maxDraftsPerAddress = _maxDraftsPerAddress;
        submissionBond = _initialSubmissionBond;
        _treasury = treasuryAddress;
    }

    /// @notice Submit a new funding proposal (permissionless — any ETC address).
    ///         Requires msg.value == submissionBond. Bond is returned on activation, slashed on expiry.
    function submit(bytes32 ecfpId, address recipient, uint256 amount, bytes32 metadataCID)
        external
        payable
        returns (bytes32 hashId)
    {
        if (ecfpId == bytes32(0)) revert EmptyEcfpId();
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        if (metadataCID == bytes32(0)) revert EmptyMetadata();
        if (msg.value != submissionBond) revert IncorrectBond(submissionBond, msg.value);
        if (activeDraftCount[msg.sender] >= maxDraftsPerAddress) {
            revert TooManyActiveDrafts(msg.sender, maxDraftsPerAddress);
        }

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

        bondOf[hashId] = msg.value;
        activeDraftCount[msg.sender]++;

        emit ProposalSubmitted(hashId, ecfpId, recipient, amount, metadataCID);
    }

    /// @notice Update a Draft proposal's fields (only original submitter, only Draft status).
    ///         If hashId changes, the bond migrates to the new hashId — no additional payment required.
    function updateDraft(bytes32 hashId, address recipient, uint256 amount, bytes32 metadataCID)
        external
        returns (bytes32 newHashId)
    {
        _requireExists(hashId);
        Proposal storage p = _proposals[hashId];
        if (p.status != ProposalStatus.Draft) {
            revert InvalidStatusTransition(p.status, ProposalStatus.Draft);
        }
        if (msg.sender != p.proposer) revert NotSubmitter();
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        if (metadataCID == bytes32(0)) revert EmptyMetadata();

        bytes32 ecfpId = p.ecfpId;
        newHashId = keccak256(abi.encodePacked(ecfpId, recipient, amount, metadataCID, block.chainid));
        if (newHashId != hashId && _proposals[newHashId].timestamp != 0) revert DuplicateProposal(newHashId);

        if (newHashId != hashId) {
            // Migrate bond to new hashId — no re-payment required for an update
            bondOf[newHashId] = bondOf[hashId];
            bondOf[hashId] = 0;

            // Mark old entry as withdrawn, create new entry
            p.status = ProposalStatus.Withdrawn;
            _proposals[newHashId] = Proposal({
                ecfpId: ecfpId,
                recipient: recipient,
                amount: amount,
                metadataCID: metadataCID,
                proposer: msg.sender,
                timestamp: block.timestamp,
                status: ProposalStatus.Draft
            });
            // activeDraftCount stays the same — still 1 draft for this proposer
        } else {
            p.recipient = recipient;
            p.amount = amount;
            p.metadataCID = metadataCID;
            p.timestamp = block.timestamp;
        }

        emit DraftUpdated(uint256(ecfpId), hashId, newHashId);
    }

    /// @notice Withdraw a Draft proposal (only original submitter, only Draft status).
    ///         Bond is returned via pendingRefunds — call claimRefund() to receive it.
    function withdrawDraft(bytes32 hashId) external {
        _requireExists(hashId);
        Proposal storage p = _proposals[hashId];
        if (p.status != ProposalStatus.Draft) {
            revert InvalidStatusTransition(p.status, ProposalStatus.Withdrawn);
        }
        if (msg.sender != p.proposer) revert NotSubmitter();

        p.status = ProposalStatus.Withdrawn;

        // Return bond via pull pattern
        uint256 bond = bondOf[hashId];
        bondOf[hashId] = 0;
        activeDraftCount[msg.sender]--;

        if (bond > 0) {
            pendingRefunds[msg.sender] += bond;
            emit RefundPending(msg.sender, bond);
        }

        emit DraftWithdrawn(uint256(p.ecfpId), hashId);
    }

    /// @notice Activate a Draft proposal (Draft → Active). Enforces minimum review period.
    ///         Bond is queued for refund via pendingRefunds — proposer calls claimRefund() to receive it.
    function activateProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) {
        _requireExists(hashId);
        Proposal storage p = _proposals[hashId];
        if (p.status != ProposalStatus.Draft) {
            revert InvalidStatusTransition(p.status, ProposalStatus.Active);
        }
        if (block.timestamp < p.timestamp + minReviewPeriod) revert ReviewPeriodActive();

        p.status = ProposalStatus.Active;

        // Return bond via pull pattern — Draft count decrements as proposal leaves Draft
        uint256 bond = bondOf[hashId];
        bondOf[hashId] = 0;
        activeDraftCount[p.proposer]--;

        if (bond > 0) {
            pendingRefunds[p.proposer] += bond;
            emit RefundPending(p.proposer, bond);
        }

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
        emit ProposalExecuted(uint256(p.ecfpId), hashId, p.recipient, p.amount, block.timestamp);
    }

    /// @notice Expire a Draft or Active proposal (Draft/Active → Expired).
    ///         If Draft: bond is slashed to OlympiaTreasury, draft count decremented.
    ///         If Active: no bond transfer (bond already returned at activation).
    function expireProposal(bytes32 hashId) external onlyRole(GOVERNOR_ROLE) nonReentrant {
        _requireExists(hashId);
        ProposalStatus current = _proposals[hashId].status;
        if (current != ProposalStatus.Draft && current != ProposalStatus.Active) {
            revert InvalidStatusTransition(current, ProposalStatus.Expired);
        }

        _proposals[hashId].status = ProposalStatus.Expired;

        if (current == ProposalStatus.Draft) {
            // Slash: bond goes to treasury, count decrements
            uint256 bond = bondOf[hashId];
            bondOf[hashId] = 0;
            activeDraftCount[_proposals[hashId].proposer]--;

            if (bond > 0) {
                payable(_treasury).sendValue(bond);
            }
        }
        // Active expiry: bond was already returned to pendingRefunds at activateProposal()

        emit ProposalExpired(hashId);
    }

    /// @notice Expire multiple Draft proposals in a single transaction (GOVERNOR_ROLE only).
    ///         All slashed bonds are forwarded to OlympiaTreasury.
    function batchExpire(bytes32[] calldata hashIds) external onlyRole(GOVERNOR_ROLE) nonReentrant {
        for (uint256 i = 0; i < hashIds.length; i++) {
            bytes32 hashId = hashIds[i];
            _requireExists(hashId);
            ProposalStatus current = _proposals[hashId].status;
            if (current != ProposalStatus.Draft && current != ProposalStatus.Active) {
                revert InvalidStatusTransition(current, ProposalStatus.Expired);
            }

            _proposals[hashId].status = ProposalStatus.Expired;

            if (current == ProposalStatus.Draft) {
                uint256 bond = bondOf[hashId];
                bondOf[hashId] = 0;
                activeDraftCount[_proposals[hashId].proposer]--;

                if (bond > 0) {
                    payable(_treasury).sendValue(bond);
                }
            }

            emit ProposalExpired(hashId);
        }
    }

    /// @notice Claim any pending bond refunds. Uses pull-over-push to eliminate reentrancy risk.
    function claimRefund() external nonReentrant {
        uint256 amount = pendingRefunds[msg.sender];
        if (amount == 0) revert NoRefundPending();
        pendingRefunds[msg.sender] = 0;
        payable(msg.sender).sendValue(amount);
        emit RefundClaimed(msg.sender, amount);
    }

    /// @notice Update the submission bond amount. Takes effect on the next submit() call.
    ///         Requires DEFAULT_ADMIN_ROLE (TimelockController) — changing the bond requires a DAO vote.
    function setSubmissionBond(uint256 newBond) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 old = submissionBond;
        submissionBond = newBond;
        emit SubmissionBondUpdated(old, newBond);
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

    /// @notice OlympiaTreasury address that receives slashed bonds
    function treasury() external view returns (address) {
        return _treasury;
    }

    function _requireExists(bytes32 hashId) internal view {
        if (_proposals[hashId].timestamp == 0) revert ProposalNotFound(hashId);
    }
}
