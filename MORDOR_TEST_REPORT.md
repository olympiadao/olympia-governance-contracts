# Olympia Demo v0.2 — Mordor On-Chain Test Report

**Date:** 2026-03-18
**Chain:** Mordor testnet (chainId 63)
**Branch:** `demo_v0.2`
**RPC:** `https://rpc.mordor.etccooperative.org`

## Deployed Contracts

Deployer: `0x7C3311F29e318617fed0833E68D6522948AaE995` (nonce 0)
Salt: `keccak256("OLYMPIA_DEMO_V0_2")`

| Contract | Address |
|----------|---------|
| OlympiaTreasury | `0x035b2e3c189B772e52F4C3DA6c45c84A3bB871bf` |
| SanctionsOracle | `0xfF2B8D7937D908D81C72D20AC99302EE6ACc2709` |
| OlympiaMemberNFT | `0x73e78d3a3470396325b975FcAFA8105A89A9E672` |
| TimelockController | `0xA5839b3e9445f7eE7AffdBC796DC0601f9b976C2` |
| OlympiaGovernor | `0xB85dbc899472756470EF4033b9637ff8fa2FD23D` |
| OlympiaExecutor | `0x64624f74F77639CbA268a6c8bEDC2778B707eF9a` |
| ECFPRegistry | `0xFB4De5674a6b9a301d16876795a74f3bdacfa722` |

## State

- NFT supply: 2 (deployer + dev wallet)
- Sanctioned address: `0x000000000000000000000000000000000000dEaD`
- Treasury balance pre-test: 0.10 METC
- Treasury balance post-test: 0.05 METC

## Test Results

All 16 tests passed.

### ECFP Lifecycle

| # | Test | Expected | Actual | Status |
|---|------|----------|--------|--------|
| 1 | ECFP-001: full lifecycle (submit → activate → propose → vote → queue → execute) | 0.05 METC transferred to dev wallet | State 7 (Executed). Treasury 0.10 → 0.05 METC. Execute tx `0x7acb2860314dc775ca730f19040f0e70bf0937c53b099912fbd55ee0495213e3` (block 15771720) | PASS |
| 2 | ECFP-002: defeated proposal (both voters Against) | State 3 (Defeated) | State 3 confirmed | PASS |
| 3 | ECFP-005: permissionless submit (non-NFT address) | Success | Proposal submitted by non-admin address | PASS |

#### ECFP-001 Execution Details

- Proposal ID: `0x155e768ba8ce638d4e9290f43be2e59f0e3d4a575a2eed317069b03a4b3a8a29`
- Description: `ECFP-001: Demo v0.2 test withdrawal — 0.05 METC to dev wallet`
- DescriptionHash: `0xcdca5a0e14307c926e5428312c3a7d6e4ec94a3e8567cdf8688f1fcc2c8dc260`
- Target: OlympiaExecutor (`0x64624f74F77639CbA268a6c8bEDC2778B707eF9a`)
- Calldata: `executeTreasury(0x3b0952fB8eAAC74E56E176102eBA70BAB1C81537, 50000000000000000)`
- Timelock ETA: `1773834866`

### Sanctions Defense (ECIP-1119)

| # | Test | Expected | Actual | Status |
|---|------|----------|--------|--------|
| 4 | Layer 1: propose() with sanctioned recipient (`0xdEaD`) | `SanctionedRecipient(0xdEaD)` revert | Revert at propose() | PASS |
| 5 | cancelIfSanctioned() on non-sanctioned proposal | Revert | Revert confirmed | PASS |

### ECFPRegistry (ECIP-1114)

| # | Test | Expected | Actual | Status |
|---|------|----------|--------|--------|
| 6 | Input validation: zero recipient | `ZeroRecipient` revert | Revert confirmed | PASS |
| 7 | Input validation: zero amount | `ZeroAmount` revert | Revert confirmed | PASS |
| 8 | Input validation: empty metadataCID | `EmptyMetadata` revert | Revert confirmed | PASS |
| 9 | Input validation: empty ecfpId | `EmptyEcfpId` revert | Revert confirmed | PASS |
| 10 | Draft lifecycle: submit → updateDraft → withdrawDraft | State transitions | All transitions confirmed | PASS |
| 11 | Review period enforcement: activateProposal() before minReviewPeriod | `ReviewPeriodActive` revert | Revert confirmed | PASS |

### Soulbound NFT (EIP-5192)

| # | Test | Expected | Actual | Status |
|---|------|----------|--------|--------|
| 12 | approve() on soulbound token | `ERC721InvalidApprover` revert | Revert confirmed | PASS |
| 13 | transferFrom() after setApprovalForAll | `SoulboundTransferBlocked` revert | setApprovalForAll succeeds (not overridden), transferFrom blocked by `_update()` override | PASS |

### Access Control

| # | Test | Expected | Actual | Status |
|---|------|----------|--------|--------|
| 14 | OlympiaExecutor: direct call (bypass Timelock) | `OnlyTimelock` revert | Revert confirmed | PASS |
| 15 | OlympiaTreasury: direct withdrawal (bypass Executor) | `Unauthorized` revert | Revert confirmed | PASS |
| 16 | Vote on queued proposal (state 5) | `GovernorUnexpectedProposalState` revert | State 5 (Queued), expected Active | PASS |
