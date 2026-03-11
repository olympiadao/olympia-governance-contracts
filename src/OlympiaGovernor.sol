// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorPreventLateQuorum} from "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";
import {GovernorStorage} from "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ISanctionsOracle} from "./interfaces/ISanctionsOracle.sol";

/// @title OlympiaGovernor
/// @notice CoreDAO Governor with 3-layer sanctions defense (ECIP-1113, ECIP-1119)
/// @dev Demo v0.1: GovernorVotes reads OlympiaMemberNFT directly. One soulbound NFT = one vote.
contract OlympiaGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    GovernorPreventLateQuorum,
    GovernorStorage
{
    ISanctionsOracle public sanctionsOracle;

    event SanctionsOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event ProposalCancelledDueToSanctions(uint256 indexed proposalId, address indexed sanctionedAddr);

    error SanctionedRecipient(address account);
    error NoSanctionedRecipients(uint256 proposalId);
    error SanctionsOracleZeroAddress();

    constructor(
        string memory name_,
        IVotes token_,
        ISanctionsOracle sanctionsOracle_,
        TimelockController timelock_,
        uint48 votingDelay_,
        uint32 votingPeriod_,
        uint256 quorumPercent_,
        uint48 lateQuorumExtension_
    )
        Governor(name_)
        GovernorSettings(votingDelay_, votingPeriod_, 0)
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(quorumPercent_)
        GovernorTimelockControl(timelock_)
        GovernorPreventLateQuorum(lateQuorumExtension_)
    {
        sanctionsOracle = sanctionsOracle_;
    }

    // =========================================================================
    // Layer 1: Early sanctions check at propose()
    // =========================================================================

    /// @notice Override propose to check recipients against SanctionsOracle
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(Governor) returns (uint256) {
        _checkSanctionedRecipients(targets, calldatas);
        return super.propose(targets, values, calldatas, description);
    }

    // =========================================================================
    // Layer 2: Permissionless cancel if recipient becomes sanctioned
    // =========================================================================

    /// @notice Cancel a proposal if any recipient is now sanctioned
    /// @dev Callable by anyone — permissionless sanctions enforcement
    function cancelIfSanctioned(uint256 proposalId) external {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) =
            proposalDetails(proposalId);

        address sanctioned = _findSanctionedRecipient(targets, calldatas);
        if (sanctioned == address(0)) {
            revert NoSanctionedRecipients(proposalId);
        }

        emit ProposalCancelledDueToSanctions(proposalId, sanctioned);
        _cancel(targets, values, calldatas, descriptionHash);
    }

    // =========================================================================
    // OIP self-upgrade: sanctions oracle
    // =========================================================================

    /// @notice Update the sanctions oracle via governance proposal
    function updateSanctionsOracle(ISanctionsOracle newOracle) external onlyGovernance {
        if (address(newOracle) == address(0)) revert SanctionsOracleZeroAddress();
        address oldOracle = address(sanctionsOracle);
        sanctionsOracle = newOracle;
        emit SanctionsOracleUpdated(oldOracle, address(newOracle));
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    /// @dev Revert if any target or calldata recipient is sanctioned
    function _checkSanctionedRecipients(address[] memory targets, bytes[] memory calldatas) internal view {
        address sanctioned = _findSanctionedRecipient(targets, calldatas);
        if (sanctioned != address(0)) {
            revert SanctionedRecipient(sanctioned);
        }
    }

    /// @dev Scan targets and calldatas for sanctioned addresses. Returns address(0) if none found.
    function _findSanctionedRecipient(address[] memory targets, bytes[] memory calldatas)
        internal
        view
        returns (address)
    {
        for (uint256 i = 0; i < targets.length; i++) {
            // Check the target address itself
            if (sanctionsOracle.isSanctioned(targets[i])) {
                return targets[i];
            }
            // Decode recipient from calldata if it looks like executeTreasury(address,uint256)
            if (calldatas[i].length >= 36) {
                bytes4 selector;
                address recipient;
                assembly {
                    let data := mload(add(calldatas, mul(add(i, 1), 0x20)))
                    selector := mload(add(data, 0x20))
                    recipient := mload(add(data, 0x24))
                }
                // Clean upper bits
                recipient = address(uint160(recipient));
                if (recipient != address(0) && sanctionsOracle.isSanctioned(recipient)) {
                    return recipient;
                }
            }
        }
        return address(0);
    }

    // =========================================================================
    // Diamond inheritance overrides (pass-throughs to super)
    // =========================================================================

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        override(Governor, GovernorPreventLateQuorum)
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function quorum(uint256 timepoint) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(timepoint);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function _tallyUpdated(uint256 proposalId) internal override(Governor, GovernorPreventLateQuorum) {
        super._tallyUpdated(proposalId);
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }
}
