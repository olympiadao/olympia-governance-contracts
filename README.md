# Olympia Governance Contracts

> **Demo v0.3** — 9 contracts deployed on Mordor + ETC mainnet. On-chain SVG art, sybil resistance, deterministic CREATE2 (salt: `OLYMPIA_DEMO_V0_3`). Pre-Olympia EVM (Shanghai), OpenZeppelin v5.1.0. Not production.

Governance pipeline contracts for Olympia Demo v0.3 on Ethereum Classic (ECIP-1113, ECIP-1114, ECIP-1119). Built on **OpenZeppelin v5.1.0** with soulbound NFT voting, on-chain SVG renderer, and merkle/attestation membership verification. Deployable on Shanghai EVM (pre-Olympia).

## Contracts

| Contract | ECIP | Purpose |
|----------|------|---------|
| `OlympiaGovernor` | 1113 | Governor with 3-layer sanctions defense, OIP self-upgrade |
| `OlympiaExecutor` | 1113 | Layer 3 sanctions gate between Timelock and Treasury |
| `ECFPRegistry` | 1114 | Hash-bound funding proposals with draft lifecycle, review period, input validation |
| `SanctionsOracle` | 1119 | On-chain sanctions list with MANAGER_ROLE access control |
| `OlympiaMemberNFT` | 1113 | Soulbound governance NFT — one NFT = one vote |

### Interfaces

| Interface | Purpose |
|-----------|---------|
| `ISanctionsOracle` | Sanctions query interface |
| `ITreasury` | Minimal Treasury withdrawal interface (`withdraw(address payable, uint256)`) |
| `IERC5192` | EIP-5192 soulbound token interface |
| `IOlympiaVotingModule` | Forward-looking modular voting interface |

## Architecture

