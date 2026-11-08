# VaultHunt: Milestone Tracker

**Project:** Decentralized Escrow System for Bug Bounty Hunters
**Network:** Ethereum Sepolia testnet (local Anvil for development)

## How to use this file

Every new chat starts with this exact opener: "Read tasks-docs\milestone.md fully, including its Protocol section, and follow it exactly. continue milestone"

The path is `tasks-docs\milestone.md`. Rules live in the Protocol section of this file. Type `continue milestone` in any new Kiro session. I will show you the next phase's prerequisites, then ask for your permission before starting work. A checkbox `[x]` means that phase passed its own exit checks AND the cumulative audit gate. Trust the process: one phase at a time, with evidence at every step.

### Phase Summary

| Phase | Name | Tasks | Prerequisites |
|---|---|---|---|
| 0 | Environment and repo scaffold | 9 | 4 |
| 1 | Token, Reputation SBT, Treasury contracts | 9 | 1 |
| 2 | Escrow and Factory contracts | 8 | 1 |
| 3 | Report Registry (commit-reveal) | 6 | 1 |
| 4 | Dispute Court and juror system | 7 | 1 |
| 5 | Deploy scripts, scenario/fuzz/invariant tests | 8 | 1 |
| 6 | Next.js scaffold, wagmi, RainbowKit, design tokens | 9 | 4 |
| 7 | Core flows (programs, submit, review, IPFS) | 9 | 3 |
| 8 | Dispute/jury UI, profile, leaderboard, live feed | 9 | 2 |
| 9 | Polish (motion, responsive, accessibility, demo) | 9 | 1 |
| 10 | Sepolia deployment and final audit | 7 | 4 |
| 11 | Documentation, report, presentation, demo video | 6 | 1 |
| **Total** | **12 phases** | **96 tasks** | **24 prerequisites** |

All phases have ≤10 tasks. Updated 2026-11-08 Batch 2.

---

## Protocol (ALWAYS FOLLOW)

You are the build assistant for the repo `vaulthunt-escrow-blockchain-project` (local path D:\vaulthunt-escrow-blockchain-project). The project is a decentralized escrow system for bug bounty hunters. You work phase by phase from this file (`tasks-docs/milestone.md`), with the user's permission at every phase. These rules live in this file because there is no separate steering file; read this whole Protocol section at the start of every session.

### 1. Source of truth (priority order)
1. The user's latest instruction in chat.
2. `tasks-docs/PRD.md` (what to build).
3. `tasks-docs/TechStack.md` (which tools; JavaScript, not TypeScript, in the web app).
4. `tasks-docs/design.md` (UI rules, exact colors, fonts).
5. `tasks-docs/milestone.md` (progress tracker only; it never overrides 1 to 4).

Never edit `PRD.md`, `TechStack.md` or `design.md` without asking. If you think one is wrong or incomplete, say so and propose the edit as "before -> after". `tasks-docs/milestone.md` is the exception: you update it as this protocol requires, but never edit this Protocol section without asking.

### 2. Anti-hallucination rules (strict)
- **Ground every decision.** Cite where it comes from, e.g. "(PRD section 7)". If the docs are silent, do NOT guess: add it to the `Assumptions` table in `milestone.md` as `PENDING` and ask the user.
- **Verify before use.** Before using any command, package, library function, contract API, or config key, check it is real:
  - Package: run `npm view <name> version`, or read it in `package.json` / `node_modules`.
  - Tool versions: run `<tool> --version` (node, pnpm, forge, anvil, git).
  - Library APIs (wagmi, viem, RainbowKit, OpenZeppelin, Next.js, Framer Motion): read the **installed** package's types, README, or source in `node_modules\` or `contracts\lib\` before writing code against them. If you cannot verify, write `UNVERIFIED` and ask.
- **Never invent**: contract addresses, private keys, API keys, URLs, download links, release asset names, package names, version numbers, function signatures, file contents you have not read, or test results.
- **Evidence over claims.** Never say "done", "passing" or "works" without having run the command in this session and quoting the key lines of its output. If you could not run something, say "NOT RUN" and why.
- **Verify every write.** After creating or editing any file, read it back (or the changed lines) and confirm the change is really there. Never say "created" or "updated" until you have confirmed it. If a file is missing after a write, say so immediately.
- **Read before edit.** Open a file before modifying it.
- **Say "I don't know"** when true. A clear question is better than a confident wrong answer.

### 3. The loop (follow in this exact order)

#### Step A: Orient (start of every session, or when the user says "continue milestone")
1. Read `tasks-docs/milestone.md` fully.
2. Find the first phase whose heading checkbox is `[ ]`. That is the **current phase**.
3. If any earlier phase has Status `REGRESSION`, that phase becomes current (fix first).
4. Reply with a short status (max 6 lines): phases done, current phase, last audit result. Then go to Step B.

#### Step B: Prerequisite briefing (manual work for the user)
1. Show only the **current phase's** prerequisites, as a short numbered list (max 5 items, plain language, copy-paste commands, each with "How to check it worked").
2. Run any **read-only checks** you can (version commands) and report what you found.
3. Ask: "Reply `done` when these are ready, or tell me where you're stuck." Then WAIT. Help with any stuck step patiently, one step at a time.
4. Do not create or change project files in this step.

#### Step C: Permission gate
Once prerequisites are verified, ask exactly:
**"Should I start Phase N: <phase name>?"**
Proceed only on an explicit yes ("yes", "start", "go ahead"). If unclear, ask again. Never start a phase without it.

#### Step D: Execute
- Set the phase Status to `IN_PROGRESS`.
- Do the phase's tasks **in order**. After each task: run its check, then tick its checkbox `[x]` only if the check passed.
- Work **only inside the current phase's scope**. Do not start, scaffold, or "prepare" later phases.
- Keep changes small and reviewable. Ask before installing anything not listed in `TechStack.md`.

#### Step E: Verify exit criteria
- Run every command under the phase's **Verification commands**. Quote the key output.
- If something fails: diagnose, fix, re-run. After 3 failed attempts on the same problem, STOP, explain what you tried, and ask the user. Do not tick anything.

