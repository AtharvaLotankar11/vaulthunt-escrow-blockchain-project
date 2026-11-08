# SLITHER_FINDINGS_PHASE4.md (DisputeCourt)

**Date:** 2026-11-08
**Command (from `contracts\`):** `slither . --filter-paths "test|script|lib"`
**Result for DisputeCourt:** zero High, zero Medium. Five Low results, reviewed below.

| # | Detector | Where | Severity | Decision |
|---|---|---|---|---|
| 1 | missing-zero-check | constructor, `treasury_` | Low | **Accepted on purpose.** A zero treasury is allowed: rounding dust and unclaimable pools then go to the Court's own `reserve`. Tested. |
| 2 | timestamp (x4) | commit/reveal windows, unstake cooldown, `resolveCase` | Low | **Accepted.** The windows are hours to days; a validator can shift a timestamp by seconds only. Boundaries are tested exactly (at the limit and one second after). |

## History (worth mentioning in the viva)
- **High finding fixed by design: `arbitrary-send-erc20`.** The first draft pulled the dispute fee with `transferFrom(feePayer, ...)` where `feePayer` was passed in by the Registry. If the Registry ever misbehaved, it could take tokens from anyone who had approved the Court (for example a juror). Fix: the hunter now pays their own fee (`payDisputeFee`, tokens come from `msg.sender` only), and `openCase` just checks that the right person paid. The Court never pulls tokens from an address chosen by someone else.
- **Medium findings removed:** `incorrect-equality` on a zero sentinel (replaced by an `unstakePending` flag) and `divide-before-multiply` on the rounding dust (now a plain `%`).
- **Randomness without a modulo.** Jurors are drawn by giving every pool member a pseudo-random score and taking the lowest scores. No modulo, so no weak-randomness-by-modulo pattern, and no retry loops.

## Design choices worth defending in the viva
- The Court has no owner and no admin function; its rules are fixed at deployment.
- Rewards and slashes are bookkeeping on juror stakes, so one failing token transfer can never block a verdict.
- Votes are committed first and revealed later, so jurors cannot copy each other.
- The hunter and the company can never be drawn as jurors in their own case.
- A tie follows a written rule: after a rejection the company wins; after a company timeout the hunter wins.
