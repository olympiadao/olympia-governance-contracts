# Olympia Governance Contracts

> **Production** — Olympia ECIP spec compliant. Drafted for future production deployment on Mordor and ETC mainnet. Post-Olympia EVM (Cancun), OpenZeppelin v5.6.0. Governance deploys after Olympia hard fork via CREATE2. Same addresses on Mordor and ETC mainnet.

Production-target governance pipeline contracts for Olympia on Ethereum Classic (ECIP-1113, ECIP-1114, ECIP-1119).

## Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| `OlympiaGovernor` | 1113 | Governor with 3-layer sanctions defense, OIP self-upgrade |
| `OlympiaExecutor` | 1113 | Layer 3 sanctions gate between Timelock and Treasury |
| `ECFPRegistry` | 1114 | Hash-bound funding proposals with GOVERNOR_ROLE status transitions |
| `SanctionsOracle` | 1119 | On-chain sanctions list with MANAGER_ROLE access control |
| `OlympiaMemberNFT` | 1113 | Soulbound governance NFT — one NFT = one vote |

### Interfaces

| Interface | Purpose |
|-----------|---------|
| `ISanctionsOracle` | Sanctions query interface |
| `ITreasury` | Minimal Treasury withdrawal interface |
| `IERC5192` | EIP-5192 soulbound token interface |
| `IOlympiaVotingModule` | Forward-looking modular voting interface |

## Architecture

```
ECFPRegistry.submit() → hash-bound proposal record (application layer)
        ↓
OlympiaGovernor.propose() → Layer 1: sanctions check on recipient
        ↓
Voting (snapshot block) → GovernorVotes reads OlympiaMemberNFT.getPastVotes()
        ↓
[Optional] cancelIfSanctioned() → Layer 2: permissionless cancel
        ↓
OlympiaGovernor.queue() → TimelockController.scheduleBatch()
        ↓
Wait minDelay (1 hour Mordor / 1 day production)
        ↓
OlympiaGovernor.execute() → TimelockController.executeBatch()
        ↓
OlympiaExecutor.executeTreasury() → Layer 3: final sanctions gate
        ↓
OlympiaTreasury.withdraw(recipient, amount)
```

### 3-Layer Sanctions Defense (ECIP-1119)

| Layer | Location | Trigger |
|-------|----------|---------|
| 1 | `OlympiaGovernor.propose()` | Reverts if target or calldata recipient is sanctioned |
| 2 | `OlympiaGovernor.cancelIfSanctioned()` | Permissionless cancel if recipient becomes sanctioned mid-vote |
| 3 | `OlympiaExecutor.executeTreasury()` | Final gate before treasury withdrawal |

## Tech Stack

| Component | Version |
|-----------|---------|
| Solidity | 0.8.28 |
| OpenZeppelin | v5.6.0 |
| Foundry | Latest |
| Target chains | Mordor (63), ETC mainnet (61) |

## Quick Commands

```bash
forge build          # Compile
forge test -vv       # Run tests (87 tests)
forge fmt            # Format Solidity
```

## Deploy

```bash
source .env
# Set Phase 2A contract addresses
export SANCTIONS_ORACLE=<address>
export MEMBER_NFT=<address>

# Mordor
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url $MORDOR_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy

# ETC mainnet
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url $ETC_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

## Tests

| Test Suite | Count | Coverage |
|------------|-------|----------|
| SanctionsOracle | 14 | Add/remove, isSanctioned, access control, edge cases |
| OlympiaMemberNFT | 19 | Mint, auto-delegate, soulbound, ERC5192, getPastVotes |
| OlympiaExecutor | 9 | Constructor, executeTreasury, access control, sanctions |
| OlympiaGovernor | 21 | Propose, vote, queue, execute, cancelIfSanctioned, quorum |
| ECFPRegistry | 19 | Submit, status transitions, access control, chainId isolation |
| GovernancePipeline | 5 | End-to-end: all 3 sanctions layers, self-upgrade |

**Total: 87 tests**

## Related

- [OlympiaTreasury](https://github.com/olympiadao/olympia-treasury-contract) — Treasury vault (ECIP-1112), deployed at `0xd6165F3aF4281037bce810621F62B43077Fb0e37`
- [Olympia Framework](https://github.com/olympiadao/olympia-framework) — Full specification library (11 ECIPs)
- [Olympia App](https://github.com/olympiadao/olympia-app) — Governance dApp (Next.js 16 + wagmi)

## License

MIT
