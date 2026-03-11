# Olympia Governance Contracts — Claude Code Instructions

## Project Context

Solidity governance contracts for the Olympia Demo v0.1 on Ethereum Classic. Implements ECIP-1113 (OlympiaGovernor, OlympiaExecutor, TimelockController), ECIP-1114 (ECFPRegistry), and ECIP-1119 (SanctionsOracle). Built on OpenZeppelin v5.6 with custom voting module interface.

**Repo:** `olympiadao/olympia-governance-contracts`

## Tech Stack

- Solidity 0.8.28
- Foundry (Forge, Cast, Anvil)
- OpenZeppelin Contracts v5.6.0
- Target chains: Mordor testnet (63), ETC mainnet (61)

## Quick Commands

```bash
forge build          # Compile
forge test -vv       # Run tests
forge fmt            # Format Solidity
forge snapshot       # Gas snapshots
```

## Deploy

```bash
source .env
# Mordor
forge script script/Deploy.s.sol:DeployScript --rpc-url $MORDOR_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
# ETC mainnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETC_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

## Key Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| SanctionsOracle | 1119 | 3-layer sanctions defense |
| IOlympiaVotingModule | 1113 | Custom voting module interface |
| NFTVotingModuleAdapter | 1113 | Wraps OlympiaMemberNFT |
| OlympiaExecutor | 1113 | Sanctions gate + WITHDRAWER_ROLE |
| OlympiaGovernor | 1113 | Custom `_getVotes`, OIP self-upgrade |
| ECFPRegistry | 1114 | Hash-bound funding proposals |

## Related Deployments

- Treasury: `0xd6165F3aF4281037bce810621F62B43077Fb0e37` (Mordor + ETC mainnet)
- Governance contracts: TBD (Demo v0.1, OLYMPIA_DEMO_V0_1 salt)

## Boundaries

### Always Do
- Run `forge test` before committing
- Use CREATE2 for deterministic addresses
- Use AccessControlDefaultAdminRules for role management
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
