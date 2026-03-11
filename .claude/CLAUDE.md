# Olympia Governance Contracts — Claude Code Instructions

## Project Context

Solidity governance contracts for the Olympia Demo v0.1 on Ethereum Classic. Implements ECIP-1113 (OlympiaGovernor, OlympiaExecutor, TimelockController), ECIP-1114 (ECFPRegistry), and ECIP-1119 (SanctionsOracle). Built on OpenZeppelin v5.6 with soulbound NFT voting.

**Repo:** `olympiadao/olympia-governance-contracts`

## Tech Stack

- Solidity 0.8.28
- Foundry (Forge, Cast, Anvil)
- OpenZeppelin Contracts v5.6.0
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

## Deployed Addresses (Mordor, Chain 63)

All deployed with CREATE2 salt `OLYMPIA_DEMO_V0_1` for deterministic addresses.

| Contract | Address |
|----------|---------|
| OlympiaGovernor | `0xEdbD61F1cE825CF939beBB422F8C914a69826dDA` |
| OlympiaExecutor | `0x94d4f74dDdE715Ed195B597A3434713690B14e97` |
| TimelockController | `0x1E0fADee5540a77012f1944fcce58677fC087f6e` |
| ECFPRegistry | `0xcB532fe70299D53Cc81B5F6365f56A108784d05d` |
| SanctionsOracle | `0xEeeb33c8b7C936bD8e72A859a3e1F9cc8A26f3B4` |
| OlympiaMemberNFT | `0x720676EBfe45DECfC43c8E9870C64413a2480EE0` |
| OlympiaTreasury | `0xd6165F3aF4281037bce810621F62B43077Fb0e37` |

## Branch Strategy

- **`pre-olympia`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true` — deployed to Mordor (pre-Olympia EVM)
- **`main`**: OZ 5.6.0, Cancun defaults — for post-Olympia deployments

## Voting Parameters (Mordor)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Voting Delay | 1 block (~13s) | Time before voting starts |
| Voting Period | 100 blocks (~22 min) | Voting window duration |
| Quorum | 10% of NFT supply | Minimum 'For' votes needed |
| Late Quorum Extension | 50 blocks (~11 min) | Extension if quorum reached late |
| Timelock Delay | 3600s (1 hour) | Waiting period before execution |
| Proposal Threshold | 0 | Any NFT holder can propose |

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
