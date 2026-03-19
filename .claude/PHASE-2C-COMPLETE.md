# Phase 2C — Mordor Deployment & App Scaffold: COMPLETE

**Completed:** 2026-03-11
**Branch:** `pre-olympia` (OZ 5.1.0, evm_version=shanghai, via_ir=true)
**Salt:** `OLYMPIA_DEMO_V0_1` (CREATE2 deterministic addresses)

---

## What Was Deployed

All 7 governance contracts deployed to Mordor testnet (Chain 63) from the `pre-olympia` branch.

| Contract | Address | ECIP |
|----------|---------|------|
| SanctionsOracle | `0xEeeb33c8b7C936bD8e72A859a3e1F9cc8A26f3B4` | 1119 |
| OlympiaMemberNFT | `0x720676EBfe45DECfC43c8E9870C64413a2480EE0` | 1113 |
| OlympiaGovernor | `0xEdbD61F1cE825CF939beBB422F8C914a69826dDA` | 1113 |
| OlympiaExecutor | `0x94d4f74dDdE715Ed195B597A3434713690B14e97` | 1113 |
| TimelockController | `0x1E0fADee5540a77012f1944fcce58677fC087f6e` | 1113 |
| ECFPRegistry | `0xcB532fe70299D53Cc81B5F6365f56A108784d05d` | 1114 |
| OlympiaTreasury | `0xd6165F3aF4281037bce810621F62B43077Fb0e37` | 1112 |

---

## Branch Strategy

Two-track branch strategy required due to EVM version mismatch:

- **`pre-olympia`**: Pins OZ 5.1.0 with `evm_version = "shanghai"` and `via_ir = true`. Required because Solidity 0.8.28 defaults to Cancun, but ETC Mordor runs Shanghai (Spiral). OZ 5.2+ introduced `mcopy` (EIP-5656) which isn't available pre-Olympia.

- **`main`**: OZ 5.6.0 with Cancun defaults. For post-Olympia deployments when ETC activates Olympia hard fork (EIP-5656 and other Cancun opcodes become available).

**Migration path:** After Olympia activates on ETC, redeploy from `main` branch with OZ 5.6 and Cancun EVM target.

---

## Deploy Process

### Phase 2A: Foundation Contracts

Deployed via `script/DeployFoundation.s.sol`:

1. Deploy SanctionsOracle with CREATE2 (`OLYMPIA_DEMO_V0_1` salt)
2. Deploy OlympiaMemberNFT with CREATE2
3. Mint first NFT to deployer wallet (`0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537`)

### Phase 2B: Governor Pipeline

Deployed via `script/DeployGovernance.s.sol`:

1. Deploy TimelockController (empty proposers/executors, admin = deployer)
2. Deploy OlympiaGovernor (with timelock, NFT, oracle)
3. Grant timelock roles to Governor (PROPOSER, EXECUTOR, CANCELLER)
4. Deploy OlympiaExecutor (with treasury, timelock, oracle)
5. Deploy ECFPRegistry (admin = deployer)

### Post-Deploy Role Setup

- `WITHDRAWER_ROLE` on Treasury granted to OlympiaExecutor
- `GOVERNOR_ROLE` on ECFPRegistry granted to TimelockController
- `PROPOSER_ROLE`, `EXECUTOR_ROLE`, `CANCELLER_ROLE` on Timelock granted to Governor

All deploy commands used `--legacy` flag (required until EIP-1559 activates on ETC).

---

## Voting Parameters (Mordor)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Voting Delay | 1 block (~13s) | Time between proposal creation and voting start |
| Voting Period | 100 blocks (~22 min) | Duration of the voting window |
| Quorum | 10% of NFT supply | Minimum 'For' votes needed for proposal to pass |
| Late Quorum Extension | 50 blocks (~11 min) | If quorum reached late, voting extends |
| Timelock Delay | 3600s (1 hour) | Mandatory waiting period before execution |
| Proposal Threshold | 0 | Any NFT holder can create a proposal |

---

## Post-Deploy Verification

- Governor responds to `cast call` for votingDelay, votingPeriod, quorum
- NFT balance confirmed for deployer wallet (tokenId 0)
- Treasury balance confirmed (mining rewards accumulating)
- Role grants verified via `hasRole` calls on all contracts
- App connects to contracts and reads on-chain state

---

## Olympia App (olympia-app)

Full governance UI built with Next.js 16 + wagmi 2 + viem + Tailwind 4.

**Commit:** `9ef39b8` (pushed to `olympiadao/olympia-app`)

**Features:**
- Dashboard: stats, governance guide, recent proposals
- Proposals: list with lifecycle guide, detail with Vote/Queue/Execute buttons, state guidance
- New Proposal: form with treasury action, instructional content, sanctions note
- Members: NFT holder enumeration via Transfer events, voting power explanation
- Treasury: balance, contract addresses, withdrawal explanation
- Admin: mint NFTs, manage sanctions list, view roles with access control
- Demo Config: governance parameters, contract addresses, E2E testing checklist, timing reference

**ABIs:** Extracted from `forge build` output and placed in `src/lib/contracts/abis/`.

---

## EVM Version Issue — Root Cause

**Problem:** Solidity 0.8.28 defaults to Cancun EVM target. ETC Mordor (and ETC mainnet until Olympia) runs Shanghai (Spiral). OpenZeppelin 5.2+ uses `mcopy` opcode (EIP-5656) which is a Cancun-only instruction.

**Symptoms:** Contracts compile but fail at runtime with `INVALID_OPCODE` because `mcopy` doesn't exist on Shanghai EVM.

**Resolution:** Created `pre-olympia` branch that:
1. Pins OpenZeppelin to v5.1.0 (last version without `mcopy`)
2. Sets `evm_version = "shanghai"` in `foundry.toml`
3. Enables `via_ir = true` (required by OZ 5.1 with Shanghai target)

---

## Key Lessons Learned

1. **EVM version pinning is critical on ETC** — Always check the target chain's EVM version. ETC lags behind ETH by design (hard forks require community consensus). Set `evm_version` explicitly in `foundry.toml`.

2. **`--legacy` flag required** — ETC doesn't support EIP-1559 transaction types yet. All `forge script` and `cast send` commands need `--legacy`.

3. **CREATE2 salt determinism** — Same salt + same bytecode + same deployer = same address across any EVM chain. `OLYMPIA_DEMO_V0_1` produces identical addresses on Mordor and ETC mainnet.

4. **OZ version compatibility matrix** — OZ 5.1 is the last version safe for Shanghai. OZ 5.2-5.6 require Cancun. This will resolve after Olympia hard fork activates.

5. **`via_ir = true` compilation** — IR-based compilation is slower but required for some OZ 5.1 + Shanghai combinations. Build times ~2x longer but functionally equivalent.
