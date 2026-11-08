# SLITHER_FINDINGS_PHASE3.md (ReportRegistry)

**Date:** 2026-11-08
**Command (from `contracts\`):** `slither . --filter-paths "test|script|lib"`
**Result for ReportRegistry:** zero High. One Medium, three Low/Informational groups, all reviewed below.

| # | Detector | Where | Severity | Decision |
|---|---|---|---|---|
| 1 | reentrancy-no-eth | `_updateBadge`: `hasBadge[hunter]` and `badgeOf[hunter]` are written after `sbt.mint(...)` | Medium | **Accepted, documented.** `mint` uses `_safeMint`, which calls the hunter's `onERC721Received` hook, so a hostile hunter contract gets control for a moment. `_updateBadge` runs only inside `acceptReport` and `applyVerdict`, which are `nonReentrant`, so the hook cannot re-enter any function that reads these variables. The only unguarded entry points (`commitReport`, `startReview`, `rejectReport`) do not read them. The hook also gets at most `BADGE_GAS` (400k) gas and its failure never blocks a payout (tested). |
| 2 | reentrancy-benign | same function, `badgeOf` write | Low | **Accepted** (same reasoning as 1). |
| 3 | timestamp | window and deadline checks (`reveal`, `finalizeRejection`, `escalate`, `escalateAfterTimeout`) | Low | **Accepted.** The windows are days long; a validator can move a timestamp by seconds only. Boundaries are tested exactly (at the limit and one second after). |
| 4 | missing-inheritance | `ReputationSBT` does not declare `is IReputationSBT` | Informational | **Accepted.** The Phase 1 contract is unchanged on purpose; the interface matches its two functions exactly (tested end to end). |

## Design choices worth defending in the viva
- The Registry is the only address the escrows obey (decision D2); the company never calls an escrow.
- Revealing a report locks its reward, so the company cannot drain a program while reports wait.
- A rejection keeps the lock until the dispute window ends; `finalizeRejection` then returns the money.
- Badge and ETH-push failures never block a payout (hostile or non-NFT-capable hunter contracts are tested).
- A contract cannot wake itself, so timeouts are an explicit call: `escalateAfterTimeout`.

## Known limitations (put in LIMITATIONS.md)
- The company chooses the final severity when accepting; a hunter cannot dispute a lower-than-claimed severity in this version.
- Duplicate detection is by timestamp comparison: the contract records who committed first, a person decides which reports are duplicates.
- A hunter who never reveals leaves a harmless Committed entry (no funds are locked before reveal).
- Because a reveal locks funds, a program with too little unlocked money cannot accept more revealed reports until it is topped up.

## Deployment order (use in Phase 5)
1. `BountyFactory`  2. `ReputationSBT`  3. `ReportRegistry(factory, sbt, reviewPeriod, revealWindow, disputeWindow)`
4. `factory.setRegistry(registry)`  5. `sbt.transferOwnership(registry)`  6. `DisputeCourt` (Phase 4)  7. `registry.setCourt(court)`
For a live demo deploy with short periods (for example 5 minutes) instead of 7 days.
