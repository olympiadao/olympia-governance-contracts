# Olympia Governance Contracts — Claude Code Instructions

## Project Context

Production-target governance contracts for Olympia on Ethereum Classic. Implements ECIP-1113 (OlympiaGovernor, OlympiaExecutor, TimelockController), ECIP-1114 (ECFPRegistry with draft lifecycle, review period, input validation), and ECIP-1119 (SanctionsOracle). Built on OpenZeppelin v5.6.0 (Cancun EVM, post-Olympia) with soulbound NFT voting.

> **Production** — Olympia ECIP spec compliant. Post-Olympia EVM (Fusaka via ECIP-1121 + ECIP-1111), OpenZeppelin v5.6.0. Production addresses TBD.

**Repo:** `olympiadao/olympia-governance-contracts`

## Tech Stack

- Solidity 0.8.28
- Foundry (Forge, Cast, Anvil)
- OpenZeppelin Contracts v5.6.0 (Cancun EVM, post-Olympia production target)
- Target chains: Mordor testnet (63), ETC mainnet (61)

## Quick Commands

```bash
forge build          # Compile
forge test -vv       # Run tests (106 tests)
forge fmt            # Format Solidity
forge snapshot       # Gas snapshots
```

## Deploy

```bash
source .env
export SANCTIONS_ORACLE=<address>
export MEMBER_NFT=<address>
# Mordor
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url $MORDOR_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
# ETC mainnet
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url $ETC_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

## Key Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| OlympiaGovernor | 1113 | Governor with 3-layer sanctions defense, OIP self-upgrade |
| OlympiaExecutor | 1113 | Layer 3 sanctions gate between Timelock and Treasury |
| ECFPRegistry | 1114 | Hash-bound funding proposals with draft lifecycle, review period, input validation |
| SanctionsOracle | 1119 | On-chain sanctions list with MANAGER_ROLE |
| OlympiaMemberNFT | 1113 | Soulbound governance NFT (1 NFT = 1 vote) |

## Interfaces

| Interface | Purpose |
|-----------|---------|
| ISanctionsOracle | Sanctions query interface |
| ITreasury | Minimal Treasury withdrawal interface |
| IERC5192 | EIP-5192 soulbound token interface |
| IOlympiaVotingModule | Forward-looking modular voting interface |

## Execution Path

```
ECFPRegistry.submit() → OlympiaGovernor.propose() [Layer 1]
  → vote → [cancelIfSanctioned() Layer 2]
  → queue() → TimelockController
  → execute() → OlympiaExecutor.executeTreasury() [Layer 3]
  → OlympiaTreasury.withdraw()
```

## Deployments

Production addresses TBD — deploy after Olympia activation. OZ 5.6 bytecode produces different CREATE2 addresses than demo v0.2.

## Branch Strategy

- **`main`**: OZ 5.6.0, Cancun EVM — production target (post-Olympia)
- **`demo_v0.2`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true` — live testing (pre-Olympia)
- **`demo_v0.1`**: Archived — initial scaffolding

## Voting Parameters (Mordor)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Voting Delay | 1 block (~13s) | Time before voting starts |
| Voting Period | 100 blocks (~22 min) | Voting window duration |
| Quorum | 10% of NFT supply | Minimum 'For' votes needed |
| Late Quorum Extension | 50 blocks (~11 min) | Extension if quorum reached late |
| Timelock Delay | 3600s (1 hour) | Waiting period before execution |
| Proposal Threshold | 0 | Any NFT holder can propose |
| Min Review Period | 300s (5 min) | ECFP draft review before activation |

## Boundaries

### Always Do
- Run `forge test` before committing
- Use CREATE2 for deterministic addresses
- Emit events for all state changes

### Ask First
- Adding new roles
- Changing the CREATE2 salt
- Any mainnet deployment
- Modifying contract interfaces (affects olympia-app)

### Never Do
- Commit `.env` files or private keys
- Use `tx.origin` for authorization
- Deploy without `--legacy` flag on ETC
- Modify broadcast deployment logs
- Use upgradeable proxies — contracts are immutable

## Validation

Before every commit:

```bash
forge build && forge test -vv
```

Both must pass.
