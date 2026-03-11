# Olympia Demo v0.1 — Mordor Deployment Matrix

**Chain:** Mordor Testnet (chainId 63)
**Branch:** `pre-olympia` (OZ 5.1.0, evm_version=shanghai, via_ir=true)
**Deployer:** `0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537`
**CREATE2 Salt:** `keccak256("OLYMPIA_DEMO_V0_1")`
**Date:** 2026-03-11

---

## Contract Addresses

| Contract | Address | Deploy Method | Script |
|----------|---------|---------------|--------|
| SanctionsOracle | `0xEeeb33c8b7C936bD8e72A859a3e1F9cc8A26f3B4` | CREATE2 | DeployFoundation.s.sol |
| OlympiaMemberNFT | `0x720676EBfe45DECfC43c8E9870C64413a2480EE0` | CREATE2 | DeployFoundation.s.sol |
| TimelockController | `0x1E0fADee5540a77012f1944fcce58677fC087f6e` | CREATE2 | DeployGovernance.s.sol |
| OlympiaGovernor | `0xEdbD61F1cE825CF939beBB422F8C914a69826dDA` | CREATE2 | RepairGovernor.s.sol |
| OlympiaExecutor | `0x94d4f74dDdE715Ed195B597A3434713690B14e97` | CREATE2 | DeployGovernance.s.sol |
| ECFPRegistry | `0xcB532fe70299D53Cc81B5F6365f56A108784d05d` | CREATE2 | DeployGovernance.s.sol |
| OlympiaTreasury | `0xd6165F3aF4281037bce810621F62B43077Fb0e37` | CREATE2 | (separate repo) |

---

## Role / Permission Matrix

### SanctionsOracle (`0xEeeb...3B4`)

| Role | Holder | Purpose |
|------|--------|---------|
| DEFAULT_ADMIN_ROLE | Deployer (`0x3b09...537`) | Can grant/revoke MANAGER_ROLE |
| MANAGER_ROLE | Deployer (`0x3b09...537`) | Can add/remove sanctioned addresses |

### OlympiaMemberNFT (`0x7206...EE0`)

| Role | Holder | Purpose |
|------|--------|---------|
| DEFAULT_ADMIN_ROLE | Deployer (`0x3b09...537`) | Can grant/revoke MINTER_ROLE |
| MINTER_ROLE | Deployer (`0x3b09...537`) | Can mint membership NFTs |

### TimelockController (`0x1E0f...6e`)

| Role | Holder | Purpose |
|------|--------|---------|
| DEFAULT_ADMIN_ROLE | TimelockController (self) | Self-administered |
| PROPOSER_ROLE | OlympiaGovernor (`0xEdbD...dDA`) | Can schedule operations |
| EXECUTOR_ROLE | OlympiaGovernor (`0xEdbD...dDA`) | Can execute operations |
| CANCELLER_ROLE | OlympiaGovernor (`0xEdbD...dDA`) | Can cancel operations |

### OlympiaGovernor (`0xEdbD...dDA`)

| Setting | Value | Notes |
|---------|-------|-------|
| Voting Delay | 1 block | ~15s on Mordor |
| Voting Period | 100 blocks | ~25 min on Mordor |
| Quorum | 10% of total NFT supply | |
| Late Quorum Extension | 50 blocks | ~12 min |
| Proposal Threshold | 0 | Any NFT holder can propose |
| Token | OlympiaMemberNFT | 1 NFT = 1 vote |
| Timelock | TimelockController | 1 block min delay |
| Sanctions Oracle | SanctionsOracle | 3-layer defense |

### OlympiaExecutor (`0x94d4...e97`)

| Immutable | Value | Purpose |
|-----------|-------|---------|
| treasury | `0xd616...e37` | OlympiaTreasury address |
| timelock | `0x1E0f...6e` | Only TimelockController can call |
| sanctionsOracle | `0xEeeb...3B4` | Layer 3 sanctions check |

### ECFPRegistry (`0xcB53...05d`)

| Role | Holder | Purpose |
|------|--------|---------|
| DEFAULT_ADMIN_ROLE | Deployer (`0x3b09...537`) | Can grant/revoke GOVERNOR_ROLE |
| GOVERNOR_ROLE | TimelockController (`0x1E0f...6e`) | Can activate/approve/expire proposals |

### OlympiaTreasury (`0xd616...e37`)

| Role | Holder | Purpose |
|------|--------|---------|
| DEFAULT_ADMIN_ROLE | Deployer (`0x3b09...537`) | Admin (with 3-day transfer delay) |
| WITHDRAWER_ROLE | OlympiaExecutor (`0x94d4...e97`) | Can withdraw ETC from treasury |

---

## Execution Flow

```
1. ECFPRegistry.submit()           — Anyone submits a funding proposal (permissionless)
2. OlympiaGovernor.propose()       — NFT holder creates governance proposal [Layer 1: sanctions check on targets]
3. OlympiaGovernor.castVote()      — NFT holders vote (For/Against/Abstain)
   └── cancelIfSanctioned()        — Anyone can cancel if recipient becomes sanctioned [Layer 2]
4. OlympiaGovernor.queue()         — Queue in TimelockController after vote passes
5. TimelockController.execute()    — Execute after timelock delay
6. OlympiaExecutor.executeTreasury() — [Layer 3: sanctions check] → Treasury.withdraw()
```

