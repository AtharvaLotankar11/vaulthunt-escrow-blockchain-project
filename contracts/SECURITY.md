# SECURITY.md

Security notes for VaultHunt (testnet prototype). Read with `LIMITATIONS.md`.
**Not audited. Testnet only. Never use real funds.**

## 1. What is protected, and how

| Risk | Mitigation | Where it is tested |
|---|---|---|
| A company steals a bug and rejects the report | The hunter's commit hash and timestamp prove who found it first; rejection keeps the reward locked; the hunter can go to a staked jury | `RegistryIntegration`, `RejectionAndDispute` |
| Another hunter copies a commit | The hash is bound to the hunter's address; the same hash cannot be committed twice; only the committing address can reveal | `RegistryFuzz` (4 tests) |
| Company drains a program while a report waits | Revealing a report **locks** its reward; the company can withdraw only unlocked funds | `EscrowFuzz`, `EscrowInvariant` |
| Company shrinks a reward after it was locked (found in Phase 5) | The lock records the pool size at lock time; payment never uses a smaller pool | `testWithdrawingAfterLockCannotShrinkTheReward`, a fuzz test |
| Anyone calls a payout function | Escrows obey only the Registry; the Registry restricts accept/reject to the program owner and verdicts to the Court | unit tests per contract |
| Reentrancy on payout | State is written before any ETH is sent; `nonReentrant` on every function that sends ETH; `payHunter` only credits, ETH moves in `claim`/`claimFor` | `testReentrancyIsBlockedDuring*` |
| A hostile hunter contract blocks a payout | `claimFor` gives the hunter at most 100k gas; failures leave the credit claimable; badge calls are gas-capped and failures never block a payout | `GasBurner`, `GasBurnReceiver`, `ContractHunter` tests |
| Court pulls tokens from someone who only approved it for staking | The Court never pulls from an address chosen by someone else; the hunter pays their own dispute fee | `testFeePaidBySomeoneElseDoesNotCount` |
| Jurors copy each other's votes | Commit first, reveal after the commit window | `DisputeCourt` tests |
| Jurors judge their own case | The hunter and the company are skipped when jurors are drawn | `testHunterAndCompanyAreNeverSelected` |
| Badge is bought or sold | Soulbound: every transfer path reverts | `SbtInvariant` |
| Someone takes over an escrow implementation | Its constructor locks `initialize`; clones can be initialized once | `DeployWiringTest` |
| Wiring done twice or by the wrong party | `setRegistry` and `setCourt` are one-time; the Registry owns the badge contract | `DeployWiringTest` |

## 2. Who can do what

| Contract | Privileged address | Powers |
|---|---|---|
| BountyEscrow (per program) | Registry | lock, pay (credit), release |
| BountyEscrow | Company (owner) | deposit, withdraw **unlocked** funds |
| ReportRegistry | Program owner | startReview, acceptReport, rejectReport (own program only) |
| ReportRegistry | Court | applyVerdict |
| ReportRegistry | Deployer (owner) | setCourt, once |
| BountyFactory | Deployer (owner) | setRegistry, once |
| ReputationSBT | Registry (owner after deployment) | mint, updateLevel |
| DisputeCourt | nobody (no owner, no admin) | rules fixed at deployment |
| PlatformTreasury | Deployer (owner) | withdraw ETH and tokens |
| ProgramDirectory | Each program's owner | publish or change that program's profile pointer (name, scope, public key); no funds, no admin |

The deployer keeps the token owner role and the Treasury. A production system would put these behind a multisig and timelock.

## 3. How the tests prove it

- **Unit and integration tests** for every contract and every revert path.
- **Scenario tests on the deployed wiring** (`FullHappyPath`, `RejectionAndDispute`, `TimeoutEscalation`): the whole platform wired by the same code the Deploy script uses.
- **Fuzz tests** (`EscrowFuzz`, `RegistryFuzz`, plus fuzz tests inside the escrow and court suites): random funding, tiers, severities, salts and event orders.
- **Invariant tests** (`EscrowInvariant`, `SbtInvariant`, `CourtInvariant`): random sequences of actions; after each step the rules below must hold:
  - the escrow always holds at least what is locked plus what hunters are owed
  - every wei that went into an escrow is accounted for
  - nothing locked is ever withdrawn
  - a badge never changes hands
  - the Court holds exactly stakes + prepaid fees + open-case fees + reserve
  - no case is resolved while votes are still hidden
  - a juror's open-case counter always matches reality
- **Mutation checks** (done by hand during Phase 5): each rule above was deliberately broken in the code, and the matching invariant failed as it should. Putting the Phase 2 reward bug back made four tests fail.

Test and Slither results are in the Audit Log of `milestone.md` (user-run).

## 4. Static analysis (Slither)
No High findings across the repository. Medium findings, all reviewed:

| Finding | Where | Decision |
|---|---|---|
| incorrect-equality | `BountyToken.faucet` (`lastFaucetTime == 0`) | False positive: intentional "never claimed" marker |
| reentrancy-no-eth | `ReportRegistry._updateBadge` writes `hasBadge` after the badge mint | Accepted: only reachable inside `nonReentrant` functions; the hook gets capped gas; its failure never blocks a payout |

Low and informational findings (timestamps, zero-address checks on owner-only functions, deliberate low-level calls, assembly in `claimFor`) are listed in `SLITHER_FINDINGS.md`, `SLITHER_FINDINGS_PHASE2.md`, `SLITHER_FINDINGS_PHASE3.md` and `SLITHER_FINDINGS_PHASE4.md`.

## 5. Problems found and fixed during development (good viva material)

| Phase | Found by | Problem | Fix |
|---|---|---|---|
| 2 | Slither (High) | `payHunter` sent ETH, then wrote state: reentrancy | `payHunter` only credits; ETH moves in `claim`/`claimFor`, state first |
| 4 | Slither (High) | Court pulled the fee from an address chosen by the Registry | The hunter pays their own fee (`payDisputeFee`) |
| 5 | A scenario test | A company could shrink a locked reward by withdrawing free funds before accepting | The lock remembers the pool size; payment uses the larger of lock-time and current pool |

## 6. Deploying safely

- **Local:** `anvil`, then `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <anvil account 0 key shown by anvil>`, then `forge script script/Seed.s.sol --rpc-url http://127.0.0.1:8545 --broadcast`. Anvil keys are public and worthless outside Anvil. Run Seed once per fresh Anvil.
- **Sepolia:** never put a real private key in a file or on the command line. Import a throwaway test wallet into a keystore once (`cast wallet import deployer --interactive`), then use `--account deployer`. `.env` is git-ignored; commit only `.env.example`.
- **Windows (cmd):** use `%VAR%`, never `$VAR`; inside PowerShell use `$env:VAR`.
- **Timing windows:** the demo defaults are 5 to 10 minutes (see `script/DeployBase.sol`). Use days for anything real (override with the `REVIEW_PERIOD`, `REVEAL_WINDOW`, `DISPUTE_WINDOW`, `COMMIT_PERIOD`, `COURT_REVEAL_PERIOD`, `UNSTAKE_COOLDOWN` environment variables, in seconds).
- Verify contracts on Etherscan with `--verify --etherscan-api-key <key>` (Phase 10).

## 7. Known limitations
See `LIMITATIONS.md`. The big ones: pseudo-random juror selection, a three-juror demo jury, the company decides the final severity, and report keys are re-wrapped for jurors in a simplified way.