#### Step F: Audit gate (cumulative, incremental)
After Phase N's own exit criteria pass, run **Audit Gate N**:
- Re-run the Verification commands of **every phase from 0 to N**, in order (Gate 1 checks 0 to 1, Gate 2 checks 0 to 2, and so on).
- Run the **global checks**:
  - Contracts: `forge build` clean and `forge test` all passing, once contracts exist.
  - Web app: `pnpm lint` and `pnpm build`, once it exists.
  - **Doc conformance:** contract names and responsibilities match PRD section 7; no `.ts` or `.tsx` files under `web\` (excluding `node_modules` and `.next`); every color value in `web\` comes from the design.md tokens (list any off-palette hex); fonts and weights match design.md.
  - **Secrets hygiene:** `.env` is git-ignored; no private keys, API keys or JWTs appear in tracked files.
- Record the result as a new row in the **Audit Log** table (date, gate, commands run, PASS/FAIL, notes).
- **If everything passes:** set the phase Status to `DONE` and tick the phase heading checkbox `[x]`. Only now.
- **If an earlier phase fails:** set that phase's heading back to `[ ]`, Status `REGRESSION`, log it, and fix it before any new work.

#### Step G: Close and hand off
Give a summary (max 10 lines): what was built, files created or changed, how the user can try it, audit result. Then show the **next** phase's prerequisites (back to Step B). Do not start the next phase.

### 4. Anti-avalanche rules
- **One phase at a time.** Never work on two phases in one go.
- **Interface freeze.** Once a phase is DONE, its public interfaces (contract function signatures, events, ABI, exported component props, file paths other phases depend on) are frozen. A change needs: (1) user approval, (2) a Change Log entry, (3) re-running the audit gate for dependent phases.
- **Minimal fixes.** When fixing a regression, change the smallest amount of code and list exactly which files were touched.
- **No silent scope creep.** Extra ideas go into the `Parking Lot`, not into code.
- **Split big phases.** No phase may have more than 10 tasks. If a phase or task grows too large, propose a split and wait for approval.

### 5. Safety rules
- Local (Anvil) and **Sepolia testnet only**. Never mainnet. Never real funds.
- Never print, log, commit, or ask the user to paste a private key or API secret into chat. Use `.env` (git-ignored) and commit only `.env.example` with empty values.
- Never run destructive commands (`Remove-Item -Recurse -Force`, `git reset --hard`, `git push --force`, deleting directories) without asking first. Ask before any `git commit` or `git push`; propose the commit message.
- Never recommend "Always allow" for shell commands.
- Never change PATH, the registry, or files outside this repo yourself. Give the user the command and let them run it.

### 6. Communication style
- Friendly, calm, short. Plain language; explain jargon in one line the first time.
- One thing at a time. At most one question per message, except the prerequisite checklist.
- Small numbered steps; tell the user how to confirm each step worked.
- No walls of text. No more than 5 manual steps at once.
- When the user pastes terminal output, read it fully and say what it proves before moving on.

### 7. `milestone.md` rules
- Heading checkbox `[ ]` = not finished; `[x]` = finished AND audited. This is the only meaning.
- Each phase has a `Status:` line with exactly one of: `NOT_STARTED`, `PREREQS`, `IN_PROGRESS`, `AUDITING`, `DONE`, `REGRESSION`.
- Update `tasks-docs/milestone.md` immediately after each task, not in batches.
- Keep the Assumptions, Audit Log, Change Log and Parking Lot tables current. Every assumption goes into the table the moment you make it.

### 8. Environment and command rules (Windows cmd.exe shell, user has PowerShell 5.1)
- **Shell fact:** Kiro's `execute_pwsh` tool runs **cmd.exe** (verified: `echo %ComSpec%` → `C:\WINDOWS\system32\cmd.exe`). The user runs **PowerShell 5.1** in their own terminal (verified: Major 5, Minor 1, Build 26100).
- **Absolute paths for --root and --dir:** Always use absolute paths like `--root D:\vaulthunt-escrow-blockchain-project\contracts` or `--dir D:\vaulthunt-escrow-blockchain-project\web`. Relative paths can create nested folders (verified: relative `--root contracts` created `contracts\contracts\contracts`). When running Verification commands, replace `--root contracts` with `--root D:\vaulthunt-escrow-blockchain-project\contracts`.
- **Verification command rule for ALL phases:** Write one command per line. No `;` chaining, no `&&`. Plain tools (forge, anvil, cast, pnpm, git, node) run as-is. Use `forge --root D:\vaulthunt-escrow-blockchain-project\contracts <cmd>` and `pnpm --dir D:\vaulthunt-escrow-blockchain-project\web <cmd>` (verified: pnpm supports `--dir` and `-C`) instead of `cd`. Any PowerShell cmdlet (Get-ChildItem, Select-String, Get-Content, Start-Process, Where-Object) must be wrapped: `powershell -NoProfile -Command "..."`.
- Never use bash/cmd hybrid syntax: no `&&`, `grep`, `dir /b`, `type`, `findstr`, `%VAR%`, `anvil &`, `export`, `source`. Use PowerShell equivalents wrapped as above.
- **Installing tools:** give instructions ONLY from official documentation you fetched in this session, and name the page. Never construct, guess or "remember" download URLs, release asset names, package-manager package names or installer names. If the official method does not work on Windows, say so plainly and ask the user.
- Never offer to skip, reorder or defer a phase or a prerequisite. If a prerequisite is blocked, help unblock it or ask.
- If a file or folder is missing, do not recreate it. Ask the user where it is; they may have moved it.

### 9. Working on large edits
- Do large changes in batches. After each batch, list what changed, verify by reading back, then stop and wait for the user to say `next batch`.
- Never stop silently. If you cannot finish, report exactly what is done, what is not, and say how to resume.
- Do not paste whole files into replies; show only the changed parts.

## Assumptions

| ID | Assumption | Status | Resolution |
|---|---|---|---|
| A-1 | Juror count: 3 for demo, stored as configurable constant | RESOLVED | User-approved R1 |
| A-2 | Testnet: Ethereum Sepolia | RESOLVED | User-approved R1 |
| A-3 | Fonts: system fallbacks until licenses confirmed for Telegraf and Open Sauce One; document in DESIGN_NOTES.md | RESOLVED | User-approved R1 |
| A-4 | Foundry on Windows: native PowerShell (no WSL, no Git Bash) | RESOLVED | User-approved R1 |
| A-5 | zk-SNARK stretch goal: out of scope | RESOLVED | User-approved R1 |
| A-6 | Foundry nightly manual install: forge/anvil/cast v1.9.1-nightly commit 7bff443b45b93efecfeae1779404d12a20f4c225 from GitHub nightly zip into C:\Users\Manoj\.foundry\bin | OPEN | Review at Phase 5 if tests behave oddly; first suggestion is to switch to latest stable release |
| A-7 | Environment versions: Node v24.22.0, Git 2.45.2.windows.1, pnpm 12.18.0, PowerShell 5.1 | RESOLVED | Verified in session 2026-11-08 |
| A-8 | Design decisions D1-D4 (commit-reveal flow, access control, timeouts, soulbound implementation) | RESOLVED | User-approved R1 |
| A-9 | Slither static analysis: confirmed working on Windows with slither --version 0.11.6 | RESOLVED | Tested at Phase 0, will verify on real contracts in Phase 1 |

---

## Audit Log

| Date | Gate | Commands Run | Result | Notes |
|---|---|---|---|---|
| 2026-11-08 | Gate 0 | forge build, verify folders, check .gitignore, verify no .env | PASS | All tools verified, folders created, OpenZeppelin v5.7.0 installed, no secrets in tracked files |
| 2026-11-08 | Gate 1 | forge test 33/33, coverage 98.59% lines, slither 0 High (user-run) | PASS | BountyToken, ReputationSBT, PlatformTreasury complete with tests, soulbound verified, no HIGH findings |
| 2026-11-08 | Gate 2 | forge test 99/99, coverage 99.5% lines, slither 0 High (user-run) | PASS | BountyFactory and BountyEscrow complete, pull-payment pattern, reentrancy-safe |
| 2026-11-08 | Gate 3 | forge test 176/176, coverage 99.75% lines, slither 0 High (user-run) | PASS | ReportRegistry with commit-reveal, severity locking, badge minting, state machine complete |
| 2026-11-08 | Gate 4 | forge test 254/254, coverage 99.84% lines, slither 0 High (user-run) | PASS | DisputeCourt with staking, voting, verdict application, tie-break rules complete |
| 2026-11-08 | Gate 5 | forge test 289/289, coverage 99.82% lines, slither 0 High, Deploy and Seed run on Anvil (user-run) | PASS | evidence in SECURITY.md |
| 2026-11-08 | Phase 6-7 | pnpm lint and build OK; program created, encrypted report submitted, accepted and paid on Anvil (user-run) | PASS | App loads, wallet connects, live chain data, Report #1 Paid, Badge #0, 50 XP verified |

---

## Change Log

| Date | Phase | Change | Reason | Affected Phases |
|---|---|---|---|---|
| 2026-11-08 | All | Convert all verification commands to PowerShell 5.1 syntax | Windows environment, no WSL/Git Bash | 0-10 |
| 2026-11-08 | 0 | Update prerequisites: removed Git Bash/WSL, added MetaMask, Slither with Windows-specific instructions, heads-up about Sepolia faucet | Verified Windows-native setup | 0 |
| 2026-11-08 | 0 | Add task to record Foundry nightly version and commit SHA in README | Track nightly build for troubleshooting | 0 |
| 2026-11-08 | 0 | Fix doc reference: TechStack section 6 not 7 for repository layout | Correct documentation reference | 0 |
| 2026-11-08 | 1 | Update ReputationSBT to use _update hook (OpenZeppelin v5) for soulbound; add tests for transferFrom, safeTransferFrom, approve-then-transfer | D4: correct soulbound implementation | 1, tests |
| 2026-11-08 | 2 | Update BountyEscrow to use initialize() not constructor (EIP-1167 clone); only Registry address can call lock/pay/refund | D2: access control pattern | 2, 3, 4, 5 |
| 2026-11-08 | 3 | Update commit-reveal flow: hash contentHash first, then encrypt and upload; commitHash = keccak256(abi.encode(contentHash, salt, hunter)); reveal checks both contentHash and salt | D1: correct commit-reveal sequence | 3, 7 |
| 2026-11-08 | 3 | Registry is single orchestrator: company calls acceptReport/rejectReport on Registry (not Escrow); Registry pays through Escrow and updates SBT; add escalateAfterTimeout | D2: access control, D3: timeout handling | 3, 4, 5, 7 |
| 2026-11-08 | 4 | DisputeCourt calls Registry.applyVerdict (not Escrow directly); add setRegistry one-time setter; juror count N=3 as configurable constant | D2: access control, A-1: juror count | 4, 5 |
| 2026-11-08 | 5 | Deploy script reads Anvil first account key at runtime, stores in .env (git-ignored), never hard-codes in tracked files | Security: no private keys in repo | 5, 10 |
| 2026-11-08 | 5 | Add Seed.s.sol script: funds test accounts, gives BBT, stakes 3 jurors | Simplify Phase 8 prerequisite | 5, 8 |
| 2026-11-08 | 6 | Use web/src/app, web/src/lib, web/src/contracts structure with --src-dir flag | TechStack section 6 folder layout | 6-9 |
| 2026-11-08 | 6 | Add prerequisite: configure MetaMask with Anvil local network (RPC http://127.0.0.1:8545, Chain ID 31337) | UI testing requirement | 6 |
| 2026-11-08 | 6 | Add task: check Tailwind major version; if v4, use CSS @theme instead of tailwind.config.js; log deviation | Adapt to current Tailwind | 6 |
| 2026-11-08 | 6 | Verify shadcn init options for JavaScript project before use | Avoid TypeScript-only flags | 6 |
| 2026-11-08 | 6 | Note WalletConnect cloud may be rebranded (check cloud.walletconnect.com or cloud.reown.com) | Current branding may differ | 6 |
| 2026-11-08 | 0 | Expand Slither prerequisite: require Python 3.10+, list installation methods (pip, uv, Docker, source), Windows-native Python+pip simplest | Slither official docs (github.com/crytic/slither, 2026-11-08), no WSL required | 0 |
| 2026-11-08 | 7 | Update JWT verification command to PowerShell Select-String syntax | Windows PowerShell environment | 7 |
| 2026-11-08 | 7 | Clarify commit-reveal order in tasks: contentHash→commitHash→encrypt/upload→reveal; Registry.acceptReport not Escrow.acceptReport | D1, D2: correct sequence and access control | 7 |
| 2026-11-08 | 8 | Change prerequisite from "deploy and fund accounts" to "run Seed script" | Seed.s.sol added in Phase 5 | 8 |
| 2026-11-08 | 8 | Add task: implement escalateAfterTimeout in Registry | D3: explicit timeout handling | 8 |
| 2026-11-08 | 9 | Restrict demo mode to Anvil only; do not use demo mode on Sepolia or with private keys in client code | Security: no real keys in client | 9 |
| 2026-11-08 | 6 | Mark next.js flags, Tailwind v4 behavior, shadcn init options, WalletConnect branding as UNVERIFIED until Phase 6 start | Defer verification to phase execution | 6 |
| 2026-11-08 | 0,7 | Fix Select-String syntax: replace "Select-String -Path X -Pattern Y -Recurse" with "Get-ChildItem X -Recurse -File | Select-String -Pattern Y" | Select-String has no -Recurse parameter in PowerShell | 0, 7 |
| 2026-11-08 | 0 | Revise Slither prerequisite: mark UNVERIFIED on Windows, add fallback plan (skip local Slither, rely on Foundry fuzz/invariant, optionally run in Linux CI) | Slither docs don't specify Windows support; safer to test first | 0 |
| 2026-11-08 | A-9 | Add Assumption A-9 for Slither fallback plan if Windows installation fails | Track decision about static analysis alternatives | 0, 1 |
| 2026-11-08 | 5 | Merge tasks: combine Deploy.s.sol + Seed.s.sol writes, combine their runs, merge 3 scenario tests, merge fuzz+invariant tests (13 tasks → 8 tasks) | Reduce task count per phase to ≤10 | 5 |
| 2026-11-08 | 6 | Merge tasks: combine Next.js init + Tailwind check, combine deps install + shadcn, combine CSS + Tailwind config, combine sync-abis write + run (13 tasks → 9 tasks) | Reduce task count per phase to ≤10 | 6 |
| 2026-11-08 | 8 | Merge tasks: combine 3 page creations, combine LiveFeed + toast + integration, combine 3 test tasks (11 tasks → 5 tasks) | Reduce task count per phase to ≤10 | 8 |
| 2026-11-08 | 0,1 | Delete forge init samples (Counter.sol, Counter.t.sol, Counter.s.sol) before Phase 1 work | Clean slate for actual contracts | 1 |
| 2026-11-08 | Phase 2 | payHunter now only credits; ETH is sent by claimFor or claim | Slither reentrancy-eth High | 3, 4, 5, 7, 8 |
| 2026-11-08 | Phase 3 | Registry: reveal takes claimedSeverity (5 args); Accepted is folded into Paid and Closed into Refunded; review, reveal and dispute windows are constructor settings; Registry must own ReputationSBT | timeout disputes need a severity to lock; short demo windows | 3,4,5,7,8 |
| 2026-11-08 | Phase 3 | Revealing a report locks its reward; badge and ETH-push failures never block a payout | protects hunters and tolerates hostile hunter contracts | 5,7,9 |
| 2026-11-08 | Phase 4 | Hunter pays the dispute fee with payDisputeFee before registry.escalate (approve, payDisputeFee, escalate) | Slither High arbitrary-send-erc20 | 5,7,8 |
| 2026-11-08 | Phase 4 | Court has no owner; tie after rejection goes to the company, after timeout to the hunter; verification contract is DisputeScenarios | design choice; matches the milestone command | 5,8 |
| 2026-11-08 | 5 | BountyEscrow: payout uses the pool size recorded at lock time (never smaller) | scenario test found that withdrawing free funds could shrink a locked reward | 2, 3, 4, 7 |
| 2026-11-08 | 5 | Deploy.s.sol signs with --private-key or --account; local windows are minutes; addresses go to contracts\deployments\<chainId>.json | safer and demo-friendly | 6, 9, 10 |
| 2026-11-08 | Phase 6 | RainbowKit dropped; wallet button built on wagmi's injected connector; wagmi pinned ^2.19.5 | RainbowKit 2.2.x needs wagmi 2 and its connectors break the Next.js 16 build | 7,8,9 |
| 2026-11-08 | Phase 6 | Tailwind v4 CSS tokens; shadcn/ui deferred; pnpm-workspace.yaml allowBuilds; fonts use fallbacks (A-3); glass arc is SVG | v4 is CSS-first; pnpm 12 needs build approvals; no font files or image assets | 6,7,9 |
| 2026-11-08 | Phase 7 | 8th contract ProgramDirectory; reports and profiles via /api/ipfs (local store, Pinata if PINATA_JWT is set); useTx adds 30% gas headroom | contracts had nowhere to store the name and public key; works without any account; juror-draw gas varies | 8,10 |

---

## Parking Lot

| Idea | Proposed By | Notes |
|---|---|---|
| | | |

---

## [x] Phase 0: Environment and repo scaffold

**Status:** DONE

**Goal:** Verify all tools are installed and working. Set up the repository folder structure, ignore files, environment template, and documentation skeleton. No contract or app code yet.

**Docs:** TechStack.md section 6 (repository layout), PRD.md section 10 (stack)

**Prerequisites (manual, for the user):**

1. **Verify installed tools.** I will check: Node v24.22.0, Git 2.45.2, pnpm 12.18.0, Foundry forge/anvil/cast v1.9.1-nightly (commit 7bff443b45b).
   **How to check:** I'll run version commands and record them in README.

2. **Install MetaMask browser extension.** Download from [metamask.io](https://metamask.io) and create a throwaway test wallet. Never use a wallet with real funds for development.
   **How to check:** Open MetaMask, see a new wallet with 0 ETH.

3. **Install Python 3.10+ and Slither** (static analysis tool). Slither official docs (github.com/crytic/slither README, fetched 2026-11-08) require Python 3.10+ and can be installed via: `pip install slither-analyzer`, `uv tool install slither-analyzer`, Docker (`trailofbits/eth-security-toolbox`), or from source. UNVERIFIED on Windows. I will test `slither --version` at Phase 1 to confirm it works. If it fails, tell me and I will record the fallback in Assumptions: skip local Slither, rely on Foundry fuzz and invariant tests, optionally run Slither in a Linux GitHub Actions workflow.
   **How to check:** Run `python --version` (should show 3.10+), `pip --version`, then `pip install slither-analyzer`, then `slither --version`.

4. **Optional heads-up:** Sepolia faucets can be slow (may take hours). When Phase 10 arrives, you'll need testnet ETH. Bookmark a faucet like [sepoliafaucet.com](https://sepoliafaucet.com) or Alchemy's faucet now.

**Tasks:**

- [x] Verify tool versions (forge, anvil, cast, node, pnpm, git) and record them in README with forge/anvil/cast commit SHA; note nightly vs stable
- [x] Create `contracts/` folder and initialize Foundry project with `forge init`
- [x] Install OpenZeppelin contracts: `forge install OpenZeppelin/openzeppelin-contracts`
- [x] Create `web/` folder (empty for now, will initialize in Phase 6)
- [x] Create `.gitignore` at repo root (ignore `node_modules/`, `.env`, `out/`, `cache/`, `broadcast/`, `.next/`)
- [x] Create `.env.example` at repo root with empty placeholders: `SEPOLIA_RPC=`, `PRIVATE_KEY=`, `ETHERSCAN_API_KEY=`, `PINATA_JWT=`, `NEXT_PUBLIC_WALLETCONNECT_ID=`
- [x] Create `README.md` skeleton: project title, one-line description, folder structure, setup steps (to be filled), tool versions
- [x] Reference `tasks-docs/` folder in README (note: already exists, contains PRD.md, TechStack.md, design.md, milestone.md)
- [x] Confirm `foundry.toml` has reasonable defaults (solc version 0.8.x, optimizer enabled)

**Exit Criteria:**
- Folders `contracts/`, `web/`, `tasks-docs/` exist
- `forge build` runs without errors (even if no contracts yet, default Foundry scaffold compiles)
- `.gitignore` and `.env.example` are present
- README lists the folder layout and mentions the three docs
- No tracked files contain secrets

**Verification Commands:**
```powershell
forge --version
node --version
pnpm --version
git --version
powershell -NoProfile -Command "Get-ChildItem contracts -Name"
powershell -NoProfile -Command "Get-ChildItem web -Name"
forge $1 --root contracts build
powershell -NoProfile -Command "Get-Content .gitignore"
powershell -NoProfile -Command "Get-Content .env.example"
powershell -NoProfile -Command "Get-Content README.md"
```

---

## [x] Phase 1: Token, Reputation SBT, Treasury contracts and tests

**Status:** DONE

**Goal:** Implement and test the three foundational contracts: BountyToken (ERC-20 for staking/fees), ReputationSBT (ERC-721 soulbound for hunter badges), and PlatformTreasury (holds fees and slashed stakes). These have no dependencies on other contracts.

**Docs:** PRD.md section 7 (contracts 1, 6, 7)

**Prerequisites (manual, for the user):**

1. **Confirm OpenZeppelin is installed.** Navigate to `contracts/` in PowerShell and run:
   ```powershell
   forge remappings
   ```
   **How to check:** You should see a line like `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`.

**Tasks:**

- [ ] Write `BountyToken.sol` (ERC-20): constructor mints initial supply to deployer, includes a `faucet()` function for testnet (mints small amount per call, rate-limited or open for demo)
- [ ] Write unit tests for BountyToken: transfer, faucet, balance checks
- [ ] Write `ReputationSBT.sol` (ERC-721): overrides `_update` hook (OpenZeppelin v5) to revert on transfers (allows mint when from == address(0), reverts otherwise for soulbound behavior), stores level and XP per tokenId, has `mint(hunter)` and `updateLevel(tokenId, newLevel, newXP)` restricted to owner/manager role
- [ ] Write unit tests for ReputationSBT: mint, attempt transferFrom (should revert), attempt safeTransferFrom (should revert), attempt approve-then-transfer (should revert), update level, tokenURI logic
- [ ] Write `PlatformTreasury.sol`: holds ETH and tokens, has `deposit()` payable, `withdraw(token, amount, to)` restricted to owner, emits events
- [ ] Write unit tests for PlatformTreasury: deposit ETH, withdraw ETH, access control
- [ ] Run all tests and confirm 100% pass
- [ ] Run `forge coverage` and check line coverage (target 85%+ for these three)
- [ ] Run Slither on these three contracts: `slither contracts/src/ --filter-paths "test|script"` (fix any HIGH findings; document MEDIUM/LOW)

**Exit Criteria:**
- Three contracts compile with no errors or warnings
- All unit tests pass (`forge test`)
- Coverage is 85% or higher for these contracts
- Slither reports zero HIGH findings (MEDIUM/LOW noted in a `SLITHER_FINDINGS.md` if any)
- Contracts follow PRD section 7 specs: BountyToken is ERC-20, ReputationSBT is non-transferable ERC-721, Treasury has deposit/withdraw

**Verification Commands:**
```powershell
forge $1 --root contracts build
forge $1 --root contracts test --match-path test/BountyToken.t.sol -vv
forge $1 --root contracts test --match-path test/ReputationSBT.t.sol -vv
forge $1 --root contracts test --match-path test/PlatformTreasury.t.sol -vv
forge $1 --root contracts coverage --report summary
slither contracts\src\ --filter-paths "test|script" --exclude naming-convention,similar-names
```

---

## [x] Phase 2: BountyFactory and BountyEscrow contracts and tests

**Status:** DONE

**Goal:** Implement the factory that creates program escrows (EIP-1167 minimal proxies) and the escrow contract that locks funds, tracks severity tiers, and releases payment. Test creation, funding, and basic payout flows.

**Docs:** PRD.md section 7 (contracts 2, 3), PRD.md section 6.1 (happy path)

**Prerequisites (manual, for the user):**

1. **Phase 1 must be DONE.** Check `milestone.md` that Phase 1's heading is `[x]`.
   **How to check:** Status line for Phase 1 reads `DONE`.

**Tasks:**

- [ ] Write `BountyEscrow.sol`: EIP-1167 clone with `initialize(registry, owner)` (not constructor), holds funds for one program, stores severity payout percentages (Low, Med, High, Critical as basis points), `deposit()` payable by owner, `lock(reportId, severity)` locks amount for a report, `payHunter(reportId, hunter, severity)` with reentrancy guard and pull-payment, `refundCompany(reportId)`, access-controlled so only the Registry address (set in initialize) can call lock/payHunter/refundCompany; owner can withdraw only unlocked funds
- [ ] Write unit tests for BountyEscrow: initialize, deposit, lock funds for report, pay hunter (only Registry), refund (only Registry), attempt reentrancy (should fail), non-Registry attempt pay (should revert), owner withdraw unlocked funds
- [ ] Write `BountyFactory.sol`: uses OpenZeppelin Clones (EIP-1167) to deploy BountyEscrow instances cheaply, stores mapping of programId to escrow address, `createProgram(owner, severities) returns (address escrow)`, emits ProgramCreated event
- [ ] Write unit tests for BountyFactory: create program, verify escrow address, create multiple programs, check registry
- [ ] Run integration test: Factory creates escrow, company deposits ETH, escrow locks and pays (mock Registry address for now)
- [ ] Run all tests (`forge test`) and confirm pass
- [ ] Run `forge coverage` on Factory and Escrow (target 85%+)
- [ ] Run Slither on Factory and Escrow, fix HIGH, document others

**Exit Criteria:**
- BountyFactory and BountyEscrow compile and deploy
- All unit and integration tests pass
- Coverage 85%+ on these two contracts
- Slither shows zero HIGH findings
- Escrow correctly locks/pays/refunds, Factory clones work, no reentrancy possible

**Verification Commands:**
```powershell
forge $1 --root contracts build
forge $1 --root contracts test --match-path test/BountyEscrow.t.sol -vv
forge $1 --root contracts test --match-path test/BountyFactory.t.sol -vv
forge $1 --root contracts test --match-contract IntegrationTest -vv
forge $1 --root contracts coverage --report summary
slither contracts\src\BountyFactory.sol contracts\src\BountyEscrow.sol --filter-paths "test|script"
```

---

## [x] Phase 3: ReportRegistry with commit-reveal and tests

**Status:** DONE

**Goal:** Implement the ReportRegistry contract that stores report hashes (commit), then CIDs and status (reveal), tracks timestamps for priority, and manages the report state machine. Test commit-reveal flow, duplicate detection, and state transitions.

**Docs:** PRD.md section 7 (contract 4), PRD.md section 6.1 and 6.2 (flows), PRD.md section 12 (security)

**Prerequisites (manual, for the user):**

1. **Phases 1 and 2 must be DONE.**
   **How to check:** Both have `[x]` and Status `DONE`.

**Tasks:**

- [ ] Write `ReportRegistry.sol`: storage per reportId (commitHash, contentHash, timestamp, CID, salt, hunter, programId, severity, status), owner/company functions `startReview(reportId)`, `acceptReport(reportId, severity)` which pays through Escrow and updates ReputationSBT (Registry holds manager role), `rejectReport(reportId)`; hunter functions `commitReport(programId, commitHash)` stores commitHash and timestamp, emits Committed event; `revealReport(reportId, cid, contentHash, salt)` checks `keccak256(abi.encode(contentHash, salt, msg.sender)) == commitHash`, stores CID and contentHash, sets status to Revealed, emits Revealed event; `escalateAfterTimeout(reportId)` callable by hunter or anyone after reviewDeadline passes without company action, forwards to DisputeCourt; status transitions: Committed -> Revealed -> UnderReview -> Accepted/Rejected -> Paid/Closed/Disputed; DisputeCourt calls `applyVerdict(reportId, hunterWins)` which then pays or refunds through Escrow
- [ ] Write unit tests: commit report, reveal with correct salt and contentHash (pass), reveal with wrong salt (revert), reveal with wrong contentHash (revert), commit two reports for same program (both valid), reveal earlier commit when conflict (earlier wins by timestamp), attempt to reveal twice (revert), company startReview, acceptReport (pays hunter, mints/updates SBT), rejectReport, escalateAfterTimeout (only after deadline with vm.warp), unauthorized status change (revert), Registry-only access on Escrow
- [ ] Write integration test: commit, reveal, mock company accepts (Registry -> Escrow pays)
- [ ] Run all Registry tests, confirm pass
- [ ] Run `forge coverage` (target 85%+)
- [ ] Run Slither on Registry, fix HIGH, document others

**Exit Criteria:**
- ReportRegistry compiles and passes all tests
- Commit-reveal logic works: wrong salt reverts, correct salt passes
- Duplicate/priority logic: earliest commit timestamp is source of truth
- State machine enforced: cannot skip states, only authorized callers change status
- Coverage 85%+, zero HIGH Slither findings

**Verification Commands:**
```powershell
forge $1 --root contracts build
forge $1 --root contracts test --match-path test/ReportRegistry.t.sol -vv
forge $1 --root contracts test --match-contract RegistryIntegration -vv
forge $1 --root contracts coverage --report summary
slither contracts\src\ReportRegistry.sol --filter-paths "test|script"
```

---

## [x] Phase 4: DisputeCourt with staked jury voting and tests

**Status:** DONE

**Goal:** Implement the DisputeCourt contract: juror staking in BountyToken, case escalation, commit-reveal voting, majority verdict, reward/slash logic. Test voting scenarios with 3 and 5 jurors, edge cases (ties, abstentions).

**Docs:** PRD.md section 7 (contract 5), PRD.md section 6.2 (dispute path), PRD.md section 12 (security)

**Prerequisites (manual, for the user):**

1. **Phases 1, 2, and 3 must be DONE.**
   **How to check:** All three have `[x]` and Status `DONE`.

**Tasks:**

- [ ] Write `DisputeCourt.sol`: juror registry (address -> staked amount in BountyToken, active status), `stakeAsJuror(amount)` transfers BBT to contract, `unstakeJuror()` with cooldown, `escalateDispute(reportId, disputeFee)` called by Registry after hunter escalates or timeout, picks 3 jurors pseudo-randomly from active pool (configurable constant N=3), stores case (reportId, jurors, votes, status), `commitVote(caseId, voteHash)`, `revealVote(caseId, vote, salt)` checks hash, `resolveCaseAfterReveal(caseId)` counts votes, majority wins, calls `Registry.applyVerdict(reportId, hunterWins)` (Registry then pays or refunds through Escrow), rewards winning jurors from Treasury, slashes losing jurors, emits Resolved event with verdict; one-time owner-only `setRegistry(address)` to resolve circular dependency at deploy
- [ ] Write unit tests: stake as juror, unstake, escalate dispute from Registry (picks jurors), commit vote, reveal vote, resolve with majority (hunter wins), resolve with majority (company wins), tie-break rule (document in contract if tie means company wins or requires re-vote), slash and reward logic, attempt to vote twice (revert), non-juror vote (revert), Court calls Registry.applyVerdict not Escrow
- [ ] Write scenario tests: 3 jurors all vote same way, 3 jurors 2-1 split, 5 jurors 3-2 split, juror stakes then immediately unstakes (cooldown enforced)
- [ ] Run all Court tests, confirm pass
- [ ] Run `forge coverage` (target 85%+)
- [ ] Run Slither on DisputeCourt, fix HIGH, document others
- [ ] Document limitation in code comments: juror selection uses block.timestamp and other chain data for pseudo-randomness (not VRF); acceptable for academic demo, not production

**Exit Criteria:**
- DisputeCourt compiles and passes all tests
- Staking, voting, reveal, resolve all work
- Majority verdict correctly pays hunter or refunds company
- Reward/slash math correct
- Coverage 85%+, zero HIGH Slither findings
- Randomness limitation documented in contract and in a `LIMITATIONS.md`

**Verification Commands:**
```powershell
forge $1 --root contracts build
forge $1 --root contracts test --match-path test/DisputeCourt.t.sol -vv
forge $1 --root contracts test --match-contract DisputeScenarios -vv
forge $1 --root contracts coverage --report summary
slither contracts\src\DisputeCourt.sol --filter-paths "test|script"
powershell -NoProfile -Command "Get-Content contracts\LIMITATIONS.md"
```

---

## [x] Phase 5: Contracts integration, scenario tests, security pass, local deploy script

**Status:** DONE

**Goal:** Wire all 7 contracts together with correct permissions and references. Write end-to-end scenario tests for happy path, rejection, timeout, dispute. Run full security suite (Slither on all contracts, fuzz tests, invariant tests). Create a Foundry deploy script for Anvil. Aim for 90%+ coverage overall.

**Docs:** PRD.md section 6 (user flows), PRD.md section 7 (contract interaction map), PRD.md section 13 (testing), TechStack.md section 7 (deploy script)

**Prerequisites (manual, for the user):**

1. **Phases 1, 2, 3, and 4 must be DONE.**
   **How to check:** All four have `[x]` and Status `DONE`.

**Tasks:**

- [x] Write deployment scripts: `Deploy.s.sol` (deploys all 7 contracts, sets up permissions, reads Anvil key at runtime, outputs addresses to JSON) and `Seed.s.sol` (funds 5 test accounts, mints BBT, stakes 3 as jurors)
- [x] Run deployment and seed scripts on Anvil: Start-Process anvil -WindowStyle Minimized, wait 3s, run Deploy.s.sol and Seed.s.sol with `--fork-url http://127.0.0.1:8545 --broadcast`, confirm addresses logged
- [x] Write scenario tests: `FullHappyPath.t.sol` (create program, commit, reveal, accept, pay, mint SBT), `RejectionAndDispute.t.sol` (reject, escalate, 3 jurors vote, resolve), `TimeoutEscalation.t.sol` (company silent, escalateAfterTimeout, jury resolves)
- [x] Write fuzz and invariant tests: fuzz Escrow deposit amounts and severities; invariants "Escrow balance >= locked amounts", "SBT non-transferable", "Court cannot resolve with hidden votes"
- [x] Run all tests including scenarios, fuzz, invariants: `forge test -vv`
- [x] Run `forge coverage` on entire `src/` (target 90%+)
- [x] Run Slither on all contracts, fix any new HIGH findings, document final state
- [x] Create or update `SECURITY.md`: summary of mitigations, test results, Slither summary, known limitations (juror randomness)