---

## Deployment Transactions

### Phase 2A: Foundation (DeployFoundation.s.sol)

| # | Action | Nonce | Gas Used | Block |
|---|--------|-------|----------|-------|
| 1 | Deploy SanctionsOracle (CREATE2) | 413 | ~500K | 15,721,718 |
| 2 | Deploy OlympiaMemberNFT (CREATE2) | 414 | ~1.2M | 15,721,718 |
| 3 | Mint NFT #0 to dev wallet | 415 | ~100K | 15,721,718 |

### Phase 2B: Governance (DeployGovernance.s.sol)

| # | Action | Nonce | Gas Used | Block |
|---|--------|-------|----------|-------|
| 1 | Deploy TimelockController (CREATE2) | 416 | ~1.1M | 15,721,718 |
| 2 | Deploy OlympiaGovernor (CREATE2) | — | FAILED | — |
| 3 | Deploy OlympiaExecutor (CREATE2) | 418 | ~600K | 15,721,718 |
| 4 | Deploy ECFPRegistry (CREATE2) | 419 | ~800K | 15,721,718 |
| 5-7 | Grant Timelock roles to Governor | 420-422 | ~50K each | 15,721,718 |

### Phase 2B Repair: Governor (RepairGovernor.s.sol)

| # | Action | TX Hash | Nonce | Gas Used | Block |
|---|--------|---------|-------|----------|-------|
| 1 | Deploy OlympiaGovernor (CREATE2) | `0x38b44c...` | 423 | 4,190,152 | 15,721,890 |
| 2 | Grant PROPOSER_ROLE on Timelock | `0x76bb92...` | 424 | 51,507 | 15,721,891 |
| 3 | Grant EXECUTOR_ROLE on Timelock | `0xc763d6...` | 425 | 51,507 | — |
| 4 | Grant CANCELLER_ROLE on Timelock | `0x3fe395...` | 426 | 51,462 | — |

### Post-Deploy Role Grants (cast send)

| # | Action | TX Hash | Nonce | Gas Used | Block |
|---|--------|---------|-------|----------|-------|
| 1 | Grant WITHDRAWER_ROLE on Treasury to Executor | `0xd5a435...` | 427 | 51,650 | 15,721,917 |
| 2 | Grant GOVERNOR_ROLE on ECFPRegistry to Timelock | `0xbcf0b2...` | 428 | 51,462 | 15,721,920 |

---

## NFT Holders

| Token ID | Holder | Votes |
|----------|--------|-------|
| 0 | Dev wallet (`0x3b09...537`) | 1 |

---

## Pre-Olympia vs Post-Olympia

| Aspect | Pre-Olympia (current) | Post-Olympia (future) |
|--------|----------------------|----------------------|
| Branch | `pre-olympia` | `main` |
| OZ Version | 5.1.0 | 5.6.0 |
| EVM Target | Shanghai | Cancun |
| via_ir | Required (bytecode > 8M gas) | Optional (60M gas limit) |
| Governor API | `_castVote` override | `_tallyUpdated` override |
| Block Gas Limit | 8,000,000 | 60,000,000 |
| Activation | Now | Block 15,800,850 (~Mar 28) |

---

## Verification Commands

```bash
source .env

# Governor
cast call 0xEdbD61F1cE825CF939beBB422F8C914a69826dDA "name()(string)" --rpc-url $MORDOR_RPC_URL
cast call 0xEdbD61F1cE825CF939beBB422F8C914a69826dDA "votingPeriod()(uint256)" --rpc-url $MORDOR_RPC_URL

# Timelock roles
PROPOSER=$(cast call 0x1E0fADee5540a77012f1944fcce58677fC087f6e "PROPOSER_ROLE()(bytes32)" --rpc-url $MORDOR_RPC_URL)
cast call 0x1E0fADee5540a77012f1944fcce58677fC087f6e "hasRole(bytes32,address)(bool)" $PROPOSER 0xEdbD61F1cE825CF939beBB422F8C914a69826dDA --rpc-url $MORDOR_RPC_URL

# Treasury WITHDRAWER
cast call 0xd6165F3aF4281037bce810621F62B43077Fb0e37 "hasRole(bytes32,address)(bool)" 0x10dac8c06a04bec0b551627dad28bc00d6516b0caacd1c7b345fcdb5211334e4 0x94d4f74dDdE715Ed195B597A3434713690B14e97 --rpc-url $MORDOR_RPC_URL

# ECFPRegistry GOVERNOR
cast call 0xcB532fe70299D53Cc81B5F6365f56A108784d05d "hasRole(bytes32,address)(bool)" 0x7935bd0ae54bc31f548c14dba4d37c5c64b3f8ca900cb468fb8abd54d5894f55 0x1E0fADee5540a77012f1944fcce58677fC087f6e --rpc-url $MORDOR_RPC_URL

# NFT
cast call 0x720676EBfe45DECfC43c8E9870C64413a2480EE0 "balanceOf(address)(uint256)" 0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537 --rpc-url $MORDOR_RPC_URL
```
