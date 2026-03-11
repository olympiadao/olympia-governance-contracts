// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ITreasury
/// @notice Minimal interface for OlympiaTreasury withdrawal calls (ECIP-1112)
interface ITreasury {
    function withdraw(address payable to, uint256 amount) external;
}