**Exit Criteria:**
- Deploy script works on Anvil and outputs addresses
- All scenario tests pass (happy, rejection, timeout, dispute)
- Fuzz and invariant tests pass
- Overall coverage 90%+
- Slither full-repo scan shows zero HIGH findings
- SECURITY.md and LIMITATIONS.md are complete

**Verification Commands:**
```powershell
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts --match-contract FullHappyPath -vvv
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts --match-contract RejectionAndDispute -vvv
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts --match-contract TimeoutEscalation -vvv
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts --match-contract Fuzz -vv
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts --match-contract Invariant -vv
forge test --root D:\vaulthunt-escrow-blockchain-project\contracts -vv
forge coverage --root D:\vaulthunt-escrow-blockchain-project\contracts --report summary --no-match-coverage "script|test"
```

USER-RUN (needs a running Anvil in another terminal and its account 0 key): from the contracts folder run forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <anvil account 0 key>, then forge script script/Seed.s.sol --rpc-url http://127.0.0.1:8545 --broadcast. Slither is also user-run: from the contracts folder, slither . --filter-paths "test|script|lib".

---

## [x] Phase 6: Frontend foundation (Next.js JavaScript, design tokens and fonts per design.md, layout, wallet connect, sync-abis.js script)

**Status:** DONE

