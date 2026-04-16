# Olympia DAO — Mordor Seeding Scripts

Seeds the demo_v0.4 governance deployment on Mordor with authentic DAO activity:
3 maintainer NFTs minted and 6 funding proposals submitted, voted on, and executed
by ACME Open Source Development Corp across two waves.

All proposals reference real, open pull requests from the Core-Geth Modernization March.
Total disbursement: **10,000 mETC** to ACME Open Source Development Corp.

---

## Prerequisites

1. **Fill in `.env.seed`** (copy from `.env.seed.example`)
2. **Deposit mETC to treasury** — send at least 10,500 mETC to the treasury address
   (run `PrecomputeAddresses.s.sol` to compute the address before deployment)
3. **Fund ACME account with bonds** — ACME submits 6 proposals at 1 mETC bond each.
   Fund ACME with at least **6 mETC for bonds** plus gas (estimate 0.5 mETC for gas).
   Total minimum ACME balance: **6.5 mETC**
4. **Fund gas accounts** — deployer and 3 maintainers need mETC for gas
5. **Build** — `forge build` must pass before running any script

> **Bond mechanics (demo_v0.4):** Each `submit()` call requires exactly 1 mETC bond.
> Bonds are returned to ACME (via `pendingRefunds`) when proposals are activated.
> ACME must call `claimRefund()` after each wave's activation to recover bonds.
> Bonds are slashed to the treasury if proposals are expired instead of activated.

---

## Run Sequence

Scripts must run in order. Respect the wait times — they reflect real Mordor block times.

### Day 1 — Morning

```bash
# Load environment
source script/seed/.env.seed

# Step 1: Mint membership NFTs (deployer key, ~2 min)
forge script script/seed/01_MintMembers.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv

# Step 2: ACME submits Wave 1 ECFPs (ACME key, ~2 min)
forge script script/seed/02_SubmitWave1ECFPs.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $ACME_PRIVATE_KEY \
  --broadcast --legacy -vvv

# ⏳ Wait 5 minutes (minReviewPeriod = 300s)

# Step 3a: Deployer activates Wave 1 ECFPs
forge script script/seed/03_ActivateWave1.s.sol:ActivateWave1 \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv --sig "runActivate()"

# Step 3b: Maintainer 1 creates 4 Governor proposals (immediately after 3a)
forge script script/seed/03_ActivateWave1.s.sol:ActivateWave1 \
  --rpc-url $MORDOR_RPC_URL --private-key $MAINTAINER_1_PRIVATE_KEY \
  --broadcast --legacy -vvv --sig "runPropose()"

# ⏳ Wait 1 block (~13 seconds) for voting delay
```

### Day 1 — Morning/Midday

```bash
# Step 4: All 3 maintainers vote FOR on Wave 1 proposals
forge script script/seed/04_VoteWave1.s.sol \
  --rpc-url $MORDOR_RPC_URL \
  --broadcast --legacy -vvv

# ⏳ Wait ~22 minutes (100 blocks voting period)

# Step 5: Queue Wave 1 proposals (any account)
forge script script/seed/05_QueueWave1.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv
```

### Day 1 — During Wave 1 Timelock Wait (1 hour)

```bash
# Step 7: ACME submits Wave 2 ECFPs while Wave 1 timelock runs
forge script script/seed/07_SubmitWave2ECFPs.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $ACME_PRIVATE_KEY \
  --broadcast --legacy -vvv

# ⏳ Wait 5 minutes (minReviewPeriod = 300s)

# Step 8a: Deployer activates Wave 2 ECFPs
forge script script/seed/08_ActivateWave2.s.sol:ActivateWave2 \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv --sig "runActivate()"

# Step 8b: Maintainer 1 proposes Wave 2 (immediately after 8a)
forge script script/seed/08_ActivateWave2.s.sol:ActivateWave2 \
  --rpc-url $MORDOR_RPC_URL --private-key $MAINTAINER_1_PRIVATE_KEY \
  --broadcast --legacy -vvv --sig "runPropose()"

# ⏳ Wait 1 block

# Step 9: Vote on Wave 2 proposals
forge script script/seed/09_VoteWave2.s.sol \
  --rpc-url $MORDOR_RPC_URL \
  --broadcast --legacy -vvv

# ⏳ Wait ~22 minutes (voting period)
```

### Day 1 — Afternoon

