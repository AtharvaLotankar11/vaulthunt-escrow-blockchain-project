# SLITHER_FINDINGS_PHASE2.md (BountyEscrow, BountyFactory)

**Date:** 2026-11-08
**Tools:** Slither (pip, latest at time of run), Foundry nightly, Solc 0.8.38, OpenZeppelin 5.7.0
**Command (from `contracts\`):** `slither . --filter-paths "test|script|lib"`
**Result:** zero High, zero Medium, zero Low. 3 informational results (Phase 1 contracts excluded in this run; re-run on the whole repo in Phase 5).

| # | Detector | Where | Severity | Decision |
|---|---|---|---|---|
| 1 | assembly | `BountyEscrow.claimFor`, inline `call` | Informational | **Accepted.** A raw `call` with no output copy stops a hostile hunter from sending a huge return value ("return bomb"). The hunter gets at most `PUSH_GAS` gas. |
| 2 | low-level-calls | `BountyEscrow.withdraw` | Informational | **Accepted.** `call` with a checked `ok` is the recommended way to send ETH; the function is `onlyOwner` and `nonReentrant`. |
| 3 | low-level-calls | `BountyEscrow.claim` | Informational | **Accepted.** Same reason; state is zeroed before the call and the function is `nonReentrant`. |

## History (worth mentioning in the viva)
The first version paid the hunter inside `payHunter` and wrote state after the ETH send. Slither reported **reentrancy-eth (High)**. It was fixed by design: `payHunter` now only credits `claimable` (no ETH moves), and the ETH is sent by `claimFor`/`claim`, which zero the credit **before** sending (checks-effects-interactions) and are `nonReentrant`.
`BountyFactory.createProgram` also now records its state and emits its event before calling the new escrow.