```
ECFPRegistry.submit() → hash-bound proposal record (permissionless — any ETC address)
        ↓
[minReviewPeriod wait]
        ↓
ECFPRegistry.activateProposal() → Draft → Active (GOVERNOR_ROLE)
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

### ECFPRegistry (ECIP-1114)

- Permissionless submission — any ETC address can submit proposals (no NFT required)
- Draft amendment (`updateDraft()`) and withdrawal (`withdrawDraft()`) — submitter-only, Draft state only
- Minimum review period — `minReviewPeriod` (300s Mordor) enforced before `activateProposal()`
- Input validation — reverts on zero recipient, zero amount, empty metadataCID, empty ecfpId
- `ProposalExecuted` event includes `uint256 indexed ecfpId` for indexer correlation

## Tech Stack

| Component | Version |
|-----------|---------|
| Solidity | 0.8.28 |
| OpenZeppelin | v5.1.0 |
| Foundry | Latest |
| EVM Version | Shanghai |
| Target chains | Mordor (63), ETC mainnet (61) |

## OZ 5.1 Constraint

OZ 5.1.0 is required because Mordor and ETC mainnet only support Shanghai EVM until the Olympia hard fork activates. OZ 5.2+ uses `mcopy` (EIP-5656, Cancun-only).

Production deployment will use OZ 5.6 after Olympia activates Cancun. Different bytecode produces different CREATE2 addresses, requiring a separate Treasury deployment.

## Deployments

### Demo v0.3 (Pre-Olympia, OZ 5.1 Governance) — Deployed

All governance contracts deployed via **CREATE2** (deterministic deployer factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`). Treasury deployed via **CREATE** (nonce 0) from the [treasury repo](https://github.com/olympiadao/olympia-treasury-contract). All source code verified on Blockscout.

Deployer: `0xAF21767a2c5b3acFFB64dC64CD5A876e91155bD0` (fresh EOA, nonce 0)
Salt: `keccak256("OLYMPIA_DEMO_V0_3")`

| Contract | Address (identical on Mordor + ETC mainnet) |
|----------|---------------------------------------------|
| OlympiaTreasury | [`0x60d0A7394f9Cd5C469f9F5Ec4F9C803F5294d79b`](https://etc.blockscout.com/address/0x60d0a7394f9cd5c469f9f5ec4f9c803f5294d79b) |
| SanctionsOracle | [`0xAA93C0d1cCf9a0Ec43A2EE8CD1AfFC473b82f36A`](https://etc.blockscout.com/address/0xaa93c0d1ccf9a0ec43a2ee8cd1affc473b82f36a) |
| OlympiaMemberNFT | [`0xb4D45A498994C89553A9c923c6b85F7623C0843e`](https://etc.blockscout.com/address/0xb4d45a498994c89553a9c923c6b85f7623c0843e) |
| OlympiaMemberRenderer | [`0xE29d0f47043F40059AB5DE7C8F7E7B665a7caCCf`](https://etc.blockscout.com/address/0xe29d0f47043f40059ab5de7c8f7e7b665a7caccf) |
| MembershipVerifier | [`0xb6274251Fb8F1D865A0B62bba9fF31c1bfEdccE6`](https://etc.blockscout.com/address/0xb6274251fb8f1d865a0b62bba9ff31c1bfedcce6) |
| TimelockController | [`0x3d19fEfB093Abad60421B89CF48f4569aaae39b6`](https://etc.blockscout.com/address/0x3d19fefb093abad60421b89cf48f4569aaae39b6) |
| OlympiaGovernor | [`0xe763f13cC89292C4F279BEF2aD54F1E89A3a87d3`](https://etc.blockscout.com/address/0xe763f13cc89292c4f279bef2ad54f1e89a3a87d3) |
| OlympiaExecutor | [`0x292eBe07d11850Dfc94Cbf9c72C3A054d23cAB54`](https://etc.blockscout.com/address/0x292ebe07d11850dfc94cbf9c72c3a054d23cab54) |
| ECFPRegistry | [`0xe2b437284B0fc7A1064Afd1f60686c7cEAa7343a`](https://etc.blockscout.com/address/0xe2b437284b0fc7a1064afd1f60686c7ceaa7343a) |

**Deployment order:**
1. Deploy Treasury (CREATE, nonce 0) — executor address pre-computed but has no code yet
2. Deploy Foundation (CREATE2) — SanctionsOracle, OlympiaMemberNFT, OlympiaMemberRenderer, MembershipVerifier
3. Deploy Governance (CREATE2) — Timelock, Governor, Executor, ECFPRegistry
4. Verify: `treasury.executor() == OlympiaExecutor address`

## Quick Commands

```bash
forge build          # Compile
forge test -vv       # Run tests (106 tests)
forge fmt            # Format Solidity
```

## Deploy

```bash
source .env
export SANCTIONS_ORACLE=<address>
export MEMBER_NFT=<address>

# Mordor
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url $MORDOR_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

## Tests

| Test Suite | Count | Coverage |
|------------|-------|----------|
| SanctionsOracle | 14 | Add/remove, isSanctioned, access control, edge cases |
| OlympiaMemberNFT | 19 | Mint, auto-delegate, soulbound, ERC5192, getPastVotes |
| OlympiaExecutor | 9 | Constructor, executeTreasury, access control, sanctions |
| OlympiaGovernor | 21 | Propose, vote, queue, execute, cancelIfSanctioned, quorum |
| ECFPRegistry | 38 | Submit, input validation, draft lifecycle, review period, status transitions, permissionless access |
| GovernancePipeline | 5 | End-to-end: all 3 sanctions layers, self-upgrade |

**Total: 106 tests**

Mordor on-chain test results: [MORDOR_TEST_REPORT.md](MORDOR_TEST_REPORT.md)

## Branch Strategy

- **`main`**: OZ 5.6.0, Cancun defaults — for post-Olympia production deployments
- **`demo_v0.3`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true`, CREATE2 salt `OLYMPIA_DEMO_V0_3` — 9 contracts, on-chain SVG, sybil resistance
- **`demo_v0.2`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true`, CREATE2 salt `OLYMPIA_DEMO_V0_2` — 7 contracts
- **`pre-olympia`** / **`demo_v0.1`**: OZ 5.1.0, deployed to Mordor (predecessor governance set)

## Voting Parameters (Mordor)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Voting Delay | 1 block (~13s) | Time before voting starts |
| Voting Period | 100 blocks (~22 min) | Voting window duration |
| Quorum | 10% of NFT supply | Minimum 'For' votes needed |
| Late Quorum Extension | 50 blocks (~11 min) | Extension if quorum reached late |
| Timelock Delay | 3600s (1 hour) | Waiting period before execution |
| Proposal Threshold | 0 | Any NFT holder can propose via Governor |
| Min Review Period | 300s (5 min) | ECFP draft review before activation |

## Related

- [Olympia Treasury Contract](https://github.com/olympiadao/olympia-treasury-contract) — Treasury vault (ECIP-1112), pure Solidity, immutable executor
- [Olympia Framework](https://github.com/olympiadao/olympia-framework) — Full specification library (11 ECIPs)
- [Olympia App](https://github.com/olympiadao/olympia-app) — Governance dApp (Next.js 16 + wagmi)
- [OlympiaTreasury.org](https://github.com/olympiadao/olympiatreasury-org) — Treasury monitoring dashboard
- [OlympiaDAO.org](https://github.com/olympiadao/olympiadao-org) — Landing page
- [EthereumClassicDAO.org](https://github.com/EthereumClassicDAO/ethereumclassicdao-org) — Institutional website
- [Olympia Brand](https://github.com/olympiadao/olympia-brand) — Design tokens, logos, favicons

## License

MIT
