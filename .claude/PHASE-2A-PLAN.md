# Plan: Phase 2A — Foundation Contracts (Olympia Governance)

## Version

| Component | Version | Notes |
|-----------|---------|-------|
| **Olympia Release** | Demo v0.1 | `OLYMPIA_DEMO_V0_1` CREATE2 salt |
| **OpenZeppelin** | v5.6.0 | Matches treasury contract deployment |
| **Solidity** | 0.8.28 | Matches treasury contract |
| **Foundry** | Latest | forge, cast, anvil |

All Olympia Demo v0.1 contracts (treasury, governance, app) use **OZ v5.6.0** for consistent bytecode and audit baseline.

## Context

Stage 1 (consensus layer) is complete — 3 ETC clients implement the Olympia hard fork, treasury vault deployed at `0xd6165F3aF4281037bce810621F62B43077Fb0e37`. Phase 2A builds the foundation contracts: SanctionsOracle (ECIP-1119) and OlympiaMemberNFT (ECIP-1113).

**Decision:** Demo v0.1 uses standard OZ `GovernorVotes` reading directly from a soulbound `OlympiaMemberNFT`. No custom `_getVotes()` override, no IOlympiaVotingModule adapter. The `IOlympiaVotingModule` interface is spec'd as a forward-looking design artifact for when module swapping is needed.

**Soulbound rationale:** KYC/BrightID/Gitcoin Passport-verified accounts receive a non-transferable NFT. One soulbound NFT = one vote. Prevents vote buying/trading. MINTER_ROLE gates issuance.

Specs are in **Draft** status — we default to OZ v5.6.0 terminology and update specs to match.

**Repo:** `/media/dev/2tb/dev/olympiadao/olympia-governance-contracts`
**Reference:** `/media/dev/2tb/dev/olympiadao/olympia-treasury-contract/` (foundry.toml, remappings, tests)
**Specs:** `/media/dev/2tb/dev/olympiadao/olympia-framework/specs/`

---

## Spec Updates Required (Draft → match OZ v5.6 + decisions)

1. **`release()` → `withdraw()`** — ECIP-1112 spec says `release()`, deployed contract uses `withdraw()`
2. **`snapshotBlock` → `timepoint`** — IOlympiaVotingModule uses OZ v5.6 ERC-6372 naming
3. **Demo v0.1 uses GovernorVotes** — Standard OZ voting, not custom `_getVotes()`. IOlympiaVotingModule included as forward-looking interface spec.
4. **Soulbound NFT** — OlympiaMemberNFT blocks transfers in `_update()`. ERC5192 `locked()` interface. KYC-gated minting via MINTER_ROLE.
5. **GovernorVotesQuorumFraction works** — Quorum = % of soulbound NFT holders. Bravo-style (only "For" votes count toward quorum).
6. **Block number clock mode (OZ default)** — No `clock()` or `CLOCK_MODE()` override. Block-based snapshots are manipulation-resistant. Front-end estimates wall-clock time from block numbers.

---

## Task 1: Foundry Project Initialization

### Commands:
```bash
cd /media/dev/2tb/dev/olympiadao/olympia-governance-contracts
forge init --force
forge install OpenZeppelin/openzeppelin-contracts@v5.6.0
forge install foundry-rs/forge-std
rm src/Counter.sol test/Counter.t.sol script/Counter.s.sol
```
Note: `forge init` and `forge install` create commits by default. We'll squash or amend into a single init commit.

### Files:

**`foundry.toml`** (mirror treasury pattern):
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.28"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
mordor = "${MORDOR_RPC_URL}"
etc = "${ETC_RPC_URL}"

