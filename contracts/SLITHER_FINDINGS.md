# SLITHER_FINDINGS.md (Phase 1: BountyToken, ReputationSBT, PlatformTreasury)

**Date:** 2026-11-08
**Tool:** Slither 0.11.6 (Python 3.13, Windows), Foundry 1.9.1-nightly (commit 7bff443b45b93efecfeae1779404d12a20f4c225), Solc 0.8.38
**Command (run from `contracts\`):** `slither . --filter-paths "test|script|lib"`
**Scope:** 26 contracts analysed with 102 detectors (includes imported OpenZeppelin base contracts); 5 results.

## Result: zero High findings (Phase 1 exit criterion met)

| # | Detector | Where | Severity (per Slither detector docs; confirm at the wiki link) | Decision |
|---|---|---|---|---|
| 1 | incorrect-equality | `BountyToken.faucet()`, `lastFaucetTime[msg.sender] == 0` | Medium | **Accepted (false positive).** The `== 0` check is an intentional "never claimed" marker so a first claim is always allowed. No funds depend on it. |
| 2 | timestamp | `BountyToken.faucet()`, cooldown uses `block.timestamp` | Low | **Accepted.** A validator can shift the timestamp by seconds only; the cooldown is long and the faucet is for testnet demo tokens. |
| 3 | missing-zero-check | `PlatformTreasury.withdrawEth(address,uint256)`, parameter `to` | Low | **OPEN, to fix.** Owner-only function; add `require(to != address(0))`. Re-run tests and Slither after the change. |
| 4 | reentrancy-events | `PlatformTreasury.withdrawEth`, event emitted after the external call | Low | **Accepted for now.** Only event ordering is flagged (no reentrancy of state or ETH reported). Owner-only. Optional hardening: emit before the call or add `nonReentrant`. |
| 5 | low-level-calls | `PlatformTreasury.withdrawEth`, `to.call{value: amount}("")` | Informational | **Accepted.** `call` with a checked `success` result is the recommended way to send ETH. |

## Foundry lint warnings seen during `forge build` (not Slither)
- `ReputationSBT.sol` lines ~119 and ~125: hand-written number-to-text code (uninitialized-local, unsafe-typecast). Optional: replace with OpenZeppelin `Strings.toString`.
- `BountyToken.sol`: `lastFaucetTime` changed without an event. Optional: add a `FaucetClaimed` event.

## Re-check
Re-run Slither after any contract change and update this table. Severity labels above come from my reading of the detector documentation; verify them at https://github.com/crytic/slither/wiki/Detector-Documentation before submission.
