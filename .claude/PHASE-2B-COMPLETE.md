# Phase 2B — Governor Pipeline: COMPLETE

**Completed:** 2026-03-11
**Tests:** 54 new (9 Executor + 21 Governor + 19 ECFPRegistry + 5 Integration)
**Total project tests:** 87
**Commits:** `e5067fc` → `4223abc` (7 commits)

---

## What Was Built

### ITreasury Interface

| File | Purpose |
|------|---------|
| `src/interfaces/ITreasury.sol` | Minimal `withdraw(address payable, uint256)` interface matching deployed Treasury |

### OlympiaExecutor (ECIP-1113 — Layer 3 Sanctions Gate)

| File | Purpose |
|------|---------|
| `src/OlympiaExecutor.sol` | Standalone contract — final sanctions check before Treasury withdrawal |
| `test/OlympiaExecutor.t.sol` | 9 tests |

**Architecture:**
- 3 immutable fields: `treasury`, `timelock`, `sanctionsOracle`
- Single function: `executeTreasury(address payable recipient, uint256 amount)`
- Access: `msg.sender == timelock` (revert `OnlyTimelock()`)
- Sanctions: `sanctionsOracle.isSanctioned(recipient)` (revert `SanctionedRecipient(address)`)
- Action: `ITreasury(treasury).withdraw(recipient, amount)`
- No OZ inheritance — minimal standalone contract

### OlympiaGovernor (ECIP-1113 — 3-Layer Sanctions Defense)

| File | Purpose |
|------|---------|
| `src/OlympiaGovernor.sol` | Governor with diamond inheritance (8 OZ extensions) + custom sanctions logic |
| `test/OlympiaGovernor.t.sol` | 21 tests |

**Diamond inheritance chain:**
```solidity
contract OlympiaGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    GovernorPreventLateQuorum,
    GovernorStorage
```

**Custom logic:**
- **Layer 1** — `propose()` override: Scans targets and calldatas for sanctioned recipients. Assembly-based calldata decoding extracts recipient from `executeTreasury(address,uint256)` calls.
- **Layer 2** — `cancelIfSanctioned(uint256 proposalId)`: Permissionless. Uses `proposalDetails()` from GovernorStorage to retrieve proposal data, scans for sanctioned recipients, calls `_cancel()` if found.
- **Self-upgrade** — `updateSanctionsOracle(ISanctionsOracle)`: `onlyGovernance` modifier requires full propose→vote→queue→execute pipeline.

**14 diamond override pass-throughs:**

| Function | Override List |
|----------|-------------|
| `state(uint256)` | Governor, GovernorTimelockControl |
| `proposalNeedsQueuing(uint256)` | Governor, GovernorTimelockControl |
| `proposalDeadline(uint256)` | Governor, GovernorPreventLateQuorum |
| `votingDelay()` | Governor, GovernorSettings |
| `votingPeriod()` | Governor, GovernorSettings |
| `proposalThreshold()` | Governor, GovernorSettings |
| `quorum(uint256)` | Governor, GovernorVotesQuorumFraction |
| `_queueOperations(...)` | Governor, GovernorTimelockControl |
| `_executeOperations(...)` | Governor, GovernorTimelockControl |
| `_cancel(...)` | Governor, GovernorTimelockControl |
| `_executor()` | Governor, GovernorTimelockControl |
| `_tallyUpdated(uint256)` | Governor, GovernorPreventLateQuorum |
| `_propose(...)` | Governor, GovernorStorage |
| `propose(...)` | Governor (custom Layer 1 logic) |

### ECFPRegistry (ECIP-1114 — Hash-Bound Proposals)

| File | Purpose |
|------|---------|
| `src/ECFPRegistry.sol` | Permissionless proposal submission with GOVERNOR_ROLE-gated status transitions |
| `test/ECFPRegistry.t.sol` | 19 tests |

**Architecture:**
- `AccessControl` with `GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE")`
- Hash-bound IDs: `keccak256(abi.encodePacked(ecfpId, recipient, amount, metadataCID, block.chainid))`
- Permissionless `submit()` → Draft status
- GOVERNOR_ROLE transitions: `activateProposal` (Draft→Active), `approveProposal` (Active→Approved), `rejectProposal` (Active→Rejected), `markExecuted` (Approved→Executed), `expireProposal` (Draft/Active→Expired)
- Invalid transitions revert with `InvalidStatusTransition(current, target)`