[etherscan]
mordor = { key = "", url = "https://etc-mordor.blockscout.com/api" }
etc = { key = "", url = "https://etc.blockscout.com/api" }
```

**`remappings.txt`**:
```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
forge-std/=lib/forge-std/src/
```

### Commit: "Initialize Foundry project with OZ v5.6 and forge-std"

---

## Task 2: ISanctionsOracle + SanctionsOracle + Tests (ECIP-1119)

**`src/interfaces/ISanctionsOracle.sol`**:
```solidity
interface ISanctionsOracle {
    function isSanctioned(address account) external view returns (bool);
    event AddressAdded(address indexed account);
    event AddressRemoved(address indexed account);
}
```

**`src/SanctionsOracle.sol`**:
- Inherits: `ISanctionsOracle`, OZ `AccessControl`
- State: `mapping(address => bool) private _sanctioned`
- Role: `MANAGER_ROLE = keccak256("MANAGER_ROLE")`
- Constructor: `constructor(address admin)` — grants DEFAULT_ADMIN_ROLE + MANAGER_ROLE
- Functions:
  - `isSanctioned(address) view`
  - `addAddress(address) onlyRole(MANAGER_ROLE)` — reverts AlreadySanctioned
  - `removeAddress(address) onlyRole(MANAGER_ROLE)` — reverts NotSanctioned
- Custom errors: `AlreadySanctioned(address)`, `NotSanctioned(address)`, `ZeroAddress()`

**`test/SanctionsOracle.t.sol`** (~10 tests):
- Add/remove happy path + events
- isSanctioned state transitions
- Revert: duplicate add, remove non-sanctioned, zero address
- Access control: only MANAGER_ROLE, admin can grant

### Commit: "Add SanctionsOracle with MANAGER_ROLE access control (ECIP-1119)"

---

## Task 3: OlympiaMemberNFT + Tests (ECIP-1113)

**`src/OlympiaMemberNFT.sol`**:

**Inheritance (order matters for diamond):**
```solidity
contract OlympiaMemberNFT is ERC721, ERC721Enumerable, ERC721Votes, IERC5192, AccessControl
```

**Key implementation:**

1. **Soulbound via `_update()`** — blocks transfers, allows mint/burn:
   ```solidity
   function _update(address to, uint256 tokenId, address auth)
       internal override(ERC721, ERC721Enumerable, ERC721Votes) returns (address)
   {
       address from = super._update(to, tokenId, auth);
       if (from != address(0) && to != address(0)) revert SoulboundTransferBlocked();
       if (from == address(0) && to != address(0)) {
           _delegate(to, to);  // Auto-delegate on mint
           emit Locked(tokenId);
       }
       return from;
   }
   ```

2. **`_increaseBalance()` override** (ERC721 + ERC721Enumerable):
   ```solidity
   function _increaseBalance(address account, uint128 value)
       internal override(ERC721, ERC721Enumerable) { super._increaseBalance(account, value); }
   ```

3. **Clock mode:** OZ default (block numbers). No `clock()` or `CLOCK_MODE()` override needed.

4. **Minting:** `MINTER_ROLE`, `safeMint(address to)`, auto-increment `_nextTokenId`

5. **ERC5192:** `locked(uint256 tokenId)` always returns true, `supportsInterface` includes IERC5192

6. **Custom errors:** `SoulboundTransferBlocked()`

**`src/interfaces/IERC5192.sol`** (not in OZ v5.6):
```solidity
interface IERC5192 {
    event Locked(uint256 tokenId);
    event Unlocked(uint256 tokenId);
    function locked(uint256 tokenId) external view returns (bool);
}
```

**`test/OlympiaMemberNFT.t.sol`** (~12 tests):
- Mint: assigns token, emits Transfer + Locked
- Auto-delegate: getVotes(recipient) == 1 after mint
- Soulbound: transfer reverts (SoulboundTransferBlocked)
- getPastVotes: snapshot correctness with vm.roll()
- Multiple mints: totalSupply increments, enumeration works
- Locked: locked(tokenId) returns true
- supportsInterface: ERC721, ERC721Enumerable, IERC5192, AccessControl
- Access control: only MINTER_ROLE can mint

### Commit: "Add OlympiaMemberNFT soulbound governance NFT (ECIP-1113)"

---

## Task 4: IOlympiaVotingModule Interface (Demo v0.1 spec artifact)

**`src/interfaces/IOlympiaVotingModule.sol`**:
```solidity
/// @title IOlympiaVotingModule
/// @notice Modular voting power interface for OlympiaGovernor (ECIP-1113)
/// @dev Olympia Demo v0.1 uses standard OZ GovernorVotes with soulbound
///      OlympiaMemberNFT. This interface defines the swappable voting module
///      pattern for governance-gated upgrades via OIP in future releases.
interface IOlympiaVotingModule {
    function votingPower(address account, uint256 timepoint) external view returns (uint256);
    function isEligible(address account, uint256 timepoint) external view returns (bool);
}
```

Interface spec artifact — not wired into the Demo v0.1 Governor. Deployed alongside contracts for ABI availability and future reference.

### Commit: "Add IOlympiaVotingModule interface (ECIP-1113)"

---

## Task 5: Validate + README + Spec Updates

```bash
forge build && forge test -vv && forge fmt
```

**README.md** — Project description, contract table, architecture diagram, commands.

**Spec updates** in `/media/dev/2tb/dev/olympiadao/olympia-framework/specs/`:
- ECIP-1112: `release()` → `withdraw()` to match deployed contract
- ECIP-1113: `snapshotBlock` → `timepoint` (ERC-6372)
- ECIP-1113: Demo v0.1 uses GovernorVotes + soulbound NFT (not custom _getVotes())
- ECIP-1113: IOlympiaVotingModule included as forward-looking interface spec
- ECIP-1113: Document soulbound enforcement (IERC5192) + KYC-gated minting
- ECIP-1113: Bravo-style quorum (only "For" votes count)

### Commit: "Update README and specs with Phase 2A implementation details"

---

## Build Order

```
1. Foundry init + OZ v5.6
2. ISanctionsOracle + SanctionsOracle + tests
3. IERC5192 + OlympiaMemberNFT + tests
4. IOlympiaVotingModule (interface spec only)
5. Validate + README + spec updates
```

## OZ v5.6 Contracts Used

| OZ Contract | Used By | Purpose |
|-------------|---------|---------|
| `AccessControl` | SanctionsOracle | MANAGER_ROLE |
| `ERC721` | OlympiaMemberNFT | Base NFT |
| `ERC721Enumerable` | OlympiaMemberNFT | totalSupply(), tokenByIndex() |
| `ERC721Votes` | OlympiaMemberNFT | Delegation + getPastVotes() |

**Phase 2B will add:**
| OZ Contract | Used By | Purpose |
|-------------|---------|---------|
| `Governor` | OlympiaGovernor | Proposal lifecycle |
| `GovernorSettings` | OlympiaGovernor | Updatable params |
| `GovernorCountingSimple` | OlympiaGovernor | For/Against/Abstain |
| `GovernorVotes` | OlympiaGovernor | Reads soulbound NFT votes |
| `GovernorVotesQuorumFraction` | OlympiaGovernor | Quorum = % of NFT holders |
| `GovernorTimelockControl` | OlympiaGovernor | Timelock integration |
| `TimelockController` | Timelock | Delay queue |

## Key Decisions

1. **GovernorVotes + soulbound NFT for Demo v0.1** — Standard OZ stack, battle-tested. IOlympiaVotingModule as forward-looking spec artifact.
2. **Soulbound via `_update()` override** — Blocks transfers, allows mint/burn. IERC5192 `locked()` always true.
3. **KYC-gated minting** — MINTER_ROLE controls issuance. Identity verification (BrightID/Gitcoin Passport) at application layer.
4. **Auto-delegate on mint** — `_delegate(to, to)` in `_update()` so votes are active immediately.
5. **Block number clock (OZ default)** — No override. Block-based snapshots are manipulation-resistant. Front-end estimates time.
6. **OZ terminology canonical** — All draft specs updated to match OZ v5.6.

## Verification

```bash
cd /media/dev/2tb/dev/olympiadao/olympia-governance-contracts
forge build    # All contracts compile
forge test -vv # All tests pass
forge fmt      # Formatted
```

Expected: 3 interfaces (ISanctionsOracle, IERC5192, IOlympiaVotingModule) + 2 contracts (SanctionsOracle, OlympiaMemberNFT), 2 test files, ~22 tests total.