**Goal:** Initialize the Next.js app in `web/`, install dependencies (wagmi, viem, RainbowKit, Tailwind, shadcn/ui, Framer Motion), set up design tokens (colors, fonts, spacing) from design.md, create global layout with navigation and wallet connect button, write and test the `sync-abis.js` script that copies ABIs and addresses from Foundry output to the frontend.

**Docs:** TechStack.md sections 2, 5, 7 (Next.js setup, layout), design.md sections 2, 3, 12 (colors, typography, tokens), PRD.md section 10 (stack)

**Prerequisites (manual, for the user):**

1. **Phase 5 must be DONE** (contracts deployed on Anvil and ABIs generated).
   **How to check:** Phase 5 has `[x]` and Status `DONE`.

2. **Add local Anvil network in MetaMask.** Open MetaMask, go to Settings > Networks > Add Network (manual). Set: Network Name = "Anvil Local", RPC URL = `http://127.0.0.1:8545`, Chain ID = `31337`, Currency Symbol = "ETH". Confirm these values by running `anvil` in PowerShell and reading its startup output (it prints RPC and Chain ID).
   **How to check:** MetaMask shows "Anvil Local" in network dropdown.

3. **Obtain fonts (Telegraf and Open Sauce One).** Check their licenses and download from official sources if available. Place `.woff2` files in `web/public/fonts/`. If licenses are restrictive or fonts unavailable, use system fallback fonts only and document the limitation in `DESIGN_NOTES.md`.
   **How to check:** `Get-ChildItem web\public\fonts` shows font files or a note about licensing.

