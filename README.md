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
- **Minimum review period** — `minReviewPeriod` (1 day Mordor) enforced before `activateProposal()`
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
- Security patches: 5 years of audits and fixes between 5.1 and 5.6
- Cancun opcodes: transient storage (EIP-1153), SELFDESTRUCT restriction (EIP-6780)

**Production deployment** will use OZ 5.6 after Olympia activates Cancun. Different bytecode → different CREATE2 addresses → separate Treasury deployment.

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
- **`demo_v0.1`** / **`pre-olympia`**: OZ 5.1.0, deployed to Mordor (demo v0.1 governance suite)
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
| Min Review Period | 86400s (1 day) | ECFP draft review before activation |

## Related

- [OlympiaTreasury](https://github.com/olympiadao/olympia-treasury-contract) — Treasury vault (ECIP-1112), pure Solidity, immutable executor
- [Olympia Framework](https://github.com/olympiadao/olympia-framework) — Full specification library (11 ECIPs)
- [Olympia App](https://github.com/olympiadao/olympia-app) — Governance dApp (Next.js 16 + wagmi)

## License

MIT
