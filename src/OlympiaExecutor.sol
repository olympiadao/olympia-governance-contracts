// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISanctionsOracle} from "./interfaces/ISanctionsOracle.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";

/// @title OlympiaExecutor
/// @notice Layer 3 sanctions gate between Timelock and Treasury (ECIP-1113, ECIP-1119)
/// @dev Sits between TimelockController and OlympiaTreasury. Holds WITHDRAWER_ROLE on Treasury.
///      Checks SanctionsOracle before every withdrawal — the hard security invariant.
contract OlympiaExecutor {
    address public immutable treasury;
    address public immutable timelock;
    ISanctionsOracle public immutable sanctionsOracle;

    event TreasuryExecution(address indexed recipient, uint256 amount);

    error OnlyTimelock();
    error SanctionedRecipient(address account);
    error ZeroAddress();

    constructor(address _treasury, address _timelock, address _sanctionsOracle) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_timelock == address(0)) revert ZeroAddress();
        if (_sanctionsOracle == address(0)) revert ZeroAddress();

        treasury = _treasury;
        timelock = _timelock;
        sanctionsOracle = ISanctionsOracle(_sanctionsOracle);
    }

    /// @notice Execute a Treasury withdrawal with sanctions screening
    /// @param recipient Address to receive funds
    /// @param amount Amount in wei to withdraw
    function executeTreasury(address payable recipient, uint256 amount) external {
        if (msg.sender != timelock) revert OnlyTimelock();
        if (sanctionsOracle.isSanctioned(recipient)) revert SanctionedRecipient(recipient);

        ITreasury(treasury).withdraw(recipient, amount);
        emit TreasuryExecution(recipient, amount);
    }
}
