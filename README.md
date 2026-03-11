# Olympia Governance Contracts

Foundation contracts for the Olympia Demo v0.1 governance pipeline on Ethereum Classic (ECIP-1113, ECIP-1119).

## Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| `SanctionsOracle` | 1119 | On-chain sanctions list with MANAGER_ROLE access control |
| `OlympiaMemberNFT` | 1113 | Soulbound governance NFT — one NFT = one vote |
| `ISanctionsOracle` | 1119 | Interface for sanctions queries |
| `IERC5192` | — | EIP-5192 soulbound token interface (not in OZ v5.6) |
| `IOlympiaVotingModule` | 1113 | Forward-looking modular voting interface |

## Architecture

```
OlympiaMemberNFT (soulbound ERC721 + ERC721Votes)
  │
  ├── MINTER_ROLE gates issuance (KYC/identity verification)
  ├── Auto-delegates on mint (votes active immediately)
  ├── Non-transferable (_update blocks transfers)
  └── ERC5192 locked() always returns true

SanctionsOracle (AccessControl)
  │
  ├── MANAGER_ROLE can add/remove sanctioned addresses
  └── Used by OlympiaGovernor for 3-layer sanctions defense
```

Demo v0.1 uses standard OZ `GovernorVotes` reading directly from the soulbound `OlympiaMemberNFT`. The `IOlympiaVotingModule` interface is a spec artifact for future governance-gated module swaps.

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
forge test -vv       # Run tests (33 tests)
forge fmt            # Format Solidity
```

## Tests

- **SanctionsOracle:** 14 tests — add/remove, isSanctioned, access control, edge cases
- **OlympiaMemberNFT:** 19 tests — mint, auto-delegate, soulbound enforcement, ERC5192, getPastVotes, enumeration, supportsInterface

## Related

- [OlympiaTreasury](https://github.com/olympiadao/olympia-treasury-contract) — Treasury vault (ECIP-1112), deployed at `0xd6165F3aF4281037bce810621F62B43077Fb0e37`
- [Olympia Framework](https://github.com/olympiadao/olympia-framework) — Full specification library (11 ECIPs)
- [Development Roadmap](https://github.com/olympiadao/ROADMAP.md) — Phase 2A-2E build plan

## License

MIT