```bash
# Step 6: Execute Wave 1 (after 1 hour timelock from step 5)
forge script script/seed/06_ExecuteWave1.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv

# Step 10: Queue Wave 2 proposals
forge script script/seed/10_QueueWave2.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv
```

### Day 2

```bash
# Step 11: Execute Wave 2 (after 1 hour timelock from step 10)
forge script script/seed/11_ExecuteWave2.s.sol \
  --rpc-url $MORDOR_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --legacy -vvv
```

---

## Timing Summary

| Step | Script | Wait After |
|------|--------|-----------|
| 01 | MintMembers | A few minutes |
| 02 | SubmitWave1ECFPs | **5 min** (ECFP review period) |
| 03a | ActivateWave1 (activate) | Immediate |
| 03b | ActivateWave1 (propose) | **1 block ~13s** |
| 04 | VoteWave1 | **~22 min** (100 blocks) |
| 05 | QueueWave1 | **1 hour** (timelock) |
| 07 | SubmitWave2ECFPs | **5 min** (review period) |
| 08a | ActivateWave2 (activate) | Immediate |
| 08b | ActivateWave2 (propose) | **1 block ~13s** |
| 09 | VoteWave2 | **~22 min** (100 blocks) |
| 06 | ExecuteWave1 | Immediate (timelock done) |
| 10 | QueueWave2 | **1 hour** (timelock) |
| 11 | ExecuteWave2 | Done |

Total wall-clock time: **~3.5 hours** across 2 calendar days.

---

## Contracts (Mordor demo_v0.4)

Addresses are pending deployment. Run `PrecomputeAddresses.s.sol` then the deploy scripts,
and update `SeedConfig.sol` with the actual deployed addresses.

| Contract | Address |
|----------|---------|
| OlympiaGovernor | `pending` |
| TimelockController | `pending` |
| OlympiaExecutor | `pending` |
| OlympiaMemberNFT | `pending` |
| MembershipVerifier | `pending` |
| ECFPRegistry | `pending` |
| OlympiaTreasury | `pending` |

---

## Proposals

| # | ECFP | Title | Amount |
|---|------|-------|--------|
| P1 | ECFP-001 | Go 1.26 Runtime Modernization (PR #10) | 1,200 mETC |
| P2 | ECFP-002 | Core Cryptography Hardening — 4 CVEs (PRs #14–17) | 1,600 mETC |
| P3 | ECFP-003 | Dependency & Protocol Security — 5 CVEs (PRs #12, #13, #18–20) | 1,400 mETC |
| P4 | ECFP-004 | P2P Protocol Security: CVE-2026-26313 + RLP (PRs #35, #36) | 2,200 mETC |
| P5 | ECFP-005 | ETC Chain Config & Consensus Unit Tests (PRs #21, #23–27) | 1,600 mETC |
| P6 | ECFP-006 | Live RPC Tests, Cross-Client Vectors & Repository Hygiene (PRs #28–31, #34) | 2,000 mETC |
| | | **Total** | **10,000 mETC** |

All proposals are submitted by **ACME Open Source Development Corp** (external contributor)
and funded by **Ethereum Classic DAO LLC** (legal entity of Olympia DAO).

---

## Verification

After all scripts complete (substitute actual deployed addresses from `SeedConfig.sol`):

```bash
# NFT balances (should all be 1)
cast call $MEMBER_NFT_ADDRESS "balanceOf(address)" $MAINTAINER_1_ADDRESS --rpc-url $MORDOR_RPC_URL
cast call $MEMBER_NFT_ADDRESS "balanceOf(address)" $MAINTAINER_2_ADDRESS --rpc-url $MORDOR_RPC_URL
cast call $MEMBER_NFT_ADDRESS "balanceOf(address)" $MAINTAINER_3_ADDRESS --rpc-url $MORDOR_RPC_URL

# Total NFT supply (should be 4: deployer #0 + maintainers #1-3)
cast call $MEMBER_NFT_ADDRESS "totalSupply()" --rpc-url $MORDOR_RPC_URL

# ACME pending bond refunds (should be 6 mETC after all activations, before claim)
cast call $REGISTRY_ADDRESS "pendingRefunds(address)" $ACME_ADDRESS --rpc-url $MORDOR_RPC_URL

# ACME balance (should be 10,000+ mETC after execution + claimed refunds)
cast balance $ACME_ADDRESS --rpc-url $MORDOR_RPC_URL --ether
```