### Integration Tests

| File | Purpose |
|------|---------|
| `test/GovernancePipeline.t.sol` | 5 end-to-end tests across all contracts |

### Deploy Script

| File | Purpose |
|------|---------|
| `script/DeployGovernance.s.sol` | CREATE2 deployment with `OLYMPIA_DEMO_V0_1` salt |

**Deploy sequence:**
1. Deploy TimelockController (empty proposers/executors, admin = deployer)
2. Deploy OlympiaGovernor (with timelock, NFT, oracle)
3. Grant timelock roles to Governor (PROPOSER, EXECUTOR, CANCELLER)
4. Deploy OlympiaExecutor (with treasury, timelock, oracle)
5. Deploy ECFPRegistry (admin = deployer)
6. Post-deploy: Grant WITHDRAWER_ROLE on Treasury to Executor, GOVERNOR_ROLE on ECFPRegistry to Timelock

---

## Execution Path (Full Pipeline)

```
ECFPRegistry.submit(ecfpId, recipient, amount, metadataCID)
  ↓ (permissionless — anyone can propose)
OlympiaGovernor.propose(targets=[executor], calldatas=[executeTreasury(recipient, amount)])
  ↓ Layer 1: _findSanctionedRecipient(targets, calldatas) — assembly decode
  ↓ GovernorStorage stores proposal details on-chain
Voting (VOTING_DELAY=1 block → VOTING_PERIOD=100 blocks)
  ↓ GovernorVotes reads OlympiaMemberNFT.getPastVotes(account, timepoint)
  ↓ GovernorCountingSimple: For / Against / Abstain
  ↓ GovernorVotesQuorumFraction: 10% of total supply must vote "For"
  ↓ GovernorPreventLateQuorum: extends by 50 blocks if quorum reached late
[Optional] cancelIfSanctioned(proposalId)
  ↓ Layer 2: permissionless — reads proposalDetails(), scans for sanctioned
queue(targets, values, calldatas, descriptionHash)
  ↓ TimelockController.scheduleBatch() — TIMELOCK_DELAY = 3600s (Mordor)
execute(targets, values, calldatas, descriptionHash)
  ↓ TimelockController.executeBatch()
OlympiaExecutor.executeTreasury(recipient, amount)
  ↓ Layer 3: sanctionsOracle.isSanctioned(recipient) — final gate
OlympiaTreasury.withdraw(recipient, amount)
  ↓ ETH transferred to recipient
```

---

## Mordor Testnet Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `votingDelay` | 1 block | Minimal delay for testing |
| `votingPeriod` | 100 blocks (~22 min) | Fast iteration on testnet |
| `quorumPercent` | 10% | Meaningful threshold for small membership (10-50 NFTs) |
| `lateQuorumExtension` | 50 blocks (~11 min) | Half the voting period |
| `timelockDelay` | 3600s (1 hour) | Short for demo; production = 86400s (1 day) |
| `proposalThreshold` | 0 | Any NFT holder can propose |

---

## Test Summary (54 new, 87 total)

### OlympiaExecutor (9 tests)
- Constructor validation (3 zero-address checks)
- `executeTreasury` happy path — funds arrive at recipient
- `executeTreasury` reverts if not timelock (`OnlyTimelock`)
- `executeTreasury` reverts if recipient sanctioned (`SanctionedRecipient`)
- Event emission (`TreasuryExecution`)
- Treasury revert propagation

### OlympiaGovernor (21 tests)
- **Constructor (4):** setsToken, setsSanctionsOracle, setsTimelock, setsSettings
- **Propose — Layer 1 (3):** happy path, calldata recipient sanctioned, target sanctioned
- **Voting (3):** for/against/abstain counting, zero votes without NFT, weight = NFT count
- **Queue & Execute (2):** queue after passing vote, execute after timelock delay
- **Full Lifecycle (1):** propose → vote → queue → execute → treasury withdrawal
- **cancelIfSanctioned — Layer 2 (4):** cancels when sanctioned, reverts when none, works on queued, emits event
- **updateSanctionsOracle (2):** only via governance pipeline, successfully updates
- **Quorum (2):** correct fraction of NFT supply, proposal fails without quorum

