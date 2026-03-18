# Olympia Governance Contracts

Governance pipeline contracts for Olympia Demo v0.2 on Ethereum Classic (ECIP-1113, ECIP-1114, ECIP-1119). Built on **OpenZeppelin v5.1.0** with soulbound NFT voting, deployable on Shanghai EVM (pre-Olympia).

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

### ECFPRegistry ECIP-1114 Compliance

Demo v0.2 adds full ECIP-1114 compliance:

- **Permissionless submission** — any ETC address can submit proposals (no NFT required). NFTs only gate voting.
- **Draft amendment & withdrawal** — `updateDraft()` and `withdrawDraft()` for submitter-only draft management
- **Minimum review period** — `minReviewPeriod` (5 min Mordor) enforced before `activateProposal()`
- **Input validation** — reverts on zero recipient, zero amount, empty metadataCID, empty ecfpId
- **ecfpId in ProposalExecuted** — `uint256 indexed ecfpId` added for indexer correlation

## Tech Stack

| Component | Version |
|-----------|---------|
| Solidity | 0.8.28 |
| OpenZeppelin | v5.1.0 |
| Foundry | Latest |
| EVM Version | Shanghai |
| Target chains | Mordor (63), ETC mainnet (61) |

## OZ 5.1 → 5.6 Upgrade Path

Demo v0.2 uses **OZ 5.1** because Mordor and ETC mainnet only support **Shanghai** until the Olympia hard fork activates (block 15,800,850). OZ 5.2+ uses `mcopy` (EIP-5656, Cancun-only).

**What OZ 5.6 brings:**
- `mcopy` opcode (EIP-5656): faster memory operations, lower gas for ABI encoding/decoding
- GovernorStorage extension: on-chain proposal description storage
- Improved TimelockController: batch operation safety, better event emissions
- Security patches: 18 months of audits and fixes between 5.1 and 5.6
- Cancun opcodes: transient storage (EIP-1153), SELFDESTRUCT restriction (EIP-6780)

**Production deployment** will use OZ 5.6 after Olympia activates Cancun. Different bytecode → different CREATE2 addresses → separate Treasury deployment.

## Deployments

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

### Demo v0.1 (Mordor + ETC mainnet)

Preserved on the `demo_v0.1` branch. Mixed OZ versions: Governor OZ 5.1 (Shanghai), other contracts OZ 5.6. See [DEPLOYMENT.md](DEPLOYMENT.md) for full address matrix.

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

## Branch Strategy

- **`demo_v0.2`**: OZ 5.1.0, `evm_version=shanghai`, `via_ir=true`, CREATE2 salt `OLYMPIA_DEMO_V0_2`
- **`demo_v0.1`**: OZ 5.1.0, deployed to Mordor + ETC mainnet (demo v0.1 governance suite)
- **`main`**: OZ 5.6.0, Cancun defaults — for post-Olympia production deployments

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

- [OlympiaTreasury](https://github.com/olympiadao/olympia-treasury-contract) — Treasury vault (ECIP-1112), pure Solidity, immutable executor
- [Olympia Framework](https://github.com/olympiadao/olympia-framework) — Full specification library (11 ECIPs)
- [Olympia App](https://github.com/olympiadao/olympia-app) — Governance dApp (Next.js 16 + wagmi)

## License

MIT
