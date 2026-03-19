// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ISanctionsOracle} from "./interfaces/ISanctionsOracle.sol";

/// @title SanctionsOracle
/// @notice On-chain sanctions list with role-gated management (ECIP-1119)
/// @dev Olympia Demo v0.2 — MANAGER_ROLE can add/remove sanctioned addresses.
///      Used by OlympiaGovernor for 3-layer sanctions defense:
///      Layer 1: Block sanctioned proposers at propose()
///      Layer 2: Permissionless cancel of sanctioned proposals
///      Layer 3: Atomic revert at execution if proposer became sanctioned
contract SanctionsOracle is ISanctionsOracle, AccessControl {
    /// @notice Role that can add/remove sanctioned addresses
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Sanctioned address mapping
    mapping(address => bool) private _sanctioned;

    /// @notice Address is already sanctioned
    error AlreadySanctioned(address account);

    /// @notice Address is not sanctioned
    error NotSanctioned(address account);

    /// @notice Zero address is not allowed
    error ZeroAddress();

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and MANAGER_ROLE
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
    }

    /// @inheritdoc ISanctionsOracle
    function isSanctioned(address account) external view returns (bool) {
        return _sanctioned[account];
    }

    /// @notice Add an address to the sanctions list
    /// @param account Address to sanction
    function addAddress(address account) external onlyRole(MANAGER_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        if (_sanctioned[account]) revert AlreadySanctioned(account);
        _sanctioned[account] = true;
        emit AddressAdded(account);
    }

    /// @notice Remove an address from the sanctions list
    /// @param account Address to unsanction
    function removeAddress(address account) external onlyRole(MANAGER_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        if (!_sanctioned[account]) revert NotSanctioned(account);
        _sanctioned[account] = false;
        emit AddressRemoved(account);
    }
}
