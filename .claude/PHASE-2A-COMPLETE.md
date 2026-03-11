# Phase 2A — Foundation Contracts: COMPLETE

**Completed:** 2026-03-10
**Tests:** 33 (14 SanctionsOracle + 19 OlympiaMemberNFT)
**Commits:** `ece01d9` → `c38cd8f` (6 commits)

---

## What Was Built

### SanctionsOracle (ECIP-1119)

On-chain sanctions list with role-gated management. Core of the 3-layer sanctions defense.

| File | Purpose |
|------|---------|
| `src/interfaces/ISanctionsOracle.sol` | Read-only query interface (`isSanctioned(address)`) |
| `src/SanctionsOracle.sol` | `AccessControl` with `MANAGER_ROLE` for add/remove |
| `test/SanctionsOracle.t.sol` | 14 tests |

**Key decisions:**
- `MANAGER_ROLE` (not DEFAULT_ADMIN_ROLE) gates add/remove — allows multi-sig or DAO control
- Custom errors: `AlreadySanctioned(address)`, `NotSanctioned(address)`, `ZeroAddress()`
- Events: `AddressAdded`, `AddressRemoved` for off-chain indexing

### OlympiaMemberNFT (ECIP-1113)

Soulbound governance NFT. One NFT = one vote. KYC-gated issuance.

| File | Purpose |
|------|---------|
| `src/interfaces/IERC5192.sol` | EIP-5192 soulbound token interface (not in OZ v5.6) |
| `src/OlympiaMemberNFT.sol` | `ERC721 + ERC721Enumerable + ERC721Votes + IERC5192 + AccessControl` |
| `test/OlympiaMemberNFT.t.sol` | 19 tests |

**Key decisions:**
- Soulbound via `_update()` override — blocks transfers, allows mint/burn
- Auto-delegate on mint (`_delegate(to, to)`) — votes active immediately, no user action needed
- Block number clock mode (OZ default) — no `clock()`/`CLOCK_MODE()` override
- `MINTER_ROLE` gates issuance — identity verification at application layer (BrightID/Gitcoin Passport)
- `locked(tokenId)` always returns `true` — full ERC5192 compliance

### IOlympiaVotingModule (Forward-Looking Interface)

| File | Purpose |
|------|---------|
| `src/interfaces/IOlympiaVotingModule.sol` | Modular voting power interface for future governance-gated swaps |

Not wired into Demo v0.1 Governor. Spec artifact for future releases.

---

## Diamond Inheritance Resolution

OlympiaMemberNFT required careful C3 linearization:

```solidity
contract OlympiaMemberNFT is ERC721, ERC721Enumerable, ERC721Votes, IERC5192, AccessControl
```

**Override map:**
| Function | Override List |
|----------|-------------|
| `_update()` | ERC721, ERC721Enumerable, ERC721Votes |
| `_increaseBalance()` | ERC721, ERC721Enumerable |
| `supportsInterface()` | ERC721, ERC721Enumerable, AccessControl |

---

## Test Summary (33 total)

### SanctionsOracle (14 tests)
- `test_constructor_grantsRoles` — admin gets DEFAULT_ADMIN_ROLE + MANAGER_ROLE
- `test_addAddress_happyPath` — adds address, emits AddressAdded
- `test_addAddress_revertsIfAlreadySanctioned`
- `test_addAddress_revertsIfZeroAddress`
- `test_addAddress_revertsWithoutManagerRole`
- `test_removeAddress_happyPath` — removes address, emits AddressRemoved
- `test_removeAddress_revertsIfNotSanctioned`
- `test_removeAddress_revertsIfZeroAddress`
- `test_removeAddress_revertsWithoutManagerRole`
- `test_isSanctioned_returnsTrueForSanctioned`
- `test_isSanctioned_returnsFalseForClean`
- `test_isSanctioned_returnsFalseAfterRemoval`
- `test_adminCanGrantManagerRole`
- `test_managerCannotGrantManagerRole`

### OlympiaMemberNFT (19 tests)
- `test_constructor_setsName`, `test_constructor_setsSymbol`
- `test_safeMint_assignsToken`, `test_safeMint_emitsTransfer`, `test_safeMint_emitsLocked`
- `test_safeMint_autoDelegates` — getVotes == 1 after mint
- `test_safeMint_revertsWithoutMinterRole`
- `test_transfer_reverts` — SoulboundTransferBlocked
- `test_getPastVotes_snapshotCorrectness` — vm.roll() verification
- `test_multipleMints_incrementsTotalSupply`
- `test_locked_alwaysReturnsTrue`
- `test_supportsInterface_ERC721`, `_ERC721Enumerable`, `_IERC5192`, `_AccessControl`
- `test_tokenByIndex_enumeration`
- `test_balanceOf_incrementsOnMint`
- `test_safeMint_multipleToSameAddress` — 2 NFTs = 2 votes
- `test_ownerOf_returnsCorrectOwner`

---

## Commits

| Hash | Message |
|------|---------|
| `ece01d9` | Add OlympiaMemberNFT soulbound governance NFT (ECIP-1113) |
| `a9a4a15` | Add IOlympiaVotingModule interface (ECIP-1113) |
| `c38cd8f` | Update README and apply forge fmt to OlympiaMemberNFT |

*Note: SanctionsOracle and Foundry init commits preceded these in the same session.*