### ECFPRegistry (19 tests)
- **Constructor (1):** grants DEFAULT_ADMIN_ROLE + GOVERNOR_ROLE to admin
- **Submit (4):** creates proposal, emits event, reverts on duplicate, permissionless
- **ComputeHashId (2):** matches submit return, different chains produce different hashes
- **GetProposal (2):** returns correct data, reverts for nonexistent
- **ActivateProposal (2):** Draft→Active + event, reverts without GOVERNOR_ROLE
- **ApproveProposal (1):** Active→Approved + event
- **MarkExecuted (1):** Approved→Executed + event
- **InvalidStatusTransition (2):** Draft→Executed reverts, Draft→Approved reverts
- **ExpireProposal (3):** Draft→Expired, Active→Expired, Approved→Expired reverts
- **Admin (1):** admin can grant GOVERNOR_ROLE (migration pattern)

### GovernancePipeline — Integration (5 tests)
- `test_pipeline_fullLifecycleWithECFPRegistry` — ECFP submit → propose → vote → queue → execute → withdraw
- `test_pipeline_sanctionedRecipientBlockedAtLayer1` — propose reverts
- `test_pipeline_sanctionedRecipientCancelledAtLayer2` — cancel mid-vote after oracle update
- `test_pipeline_sanctionedRecipientBlockedAtLayer3` — oracle updated after queue, execute reverts
- `test_pipeline_governorUpdatesOwnSanctionsOracle` — self-governance upgrade via full pipeline

---

## Key Lessons Learned

1. **`onlyGovernance` requires full pipeline** — OZ Governor's `onlyGovernance` modifier checks `msg.sender == _executor()`, which is the Timelock. Can't shortcut with `vm.prank(timelock)` — must create a real governance proposal that calls the function through propose→vote→queue→execute.

2. **`vm.prank` consumed by nested calls** — `vm.prank(alice); governor.castVote(governor.hashProposal(...), 1)` applies prank to `hashProposal()` not `castVote()`. Store proposalId separately.

3. **GovernorStorage doesn't override public `propose()`** — Only overrides internal `_propose()`. The public `propose()` override list is `override(Governor)`, not `override(Governor, GovernorStorage)`.

4. **Assembly calldata decoding** — Reading recipient from `executeTreasury(address,uint256)` calldata requires loading from memory array pointers with proper offset math (selector at +0x20, first arg at +0x24).

5. **`vm.expectRevert` before `vm.prank`** — In Foundry, `vm.expectRevert` should be called before `vm.prank`, not after. Otherwise the prank may be consumed by expectRevert setup.

---

## Commits

| Hash | Message |
|------|---------|
| `e5067fc` | Add ITreasury interface for Executor → Treasury calls (ECIP-1112) |
| `019fb55` | Add OlympiaExecutor with Layer 3 sanctions gate (ECIP-1113) |
| `bc5498b` | Add OlympiaGovernor with 3-layer sanctions defense (ECIP-1113) |
| `d590578` | Add ECFPRegistry with hash-bound proposals and GOVERNOR_ROLE (ECIP-1114) |
| `6343cb7` | Add end-to-end governance pipeline integration tests |
| `1d6c08f` | Add DeployGovernance script with CREATE2 |
| `4223abc` | Update README and CLAUDE.md with Phase 2B contracts |

---

## Framework Spec Updates (olympia-framework repo)

Multi-DAO alignment — Futarchy deploys alongside CoreDAO, not replacing:

| Spec | Change | Commit |
|------|--------|--------|
| ECIP-1117 | Removed `replaces: 1113`, clarified "child DAO activated by CoreDAO" | `67ab74b` |
| ECIP-1118 | Removed `replaces: 1114`, clarified alongside relationship | `67ab74b` |
| ECIP-1112 | "redirect" → "activate child DAO" language | `67ab74b` |
| ECIP-1113 | "redirect" → "activate child DAO" language | `67ab74b` |
