# Olympia Governance Contracts

> **Production** — Olympia ECIP spec compliant. Post-Olympia EVM (Fusaka via ECIP-1121 + ECIP-1111), OpenZeppelin v5.6.0. Prepared for future production deployment on Mordor and ETC mainnet. Governance deploys after Olympia hard fork via CREATE2. Production addresses TBD.

Governance pipeline contracts for Olympia on Ethereum Classic (ECIP-1113, ECIP-1114, ECIP-1119). Production target uses **OpenZeppelin v5.6.0** with soulbound NFT voting, requiring Cancun opcodes enabled by the Olympia fork.

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
| OpenZeppelin | v5.6.0 (Cancun EVM, post-Olympia) |
| Foundry | Latest |
| EVM Version | Cancun (requires Olympia fork) |
| Target chains | Mordor (63), ETC mainnet (61) |

## OZ 5.6 Requirement

Production uses OZ 5.6.0 which requires Cancun opcodes (`mcopy`/EIP-5656) enabled by the Olympia hard fork (ECIP-1121). Demo v0.2 used OZ 5.1.0 (Shanghai-compatible). Different bytecode produces different CREATE2 addresses — all production addresses are TBD until deployment.

## Deployments

### Production (Post-Olympia, OZ 5.6) — TBD

Production contracts deploy after Olympia activation (Mordor block TBD; ETC mainnet block TBD). All addresses will differ from demo v0.2 due to OZ 5.6 bytecode changes and fresh deployer EOA. Addresses recomputed by `PrecomputeAddresses.s.sol`.

### Demo v0.2 (Pre-Olympia, OZ 5.1 Governance) — Deployed

All governance contracts deployed via **CREATE2** (deterministic deployer factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`). Treasury deployed via **CREATE** (nonce-based) from the [treasury repo](https://github.com/olympiadao/olympia-treasury-contract). All source code verified on Blockscout.

Deployer: `0x7C3311F29e318617fed0833E68D6522948AaE995` (fresh EOA, nonce 0)
Salt: `keccak256("OLYMPIA_DEMO_V0_2")`

| Contract | Address (identical on Mordor + ETC mainnet) |
|----------|---------------------------------------------|
| OlympiaTreasury | [`0x035b2e3c189B772e52F4C3DA6c45c84A3bB871bf`](https://etc.blockscout.com/address/0x035b2e3c189b772e52f4c3da6c45c84a3bb871bf) |
| SanctionsOracle | [`0xfF2B8D7937D908D81C72D20AC99302EE6ACc2709`](https://etc.blockscout.com/address/0xff2b8d7937d908d81c72d20ac99302ee6acc2709) |
| OlympiaMemberNFT | [`0x73e78d3a3470396325b975FcAFA8105A89A9E672`](https://etc.blockscout.com/address/0x73e78d3a3470396325b975fcafa8105a89a9e672) |
| TimelockController | [`0xA5839b3e9445f7eE7AffdBC796DC0601f9b976C2`](https://etc.blockscout.com/address/0xa5839b3e9445f7ee7affdbc796dc0601f9b976c2) |
| OlympiaGovernor | [`0xB85dbc899472756470EF4033b9637ff8fa2FD23D`](https://etc.blockscout.com/address/0xb85dbc899472756470ef4033b9637ff8fa2fd23d) |
| OlympiaExecutor | [`0x64624f74F77639CbA268a6c8bEDC2778B707eF9a`](https://etc.blockscout.com/address/0x64624f74f77639cba268a6c8bedc2778b707ef9a) |
| ECFPRegistry | [`0xFB4De5674a6b9a301d16876795a74f3bdacfa722`](https://etc.blockscout.com/address/0xfb4de5674a6b9a301d16876795a74f3bdacfa722) |

**Deployment order:**
1. Deploy Treasury (CREATE, nonce 0) — executor address pre-computed but has no code yet
2. Deploy Foundation (CREATE2) — SanctionsOracle, OlympiaMemberNFT
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

- **`main`**: OZ 5.6.0, Cancun EVM — production target (post-Olympia, Fusaka via ECIP-1121 + ECIP-1111)
- **`demo_v0.2`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true` — live testing on Mordor + ETC (pre-Olympia)
- **`demo_v0.1`**: Archived — initial scaffolding, not spec compliant

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
