# Olympia Governance Contracts — Copilot Instructions

> **Important:** GitHub Copilot only reads this file and your project code. It does NOT have access to global settings.

## Project

Solidity governance contracts for the Olympia upgrade on Ethereum Classic. Implements OlympiaGovernor, OlympiaExecutor, SanctionsOracle, and ECFPRegistry.

## Tech Stack

- Solidity 0.8.28, Foundry, OpenZeppelin v5.1.0 (Shanghai EVM)
- Target: ETC (PoW chain, chain IDs 61/63)

## Rules

- All contracts use SPDX-License-Identifier: MIT
- Use OpenZeppelin AccessControl for role management
- Use CREATE2 for deterministic deployment addresses
- Tests use Forge Test with vm.prank/vm.deal/vm.expectRevert
- No upgradeable proxies — contracts are immutable
- Use custom errors, not require strings
- NatSpec on all public functions

## Key Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| SanctionsOracle | 1119 | 3-layer sanctions defense |
| OlympiaGovernor | 1113 | Custom `_getVotes`, OIP self-upgrade |
| OlympiaExecutor | 1113 | Sanctions gate + WITHDRAWER_ROLE |
| ECFPRegistry | 1114 | Hash-bound funding proposals |

## Protected Files

- `broadcast/` — on-chain deployment records, never modify
- `.env` — never commit

## Validation

```bash
forge build && forge test -vv
```

## Don't

- Use `tx.origin` for authorization
- Deploy without `--legacy` flag on ETC
- Modify broadcast deployment logs
- Use upgradeable proxies
- Commit .env files or private keys
