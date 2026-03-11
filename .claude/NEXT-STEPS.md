# Olympia Implementation — Next Steps

**Last Updated:** 2026-03-11
**Current Status:** Phase 2B complete. 87 tests passing. All Stage 2 contracts built but not yet deployed to Mordor.

---

## Overall Progress

| Stage | ECIPs | Status | What's Done |
|-------|-------|--------|-------------|
| **1 — Hard Fork** | 1111, 1112, 1121 | ✅ Complete | 3 clients implemented, Treasury deployed Mordor + ETC |
| **2 — CoreDAO** | 1113, 1114, 1119 | ✅ Code complete | All contracts built and tested (87 tests). Not yet deployed. |
| **3 — Futarchy** | 1117, 1118 | 🔬 Research | Prototype in olympia-futarchy repo (1,345 tests). Not integrated. |
| **4 — Miner Experimentation** | 1115 | ⏳ Deferred | Spec written. Requires fee-market data post-Olympia activation. |
| **5 — Protocol Hardcode** | 1116, 1122 | 🚫 Deferred | Requires Phase 4 empirical data. Second hard fork. |

---

## Phase 2C: Mordor Deployment & Lifecycle Testing

**Priority:** HIGH — needed before Mordor activation (block 15,800,850, ~March 28, 2026)

### 2C-1: Deploy Phase 2A Contracts to Mordor

Deploy SanctionsOracle and OlympiaMemberNFT with CREATE2.

```bash
# Requires: PRIVATE_KEY in .env, Mordor RPC
# Need a Phase 2A deploy script (currently only Phase 2B script exists)
```

**Tasks:**
1. Write `script/DeployFoundation.s.sol` for Phase 2A contracts (Oracle + NFT)
2. Deploy to Mordor via `forge script --broadcast --legacy`
3. Record deployed addresses
4. Mint NFT to dev wallet (`0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537`)

### 2C-2: Deploy Phase 2B Contracts to Mordor

Deploy Governor pipeline using existing `DeployGovernance.s.sol`.

```bash
export SANCTIONS_ORACLE=<from 2C-1>
export MEMBER_NFT=<from 2C-1>
forge script script/DeployGovernance.s.sol:DeployGovernance \
  --rpc-url $MORDOR_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

**Post-deploy setup:**
1. Grant `WITHDRAWER_ROLE` on Treasury to Executor
2. Grant `GOVERNOR_ROLE` on ECFPRegistry to Timelock
3. Mint NFTs to test voters (alice, bob, charlie)

### 2C-3: Live Governance Lifecycle Test on Mordor

End-to-end test on live testnet (not just Foundry):

1. Submit ECFP via ECFPRegistry
2. Create Governor proposal referencing the ECFP
3. Cast votes from NFT holders
4. Queue proposal after voting period
5. Execute after timelock delay
6. Verify Treasury → Executor → recipient fund flow
7. Test cancelIfSanctioned with a sanctioned address

### 2C-4: Olympia App Integration

Connect the governance UI (`olympia-app`) to deployed contracts.

**Repo:** `/media/dev/2tb/dev/olympiadao/olympia-app/`
**Status:** Placeholder (Next.js 16 + wagmi scaffold)

**Tasks:**
1. Generate TypeScript ABIs from deployed contracts (`forge build --extra-output-files abi`)
2. Configure wagmi with Mordor chain + contract addresses
3. Build proposal creation flow (ECFP submit → Governor propose)
4. Build voting interface (castVote)
5. Build queue/execute interface
6. Build proposal status tracker (Governor state + ECFPRegistry status)
7. Build sanctions check display

---

## Phase 2D: Security Hardening

**Priority:** MEDIUM — before any ETC mainnet deployment

### 2D-1: Governor Security Review

- [ ] Review assembly calldata decoding in `_findSanctionedRecipient()` for edge cases
- [ ] Verify GovernorPreventLateQuorum extension behavior under adversarial conditions
- [ ] Test with 0 NFT holders (quorum edge case)
- [ ] Test with exactly 1 NFT holder (minimum viable governance)
- [ ] Fuzz testing on propose/vote/execute cycle

### 2D-2: Access Control Audit

- [ ] Verify Timelock admin renunciation path is safe
- [ ] Verify ECFPRegistry GOVERNOR_ROLE migration (grant to new Governor, revoke from old)
- [ ] Verify Treasury WITHDRAWER_ROLE can only be granted by admin
- [ ] Test admin transfer on Treasury (AccessControlDefaultAdminRules 2-step)

### 2D-3: Gas Optimization

- [ ] `forge snapshot` baseline for all test suites
- [ ] Review Governor's 14 override pass-throughs for gas overhead
- [ ] ECFPRegistry storage optimization (pack struct if possible)

---

## Phase 2E: ETC Mainnet Deployment

**Priority:** After Mordor lifecycle testing passes + security review
**Prerequisites:** Mordor activation successful, governance lifecycle tested end-to-end

### 2E-1: Mainnet Deploy

Same CREATE2 salt (`OLYMPIA_DEMO_V0_1`) produces same addresses as Mordor.

```bash
forge script script/DeployGovernance.s.sol:DeployGovernance \
  --rpc-url $ETC_RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy
```

### 2E-2: Mainnet Configuration

**Mordor → ETC parameter changes:**

| Parameter | Mordor | ETC Mainnet | Rationale |
|-----------|--------|-------------|-----------|
| `votingDelay` | 1 block | TBD (~1 day?) | Give voters time to review |
| `votingPeriod` | 100 blocks | TBD (~7 days?) | Sufficient participation window |
| `timelockDelay` | 3600s | 86400s (1 day) | Production safety margin |
| `quorumPercent` | 10% | 10% (or adjust) | Depends on membership size |
| `lateQuorumExtension` | 50 blocks | TBD (~1 day?) | Prevent last-minute manipulation |

**Important:** These are constructor parameters — immutable after deployment. Choose carefully.

### 2E-3: Admin Handoff

1. Deploy all contracts with deployer as admin
2. Grant roles (WITHDRAWER_ROLE, GOVERNOR_ROLE, etc.)
3. Verify full lifecycle on ETC mainnet
4. Begin admin renunciation process:
   - Treasury: Accept admin transfer to... (TBD — DAO or renounce?)
   - Timelock: Renounce deployer's DEFAULT_ADMIN_ROLE (makes Governor the sole controller)
   - ECFPRegistry: Renounce DEFAULT_ADMIN_ROLE after verifying GOVERNOR_ROLE holders

---

## Stage 3: Futarchy Integration (Future)

**Repo:** `/media/dev/2tb/dev/olympia-futarchy/prediction-dao-research/`
**Status:** 1,345 tests, prototype deployed

**When to start:** After CoreDAO (Stage 2) is operational and core infrastructure needs are funded. CoreDAO passes a governance proposal to activate Futarchy as the first "child DAO."

**Integration work needed:**
1. FutarchyExecutor — similar pattern to OlympiaExecutor, shared SanctionsOracle
2. Wire prediction market contracts to SanctionsOracle (ECIP-1119)
3. Grant Futarchy's Executor a separate `WITHDRAWER_ROLE` on Treasury
4. Deploy streaming disbursement contracts (ECIP-1118)
5. Governance proposal from CoreDAO to fund Futarchy operations

**Multi-DAO model:**
- CoreDAO (ECIP-1113 + 1114) handles core needs: RPCs, bootnodes, client dev, CVEs, explorers
- Futarchy (ECIP-1117 + 1118) handles public/contentious proposals: grants, experiments, community
- Both share: Treasury (via separate WITHDRAWER_ROLEs), SanctionsOracle
- CoreDAO operates indefinitely. Futarchy activates when funding allows.

---

## Stage 4: Miner Distribution Experimentation (Future)

**ECIP-1115:** L-Curve Smoothing — deterministic smoothing of basefee revenue portion for miner distribution.

**When to start:** After Olympia hard fork activates and fee-market data is available. Fees are negligible until adoption grows.

**Work needed:**
1. SmoothingModule contract (computes L-curve allocations)
2. MinerRewardModule contract (maps allocations to miner payout addresses)
3. Governance-adjustable parameters via OIP
4. Empirical data collection framework

---

## Stage 5: Protocol Hardcode (Future — Second Hard Fork)

**ECIPs 1116 + 1122:** Embed basefee split (5%/95%) and miner distribution curve at consensus level.

**When to start:** Only after Phase 4 empirical data validates the chosen parameters.

**Work needed:**
1. Client implementations in core-geth, besu-etc, fukuii (consensus layer changes)
2. Cross-client testing (hive integration tests)
3. Coordinate second hard fork activation blocks
4. Community review period

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-10 | Demo v0.1 uses GovernorVotes + soulbound NFT | Standard OZ, battle-tested, no custom voting logic |
| 2026-03-10 | Block number clock mode (OZ default) | Manipulation-resistant, no override needed |
| 2026-03-11 | Futarchy is "child DAO", not replacement | Multi-DAO: CoreDAO for core needs, Futarchy for public |
| 2026-03-11 | ECFPRegistry uses AccessControl, not AccessControlDefaultAdminRules | Simpler for proposal tracking, Treasury already has 2-step admin |
| 2026-03-11 | GovernorPreventLateQuorum included | Prevents last-minute vote manipulation, minimal overhead |
| 2026-03-11 | GovernorStorage included | Enables proposalDetails() for cancelIfSanctioned Layer 2 |
| 2026-03-11 | Executor is standalone (no OZ inheritance) | Minimal attack surface, only 3 immutables + 1 function |

---

## Quick Reference

### Repos

| Repo | Purpose | Status |
|------|---------|--------|
| [olympia-framework](https://github.com/olympiadao/olympia-framework) | 11 ECIP specs | Complete |
| [olympia-treasury-contract](https://github.com/olympiadao/olympia-treasury-contract) | Treasury vault | Deployed |
| [olympia-governance-contracts](https://github.com/olympiadao/olympia-governance-contracts) | Governor pipeline | Phase 2B code complete |
| [olympia-app](https://github.com/olympiadao/olympia-app) | Governance dApp | Placeholder |
| [olympia-brand](https://github.com/olympiadao/olympia-brand) | Logo, design tokens | Complete |
| [olympiadao-org](https://github.com/olympiadao/olympiadao-org) | Landing page | Complete |
| [olympiatreasury-org](https://github.com/olympiadao/olympiatreasury-org) | Treasury page | Complete |

### Key Addresses

| Contract | Mordor | ETC Mainnet |
|----------|--------|-------------|
| OlympiaTreasury | `0xd6165F3aF4281037bce810621F62B43077Fb0e37` | `0xd6165F3aF4281037bce810621F62B43077Fb0e37` |
| SanctionsOracle | TBD (Phase 2C) | TBD (Phase 2E) |
| OlympiaMemberNFT | TBD (Phase 2C) | TBD (Phase 2E) |
| OlympiaGovernor | TBD (Phase 2C) | TBD (Phase 2E) |
| OlympiaExecutor | TBD (Phase 2C) | TBD (Phase 2E) |
| TimelockController | TBD (Phase 2C) | TBD (Phase 2E) |
| ECFPRegistry | TBD (Phase 2C) | TBD (Phase 2E) |
| Dev Wallet | `0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537` | Same |

### Mordor Activation

- **Block:** 15,800,850 (~March 28, 2026)
- **ETC RPC:** `https://etc.rivet.link`
- **Deploy flag:** `--legacy` (required until EIP-1559 activates)
