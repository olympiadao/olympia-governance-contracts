# Attribution — ECFPRegistry Spam Protection (demo_v0.4)

Design patterns used in the ECFPRegistry submission bond and draft cap implementation.
Contract NatSpec is kept minimal; this document is the full attribution reference.

---

## Bond Mechanism — Token Curated Registry (TCR) Pattern

The submission bond model (slash on expiry, refund on activation) follows the TCR design
introduced by Mike Goldin in "Token-Curated Registries 1.0" (2017).

Reference: https://medium.com/@ilovebagels/token-curated-registries-1-0-61a232f8dac7

Core insight: economic stake aligns submitter incentives with curation quality.
In Olympia's variant, `GOVERNOR_ROLE` replaces adversarial challengers as the curation
authority. Legitimate proposals are free (bond returned at activation). Spam and
low-quality proposals have their bonds slashed.

---

## Spam-Funds-Treasury Design

Directing slashed bonds to `OlympiaTreasury` adapts EIP-1559's fee recycling principle
(Buterin, Conner, Dudley, Slipper et al., 2019): spam increases its own cost, and those
costs flow to the network rather than being discarded.

In EIP-1559, base fees are burned to benefit all ETH holders.
In Olympia, slashed bonds go to the treasury — the entity directly responsible for
funding the work being attacked. The DAO that pays gas to expire spam also receives
the slashed bonds.

Reference: https://eips.ethereum.org/EIPS/eip-1559 (base fee burn rationale, Section "Fee Burn")

The "spam-funds-target" framing applied to a DAO proposal registry is an original design
contribution of the Olympia DAO team.

---

## Pull Payment Pattern (Bond Refunds)

Proposer refunds use the pull-over-push pattern to eliminate reentrancy risk from
arbitrary proposer addresses.

Reference: OpenZeppelin Contracts "Pull Payment"
https://docs.openzeppelin.com/contracts/5.x/api/security#PullPayment

Implementation: `pendingRefunds[proposer]` mapping + `claimRefund()` external function.
ETH is never pushed to an unknown address from within `activateProposal()` or
`withdrawDraft()` — proposers must call `claimRefund()` to pull their own funds.

Treasury slash (trusted, known contract): direct push via `Address.sendValue()` is safe
because `OlympiaTreasury` has `receive() external payable` and is a controlled contract.

---

## OpenZeppelin Components

- **`ReentrancyGuard`** — OpenZeppelin Contracts v5.1.0, MIT License
  Applied to `claimRefund()`, `expireProposal()`, and `batchExpire()` (any function that
  transfers ETH).
  Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.1.0/contracts/utils/ReentrancyGuard.sol

- **`Address.sendValue()`** — OpenZeppelin Contracts v5.1.0, MIT License
  Used for treasury slash transfers in `expireProposal()` and `batchExpire()`.
  Reverts on failure (no silent failures). Safe for known, controlled recipients.
  Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.1.0/contracts/utils/Address.sol

- **`AccessControl`** — OpenZeppelin Contracts v5.1.0, MIT License
  Provides `GOVERNOR_ROLE` (status transitions, batch expiry) and `DEFAULT_ADMIN_ROLE`
  (bond amount governance via `setSubmissionBond()`). Already used in demo_v0.3.

---

## Why Not OpenZeppelin Governor for Spam Control

OZ Governor 5.x has exactly one spam control: `proposalThreshold` (minimum voting power
to call `Governor.propose()`). It has no bond mechanism and no rate limiting.

`OlympiaGovernor` sets `proposalThreshold = 0` because NFT membership already gates
who can call `Governor.propose()`. `ECFPRegistry` is architecturally upstream:

```
ECFPRegistry.submit() [permissionless]
  -> review period
  -> activateProposal() [GOVERNOR_ROLE]
  -> Governor.propose() [NFT-gated]
  -> vote -> queue -> TimelockController -> execute
```

`ECFPRegistry` cannot be replaced by OZ Governor — the registry has a distinct lifecycle
(Draft -> Active -> Approved -> Executed/Rejected/Expired/Withdrawn) and must remain
permissionless at the submission stage. The bond-based approach follows the audited TCR
pattern for permissionless-but-bonded registries.
