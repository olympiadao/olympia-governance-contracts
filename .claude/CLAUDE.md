# Olympia Governance Contracts — Claude Code Instructions

## Project Context

Production-target governance contracts for Olympia on Ethereum Classic. Implements ECIP-1113 (OlympiaGovernor, OlympiaExecutor, TimelockController), ECIP-1114 (ECFPRegistry), and ECIP-1119 (SanctionsOracle). Built on OpenZeppelin v5.6.0 (Cancun EVM, post-Olympia) with soulbound NFT voting. API migration from OZ 5.1 → 5.6 happens at production deployment time.

> **Production** — Olympia ECIP spec compliant. Drafted for future production deployment on Mordor and ETC mainnet. Post-Olympia EVM (Cancun), OpenZeppelin v5.6.0. Governance deploys after Olympia hard fork via CREATE2. Same addresses on Mordor and ETC mainnet.

**Repo:** `olympiadao/olympia-governance-contracts`

## Tech Stack

- Solidity 0.8.28
- Foundry (Forge, Cast, Anvil)
- OpenZeppelin Contracts v5.6.0 (Cancun EVM, production target)
- Target chains: Mordor testnet (63), ETC mainnet (61)

## Quick Commands

```bash
forge build          # Compile
forge test -vv       # Run tests (87 tests)
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
| ECFPRegistry | 1114 | Hash-bound funding proposals with GOVERNOR_ROLE |
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

## Related Deployments

- Treasury: TBD (production deployer, nonce 0, CREATE address differs from demo)
- Governance contracts: TBD (production CREATE2 addresses differ from demo — OZ 5.6 bytecode)

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