4. **Get a WalletConnect Project ID** (free). Current sign-up page: I will verify the URL before sending you there (WalletConnect cloud may be rebranded; check [https://cloud.walletconnect.com](https://cloud.walletconnect.com) or [https://cloud.reown.com](https://cloud.reown.com)). Create a project, copy the ID.
   **How to check:** You have a string like `a1b2c3d4...` ready to paste into `.env`.

**Tasks:**

- [ ] Initialize Next.js app and check Tailwind version: `cd web; pnpm create next-app . --js --tailwind --app --src-dir` (UNVERIFIED: confirm flags at phase start), then check if Tailwind v4 (check package.json); if v4 uses CSS @theme, log deviation in Change Log
- [ ] Install dependencies (wagmi, viem, RainbowKit, shadcn/ui): `pnpm add wagmi viem @tanstack/react-query @rainbow-me/rainbowkit framer-motion lucide-react`, then `pnpm dlx shadcn@latest init` (UNVERIFIED: verify JavaScript options at phase start)
- [ ] Create `web/.env.local` with `NEXT_PUBLIC_WALLETCONNECT_ID=...` (add to `.gitignore` if not already)
- [ ] Set up design tokens in CSS and Tailwind config: create `globals.css` with CSS variables (`--bg`, `--surface`, `--accent`, `--blue-peak`, `--text`, gradients, fonts per design.md 12.1), update `tailwind.config.js` (or CSS @theme if v4) with extended colors and fonts (design.md 12.2)
- [ ] Create `web/src/app/layout.js`: RainbowKit provider setup, global layout with top nav (logo, links, ConnectButton), apply midnight background
- [ ] Create `web/src/app/page.js`: placeholder landing page with one headline "VaultHunt" in display-xl, chip "TRUSTLESS BUG BOUNTIES", confirm fonts and colors match design.md
- [ ] Write and run sync-abis.js script: Node script reads `contracts/out/*/**.json` for ABIs, reads deployed addresses from broadcast or saved JSON, writes to `web/src/contracts/abis.json` and `addresses.json`, then run `node web/scripts/sync-abis.js`
- [ ] Test frontend: `cd web; pnpm dev`, open localhost:3000, connect wallet with RainbowKit, confirm UI matches design tokens (midnight bg, correct colors, fonts load)
- [ ] Check for `.ts` or `.tsx` files in `web/src/`: should be NONE (JavaScript only per TechStack.md)

**Exit Criteria:**
- Next.js app runs (`pnpm dev`)
- Wallet connect works (RainbowKit modal opens, can connect MetaMask on Anvil localhost network)
- Design tokens applied: background is `#020020`, text is white, fonts are Telegraf/Open Sauce One or documented fallbacks
- `sync-abis.js` script runs and produces valid JSON files
- No TypeScript files in `web/` (verify with `dir web /s /b | findstr /i .tsx` returns empty)
- ESLint passes: `pnpm lint`

**Verification Commands:**
```powershell
pnpm --dir web --version
powershell -NoProfile -Command "Get-ChildItem web\src\contracts -Name"
node web\scripts\sync-abis.js
powershell -NoProfile -Command "Get-Content web\src\contracts\abis.json -Head 10"
powershell -NoProfile -Command "Get-Content web\src\contracts\addresses.json"
powershell -NoProfile -Command "Get-ChildItem web -Recurse -Include *.ts,*.tsx -File | Where-Object { `$_.FullName -notmatch 'node_modules|\.next' }"
pnpm --dir web lint
```

---

## [x] Phase 7: Core user flows (programs list, create program, submit report with Web Crypto and IPFS, company review)

**Status:** DONE

**Goal:** Build the main interactive pages: browse programs, create a new program (company flow), submit a report (hunter two-step commit-reveal with client-side encryption and IPFS upload), and company review dashboard (accept/reject). Wire them to contracts via wagmi. Implement Web Crypto encryption and IPFS upload via Pinata.

**Docs:** PRD.md sections 6.1, 8.1 (features), design.md sections 7.2, 7.3, 7.4, 7.5 (page designs), TechStack.md sections 4, 7 (IPFS, Web Crypto)

**Prerequisites (manual, for the user):**

1. **Phase 6 must be DONE.**
   **How to check:** Phase 6 has `[x]` and Status `DONE`.

2. **Get a Pinata JWT.** Sign up at [pinata.cloud](https://pinata.cloud), create an API key with upload permissions, copy the JWT.
   **How to check:** Add `PINATA_JWT=...` to `web/.env.local` (server-side only, not `NEXT_PUBLIC_`).

3. **Anvil must be running** with contracts deployed (from Phase 5).
   **How to check:** Run `anvil` in a terminal, deploy contracts if not already, sync ABIs.

**Tasks:**

- [ ] Create `web/src/lib/crypto.js`: `computeContentHash(reportText)` returns keccak256 of plaintext bytes; `computeCommitHash(contentHash, salt, hunterAddress)` returns keccak256(abi.encode(...)); `encryptReport(reportText, companyPublicKeyPem)` using Web Crypto (AES-GCM for content, RSA-OAEP wrap for key), returns `{encryptedData, wrappedKey, iv}` as base64; `decryptReport(encryptedData, wrappedKey, iv, privateKeyPem)` for company; company UI also checks keccak256(decrypted plaintext) == contentHash from chain
- [ ] Create `web/src/lib/ipfs.js`: `uploadToIPFS(encryptedBlob)` calls Pinata API (server route to hide JWT), returns CID
- [ ] Create `web/src/app/api/upload/route.js`: Next.js API route that receives encrypted file, uploads to Pinata, returns CID (keeps JWT secret)
- [ ] Create `web/src/app/programs/page.js`: fetch all programs from Factory, display as grid of vault cards (design.md 7.2: notched card, slate surface, program name, locked funds), filter chips
- [ ] Create `web/src/app/programs/create/page.js`: form for company to create program (name, scope, severity payouts, deposit amount), calls Factory.createProgram and Escrow.deposit, shows tx pending/confirmed/failed states (design.md 7.4: slate inputs, magenta focus)
- [ ] Create `web/src/app/programs/[id]/submit/page.js`: two-step form with correct D1 order: Step 1 "Commit" (report text, compute contentHash from plaintext, compute commitHash, call Registry.commitReport(programId, commitHash)), Step 2 "Reveal" (encrypt report with Web Crypto, upload encrypted blob to IPFS via API route to get CID, call Registry.revealReport(reportId, cid, contentHash, salt)), flow chips stepper shows Commit -> Encrypt & Upload -> Reveal (design.md 5.3)
- [ ] Create `web/src/app/company/dashboard/page.js`: table of reports for company's programs, status chips (design.md 2.4), Accept/Reject buttons, calls **Registry.acceptReport** or **Registry.rejectReport** (NOT Escrow directly per D2), shows tx feedback
- [ ] Test each flow manually on Anvil: create program, deposit, commit report (hash only), reveal report (encrypted CID), company accepts via Registry, verify payout on-chain, check events
- [ ] Verify transaction feedback (pending spinner, success message, error in plain language: design.md 7.4)

**Exit Criteria:**
- Programs page lists programs from chain
- Create program flow works: company deposits ETH, program appears on-chain and in UI
- Submit report flow works: hunter commits hash, reveals encrypted CID, report is stored in Registry with Committed -> Revealed status
- Encryption works: encrypted blob is uploaded to IPFS, CID is valid, decryption (manual test) recovers plaintext
- Company dashboard shows reports, Accept button pays hunter (check hunter's balance increases)
- All transaction states shown (pending, confirmed, failed)
- No PINATA_JWT visible in client-side code (check Network tab: JWT only in server route)

**Verification Commands:**
```powershell
cd web
node scripts\sync-abis.js
# Test dev server in separate terminal
# Manual browser tests documented in tasks above
Get-ChildItem src -Recurse -File | Select-String -Pattern PINATA_JWT | Select-Object Filename,LineNumber
# Above must match ONLY src\app\api\upload\route.js
pnpm build
Get-ChildItem .next\static -Recurse -File | Select-String -Pattern PINATA_JWT
# Above must return nothing (no matches)
pnpm lint
cd ..
```

---

## [ ] Phase 8: Dispute and jury room UI, reputation badge and leaderboard, live activity feed

**Status:** NOT_STARTED

**Goal:** Build the dispute escalation and jury voting UI (jury room with countdown and vote reveal animation), hunter profile page showing reputation SBT badge and level, global leaderboard, and a live activity feed driven by contract events. Make the app feel "alive" per PRD section 9.

**Docs:** PRD.md sections 6.2, 8.1, 9 (dispute flow, features, live experience), design.md sections 7.6, 7.7, 7.8 (jury room, profile, toasts)

**Prerequisites (manual, for the user):**

1. **Phase 7 must be DONE.**
   **How to check:** Phase 7 has `[x]` and Status `DONE`.

2. **Run the seed script** to set up 3 juror accounts with staked BBT on Anvil. In PowerShell:
   ```powershell
   cd contracts
   forge script script/Seed.s.sol --fork-url http://127.0.0.1:8545 --broadcast
   cd ..
   ```
   **How to check:** Run `cast call <CourtAddress> "getJurorStake(address)" <jurorAddress1>` and see non-zero balance.

**Tasks:**

- [ ] Create `web/src/app/disputes/[caseId]/page.js`: jury room UI per design.md 7.6 (centered layout, case title, juror avatars/identicons, countdown timer from block.timestamp + voting period, commit vote form with hidden input + hash, reveal vote form, show votes after all revealed, verdict display)
- [ ] Create `web/src/app/profile/[address]/page.js`: hunter profile page (reputation badge with level, XP bar using design.md tokens: blue gradient on slate track, timeline of accepted reports using flow chips, total earnings display)
- [ ] Create `web/src/app/leaderboard/page.js`: leaderboard table (top hunters by XP or earnings, rank displayed in display-m numerals per design.md 7.7, sortable)
- [ ] Create `web/src/components/LiveFeed.js`: scrolling ticker component per design.md 7.8 (listens to contract events ReportAccepted, Paid, DisputeResolved, LevelUp via viem `watchContractEvent`, displays short messages like "Hunter 0x4f...a2 earned 0.8 ETH", pausable on hover)
- [ ] Integrate LiveFeed into layout or home page
- [ ] Create toast component: design.md 7.8 (slate surface, magenta left bar, auto-dismiss 5s), trigger on tx confirm/fail
- [ ] Add "Escalate" and "Escalate after timeout" actions to company dashboard: if report status is Rejected, hunter can call Registry.escalate; if reviewDeadline passed and status still UnderReview, hunter (or anyone) can call Registry.escalateAfterTimeout per D3
- [ ] Test dispute flow: reject a report, hunter escalates, 3 jurors commit and reveal votes (manual with 3 browser profiles or test script), verify verdict and payout
- [ ] Test profile page, leaderboard, and live feed: mint reputation SBT (via accepted report or direct contract call), load profile and see badge with level, check leaderboard order with multiple hunters at different levels, trigger contract events and verify live feed updates in real time

**Exit Criteria:**
- Jury room page displays case, accepts votes, shows countdown, reveals votes, displays verdict
- Profile page shows SBT badge, level, XP, accepted reports
- Leaderboard ranks hunters correctly
- Live feed updates on new events without page refresh
- Toasts show on every transaction (pending, success, error)
- All animations smooth and match design.md motion rules (glass arc float, chip stagger, etc. if time allows; minimum: no jank)

**Verification Commands:**
```powershell
pnpm --dir web lint
```

---

## [ ] Phase 9: Polish (motion, responsive, accessibility, demo mode) against design.md checklist

**Status:** NOT_STARTED

**Goal:** Refine the UI to match design.md quality checklist (section 13): animations via Framer Motion (glass arc float, vault fill, hexagon draw-in, chip stagger, page transitions), responsive layout for tablet and mobile, accessibility (keyboard nav, focus rings, aria labels, reduced-motion), and a demo mode that simulates a full scenario with pre-funded test wallets for presentations.

**Docs:** design.md sections 9, 10, 11, 13 (motion, responsive, accessibility, checklist), PRD.md section 9 (interactive experience)

**Prerequisites (manual, for the user):**

1. **Phase 8 must be DONE.**
   **How to check:** Phase 8 has `[x]` and Status `DONE`.

**Tasks:**

- [ ] Add Framer Motion animations: glass arcs (`motion.div` with slow float and rotate, 6-8s loop), vault fill bar (height animates on value change, 1s ease-out), hexagon outlines (stroke-dashoffset draw-in when in viewport, 0.9s), flow chips (sequential reveal with 80ms stagger), page transitions (fade + 12px rise, 0.35s), payout success (lock-open icon animation + glass arc pulse + XP bar fill, 1.2s total)
- [ ] Test animations with `prefers-reduced-motion`: disable float and shimmer, keep fades
- [ ] Make layout responsive: tablet (768-1279px) stacks side-by-side layouts, shrinks glass arcs to 60%, mobile (<768px) single column, wider hexagons, chip rows wrap vertically, hide second glass arc, display-xl clamps to 3.5rem minimum (design.md section 10)
- [ ] Test on 1440px, 1024px, 768px, and 390px viewport widths (browser DevTools)
- [ ] Add accessibility: every interactive element has visible focus ring (2px magenta outline offset 2px), toasts and countdowns have `aria-live="polite"`, decorative arcs/rings have `aria-hidden="true"`, all status shown with icon + text (not color alone), keyboard-operable vote and review actions (Tab, Enter, Space), transaction errors in plain language (design.md section 11)
- [ ] Test keyboard navigation: Tab through all pages, confirm focus visible, Enter/Space activate buttons
- [ ] Create `web/src/app/demo/page.js`: a "Demo Mode" panel with a "Simulate Full Scenario" button; demo mode restricted to local Anvil chain only; runs client-side with pre-funded Anvil accounts (addresses and data, NOT private keys in client code; private keys stay in .env server-side only); simulates: create program, commit report, reveal, accept, pay, show each step with delays and animations, useful for presentations
- [ ] Run through design.md section 13 checklist: background `#020020`, only 5 core colors, magenta only on bars/dashes/focus, fonts Telegraf + Open Sauce One Medium, headline line-height 1.0, chips square corners 6px magenta bar 60px height, hexagon 1px white outline, glass arcs never cover text, 81px margins scaled, every state has icon + text, reduced-motion tested, responsive tested, fonts/imagery licenses confirmed (or documented)
- [ ] Document any checklist items NOT met (e.g. custom glass arc images not sourced, fonts not licensed for public use) in `DESIGN_NOTES.md`

**Exit Criteria:**
- Animations work and enhance the "alive" feel without being distracting
- Responsive layout works on 4 viewport sizes (1440, 1024, 768, 390)
- Accessibility: keyboard nav works, focus rings visible, `aria` labels correct, reduced-motion respected
- Demo mode runs a full scenario automatically for presentations; demo mode restricted to Anvil only; no private key can be present in a Sepolia/production build (private keys stay in .env server-side)
- Design.md checklist at least 90% satisfied (any gaps documented)

**Verification Commands:**
```powershell
pnpm --dir web lint
powershell -NoProfile -Command "Get-Content web\DESIGN_NOTES.md"
```

---

## [ ] Phase 10: Sepolia deployment and final audit

**Status:** NOT_STARTED

**Goal:** Deploy all contracts to Sepolia testnet, verify on Etherscan, update frontend to use Sepolia, run final full audit (all tests, Slither, coverage, design checklist, doc conformance).

**Docs:** PRD.md sections 14, 18 (deliverables), TechStack.md section 7 (deploy), design.md section 13 (checklist)

**Prerequisites (manual, for the user):**

1. **Phase 9 must be DONE.**
   **How to check:** Phase 9 has `[x]` and Status `DONE`.

2. **Get Sepolia testnet ETH.** Use faucets from Phase 0 prep (sepoliafaucet.com, Alchemy, or Infura). You'll need ETH in the deployer wallet and a few test accounts.
   **How to check:** Check balance with MetaMask or `cast balance <address> --rpc-url <SEPOLIA_RPC>`.

3. **Get Sepolia RPC URL.** Sign up for Alchemy, Infura, or another RPC provider, get a Sepolia endpoint.
   **How to check:** Add `SEPOLIA_RPC=https://...` to `.env` and confirm `cast block-number --rpc-url %SEPOLIA_RPC%` returns a number.

4. **Get Etherscan API key.** Sign up at [etherscan.io](https://etherscan.io), create an API key.
   **How to check:** Add `ETHERSCAN_API_KEY=...` to `.env`.

**Tasks:**

- [ ] Set environment variables in `.env`: `SEPOLIA_RPC`, `PRIVATE_KEY` (test wallet with Sepolia ETH), `ETHERSCAN_API_KEY`
- [ ] Deploy contracts to Sepolia: `forge script script\Deploy.s.sol --rpc-url %SEPOLIA_RPC% --broadcast --verify --etherscan-api-key %ETHERSCAN_API_KEY%`, confirm all 7 contracts deployed and verified, save addresses
- [ ] Update `web/contracts/addresses.json` with Sepolia addresses (or run `sync-abis.js` with Sepolia broadcast output)
- [ ] Update `web/lib/wagmi-config.js` to include Sepolia chain, test wallet connect on Sepolia
- [ ] Test full flow on Sepolia: create program, deposit, commit, reveal, accept, dispute (if time), verify all transactions on Sepolia Etherscan
- [ ] Run final audit: `forge test -vv`, `forge coverage`, `slither src/`, `pnpm lint`, design.md checklist, doc conformance (contract names match PRD section 7, no `.ts`/`.tsx` in `web/`, colors from design.md, secrets in `.env` not tracked)
- [ ] Record audit results in `milestone.md` Audit Log (Audit Gate 10)

**Exit Criteria:**
- All 7 contracts deployed and verified on Sepolia
- Frontend connects to Sepolia and works (create, submit, review flows)
- Final audit gate passed (all tests, 90%+ coverage, zero HIGH Slither findings, design checklist 90%+, no `.ts`/`.tsx`, secrets safe)

**Verification Commands:**
```powershell
forge script script\Deploy.s.sol --rpc-url %SEPOLIA_RPC% --broadcast --verify --etherscan-api-key %ETHERSCAN_API_KEY%
cast call <FactoryAddress> "programCount()" --rpc-url %SEPOLIA_RPC%
forge $1 --root contracts test -vv
forge $1 --root contracts coverage --report summary
slither contracts\src\ --filter-paths "test|script"
pnpm --dir web lint
pnpm --dir web build
powershell -NoProfile -Command "Get-ChildItem web -Recurse -Include *.tsx -File | Where-Object { `$_.FullName -notmatch 'node_modules|\.next' }"
git status
```

---

## [ ] Phase 11: Documentation, report, presentation, and demo video

**Status:** NOT_STARTED

**Goal:** Write complete README with setup steps, create final project report and presentation materials, record a 5-minute demo walkthrough. Prepare all deliverables for submission.

**Docs:** PRD.md sections 14, 18 (deliverables, submission checklist), TechStack.md section 9 (documentation)

**Prerequisites (manual, for the user):**

1. **Phase 10 must be DONE.**
   **How to check:** Phase 10 has `[x]` and Status `DONE`.

**Tasks:**

- [ ] Write complete `README.md`: project summary, folder structure, setup steps (clone, install Foundry, install pnpm, install dependencies, configure `.env`, deploy or use provided Sepolia addresses), how to run tests, how to run frontend, contract addresses on Sepolia, links to Etherscan, team members, licenses, limitations (juror randomness, demo encryption), known issues
- [ ] Write `PROJECT_REPORT.md` or `.pdf`: architecture, security analysis (test results, Slither summary), test coverage, design decisions, limitations, syllabus mapping (PRD section 14), screenshots, Sepolia tx links
- [ ] Create presentation deck (slides): problem, solution, architecture, contract map, demo screens, security measures, test results, live demo plan, Q&A prep (viva one-liners from PRD section 20)
- [ ] Record 5-minute demo video: show landing page, create program, submit report, accept, show payout, show live feed, jury room (optional if time tight), leaderboard, narrate key points
- [ ] Run Audit Gate 11: verify README complete, PROJECT_REPORT complete, presentation deck ready, demo video recorded, repo clean
- [ ] Final check: no private keys or API secrets in tracked files, `.env.example` up to date, all docs in `tasks-docs/` untouched (or changes approved and logged), record audit result in Audit Log

**Exit Criteria:**
- README complete with setup steps and Sepolia addresses
- Project report written (architecture, security, coverage, screenshots, tx links)
- Presentation deck ready
- Demo video recorded (5 min)
- GitHub repo clean and ready for submission

**Verification Commands:**
```powershell
powershell -NoProfile -Command "Get-Content README.md"
powershell -NoProfile -Command "Get-Content PROJECT_REPORT.md"
powershell -NoProfile -Command "Get-ChildItem . -Include *.pptx,*.pdf,*.mp4 -Recurse -File | Select-Object Name"
powershell -NoProfile -Command "Get-Content .env.example"
git status
```

---

**End of milestone phases. Once Phase 10 is DONE and audited, the project is complete and ready for submission.**
