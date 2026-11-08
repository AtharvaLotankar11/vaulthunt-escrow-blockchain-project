# PRD: Decentralized Escrow System for Bug Bounty Hunters

**Working title:** VaultHunt (rename freely)
**Course:** Blockchain Technology (Sem VII), group project
**Version:** 0.2 (design decisions D1 to D4 applied on 2026-11-08; see sections 6, 7, 12)
**Target network:** Ethereum Sepolia testnet (local Anvil/Hardhat for development). No real money.

---

## 1. One-line summary

A platform where companies lock bounty rewards in smart contracts, hackers submit **encrypted, timestamped** vulnerability reports, and payment is released **automatically** on acceptance. Disputes are settled by a **staked jury** instead of a company's goodwill. All of it is wrapped in a fast, game-like, real-time web app.

---

## 2. Problem

| Who | Pain today |
|---|---|
| **Hunters** | Reports get rejected as "duplicate" or "out of scope" with no proof. Payouts are late or never come. The company can quietly fix the bug and ghost the hunter. |
| **Companies** | Need to attract serious hunters but can't prove they will pay. Fake or low-quality reports waste time. |
| **Both** | A central platform sits in the middle, takes fees, and is the single point of trust and failure. |

**Core issue:** the money and the verdict are controlled by one party.

---

## 3. Solution (plain words)

1. **Money is locked first.** A company can't post a bounty without depositing the reward. Hunters can see it on-chain.
2. **Proof of discovery.** A hunter publishes a *hash* of the report before the company sees it. This proves who found it first, with no one able to steal or back-date it.
3. **Report stays private.** The report is encrypted so only the company (and, if disputed, the jury) can read it.
4. **Payout by code.** Accepted means the contract pays. No middleman.
5. **Fair disputes.** If the company rejects or stalls, the hunter can escalate to a jury of staked arbitrators who vote and get rewarded or penalised.
6. **Reputation that can't be faked or sold.** Hunters earn non-transferable on-chain badges and levels.

---

## 4. Goals and non-goals

### Goals
- Working end-to-end flow on a testnet: create bounty, submit, review, pay, dispute.
- **8 smart contracts** that genuinely interact (faculty minimum is 5).
- An interactive, real-time, visually strong dApp, not a static form page.
- Security-aware design (reentrancy, front-running, access control) with tests to prove it.
- Strong alignment to the syllabus (see section 14).

### Non-goals (explicitly out of scope)
- Mainnet deployment or real funds (would need a professional audit).
- KYC, legal contracts, or tax handling.
- Judging whether a vulnerability is technically real *automatically*. Humans (company, jury) decide; the chain enforces the outcome.
- Fiat payments.

---

## 5. Users and personas

| Persona | Needs | Key actions |
|---|---|---|
| **Company (Program Owner)** | Trust signal, simple setup, control over scope and severity payouts | Create program, deposit funds, review reports, accept or reject, top up |
| **Hunter** | Proof of priority, guaranteed payout, reputation | Browse programs, commit and submit report, track status, escalate dispute |
| **Juror (Arbitrator)** | Earn rewards for fair judgement | Stake tokens, receive case, vote, collect rewards |
| **Visitor** | Understand the platform quickly | Browse live feed, leaderboard, stats without connecting a wallet |

---

## 6. User flows

### 6.1 Happy path
```
Company: createProgram + deposit ETH  ->  funds sit in the program's own Escrow
Hunter : (in browser) contentHash = keccak256(report bytes)
         commitHash  = keccak256(abi.encode(contentHash, salt, hunterAddress))
Hunter : commitReport(programId, commitHash)  ->  timestamp & priority locked
Hunter : (in browser) encrypt report, upload to IPFS, get the CID
Hunter : revealReport(reportId, cid, contentHash, salt)
         contract recomputes commitHash with msg.sender and must match
Company: decrypts the report and checks keccak256(plaintext) == contentHash
Company: startReview(reportId), then acceptReport(reportId, severity) on the Registry
Registry: pays the hunter through the Escrow and updates the Reputation badge
```

**Order matters:** commit first, then encrypt and upload, then reveal. The CID does not exist before the upload, so the commit hash is built from the report's content hash, not from the CID.

### 6.2 Dispute path
```
Company calls rejectReport on the Registry
   OR the review deadline passes with no company action
Hunter : escalate(reportId) after a rejection, or escalateAfterTimeout(reportId)
         once reviewDeadline has passed (a contract cannot trigger itself,
         so someone must make this call; the hunter or anyone may)
Registry: forwards the case to DisputeCourt (dispute fee staked in BBT)
Court  : picks N jurors (N = 3 for the demo) from the staked pool
Jurors : commit vote -> reveal vote
Court  : majority wins and calls Registry.applyVerdict(reportId, hunterWins)
Registry: pays the hunter or refunds the company through the Escrow
Court  : jurors who voted with the majority are rewarded, others slashed
```

### 6.3 Report state machine
```
Committed -> Revealed -> UnderReview -> Accepted -> Paid
                              |-> Rejected -> (Closed | Disputed)
                              |-> Timeout (after reviewDeadline, someone calls
                                  escalateAfterTimeout) -> Disputed
Disputed -> Voting -> Resolved -> Paid | Refunded
```

---

## 7. Smart contract architecture (8 contracts)

| # | Contract | Standard / pattern | Responsibility |
|---|---|---|---|
| 1 | **BountyToken (BBT)** | ERC-20 | Platform token used for juror staking, dispute fees, governance weight. Faucet function for testnet demo. |
| 2 | **BountyFactory** | Factory + EIP-1167 minimal proxy clones | Creates a new Escrow per program cheaply, keeps a registry of all programs. |
| 3 | **BountyEscrow** | Clone instance (initialize(), not a constructor), ReentrancyGuard, pull-payment | Holds one program's funds. Stores severity tiers (Low/Med/High/Critical payout %). Locks, pays, or refunds, but only when called by the Registry. |
| 4 | **ReportRegistry** | Commit-reveal, single orchestrator | Stores commit hash, timestamp, encrypted-file pointer (IPFS CID), content hash, status. Resolves duplicates by earliest commit. The program owner accepts or rejects through it; it pays through the Escrow, updates the badge, and forwards disputes to the Court. |
| 5 | **DisputeCourt** | Staked jury, commit-reveal voting, slashing | Handles escalations: juror selection, voting, rewards and penalties. Its only effect on money is calling Registry.applyVerdict. |
| 6 | **ReputationSBT** | ERC-721 *soulbound* (non-transferable) | Hunter level badges (Rookie, Hacker, Elite, Legend). Updated by the Registry (manager role) with accepted reports and severity. |
| 7 | **PlatformTreasury** | Access-controlled vault | Collects small platform fee and slashed stakes; funds juror rewards; owned by multisig or timelock for demo. |
| 8 | **ProgramDirectory** | Pointer registry (added in Phase 7) | Lets a program's owner publish an IPFS pointer to its public profile: name, scope and the PUBLIC encryption key hunters use. Holds no funds, has no admin. |

### Contract interaction map
```
                 +----------------+
                 |  BountyToken   |<---- stake / dispute fees ---- jurors, hunters
                 +----------------+
                        ^ stake
                        |
 Company --> BountyFactory --clones--> BountyEscrow
                 |                         ^
                 | registers               | lock / pay / refund (Registry ONLY)
                 v                         |
 Hunter --> ReportRegistry ----------------+----> ReputationSBT (badge update)
                 ^   |
   applyVerdict  |   | escalate
                 |   v
              DisputeCourt ----rewards / slashes----> PlatformTreasury

 Company calls Registry only (startReview, acceptReport, rejectReport),
 never the Escrow directly. Court never touches the Escrow.
```

### Key rules per contract (short)
- **Escrow:** an EIP-1167 clone set up once with `initialize(registry, owner)`. Only the Registry address may call `lock`, `payHunter`, `refundCompany`. The company may deposit, and withdraw only unlocked funds. Uses pull-payments and a reentrancy guard.
- **ReportRegistry:** `commitReport(programId, commitHash)` first; later `revealReport(reportId, cid, contentHash, salt)`. The contract checks `commitHash == keccak256(abi.encode(contentHash, salt, msg.sender))`, which binds the hunter address and prevents copy-paste theft. The program owner calls `startReview`, `acceptReport(reportId, severity)`, `rejectReport(reportId)`. After `reviewDeadline` anyone may call `escalateAfterTimeout(reportId)`. Only the Court may call `applyVerdict(reportId, hunterWins)`.
- **DisputeCourt:** jurors must hold minimum staked BBT; votes are hidden until the reveal phase. Registry and Court reference each other, so they are linked once at deploy time with one-time owner-only setters (documented in SECURITY.md).
- **ReputationSBT:** overrides the ERC-721 `_update` hook (OpenZeppelin v5) so tokens can be minted but never transferred. Level derives from on-chain accepted count and severity weight.

---

## 8. Features

### 8.1 Must-have (MVP)
1. Wallet connect (MetaMask) and network check.
2. Create program with scope text, severity payout table, deposit, and review deadline.
3. Browse programs with live "locked funds" counter.
4. Two-step report submission (commit then reveal) with client-side encryption.
5. Company review dashboard with Accept / Reject and severity selection.
6. Automatic payout and refund.
7. Dispute escalation and juror voting (at least 3 jurors).
8. Soulbound reputation badge minted on first accepted report.
9. Event-driven live feed.

### 8.2 Should-have
- Hunter profile page with badge, earnings, and accepted-report timeline.
- Global leaderboard (top hunters, top paying programs).
- Notification toasts on every on-chain event.
- One-click escalation after the review deadline passes (a contract cannot call itself, so the hunter or anyone triggers `escalateAfterTimeout`).
- Top-up and extend a program.

### 8.3 Nice-to-have (stretch)
- Chainlink VRF for fair juror selection (needs testnet subscription).
- Anonymous hunters via zk proof of "I own a valid badge" (links to zk-SNARK topic in Module 6).
- Gasless first submission via meta-transactions / account abstraction.
- Cross-chain deployment to a second testnet.
- On-chain governance vote to change fee or juror count.

---

## 9. Interactive and "happening" experience (frontend vision)

The product must *feel alive*, not like a form on a page.

| Idea | What the user sees |
|---|---|
| **Live Activity Ticker** | A scrolling feed ("Hunter 0x4f...a2 just earned 0.8 ETH, Critical") driven by contract events in real time. |
| **Animated Vault** | Each program shown as a vault card. Funds fill visually, and a lock opens with animation on payout. |
| **Report Journey Tracker** | A pipeline stepper (Committed, Revealed, Review, Accepted, Paid) that advances live as transactions confirm. |
| **Jury Room** | A dispute screen with juror avatars, countdown timer, and vote reveal animation. |
| **Gamification** | XP bar, level-ups, rank badges, streaks, a "Hall of Fame". |
| **Transaction UX** | Every transaction shows pending, confirmed, and failed states with human-readable messages (no raw hex errors). |
| **Dark "terminal" theme** | Hacker-style visual identity with smooth micro-interactions. |
| **Demo mode** | A one-click "simulate" panel that plays a full scenario with pre-funded test wallets for presentations. |

---

## 10. Technical stack (proposed)

| Layer | Choice | Why |
|---|---|---|
| Contracts | **Solidity 0.8.x** + **OpenZeppelin** | Syllabus Module 3; audited building blocks |
| Dev and test | **Foundry** (or Hardhat) + **Remix** for quick prototypes | Fast tests and fuzzing; Remix is in the syllabus |
| Local chain | Anvil / Hardhat node | Instant blocks for development |
| Testnet | Sepolia | Widely supported faucets and tools |
| Frontend | **Next.js (React) + TypeScript** | Component-driven, interactive |
| Wallet and chain access | **wagmi + viem** (browser wallet, small custom connect button) | Modern, event watching built in |
| UI and animation | Tailwind CSS + shadcn/ui + Framer Motion | Polished, fast to build |
| Real-time data | Contract event subscriptions via viem (optionally The Graph subgraph) | Powers live feed and leaderboard |
| File storage | **IPFS** via Pinata or web3.storage | Large encrypted reports off-chain |
| Encryption | Browser Web Crypto (hybrid: AES for file, company public key for the AES key) | Only the company and jurors can decrypt |
| Security tooling | Slither, Foundry fuzz and invariant tests | Module 6 security |

> Note: verify current versions and testnet availability at build time (faucets and RPC providers change often).

---

## 11. System architecture

```
 [ Next.js dApp ]
     |  wagmi/viem                \
     |                             \--> [ IPFS ] encrypted reports
     v
 [ Wallet: MetaMask ] --signs tx--> [ Sepolia ]
                                      |  Factory, Escrow, Registry,
                                      |  Court, SBT, Token, Treasury
                                      v
                          events --> [ Frontend live feed / leaderboard ]
```

**On-chain:** money, hashes, status, votes, reputation.
**Off-chain:** encrypted report files, UI, indexing.
**Rule of thumb:** nothing sensitive in plaintext on-chain.

---

## 12. Security and threat model

| Threat | Mitigation |
|---|---|
| Company steals the bug and rejects | Commit hash timestamp proves priority; dispute path with jury |
| Hunter copies another hunter's report | Hash is bound to hunter address and salt; earliest commit wins |
| Front-running a reveal | Commit-reveal scheme |
| Reentrancy on payout | Checks-effects-interactions, ReentrancyGuard, pull payments |
| Company withdraws funds mid-review | Escrow locks funds per active report |
| Anyone calls payout functions directly | Escrow accepts calls only from the Registry; the Registry restricts accept/reject to the program owner and verdicts to the Court |
| Juror collusion or lazy voting | Stake and slash, hidden votes, reward only for majority |
| Sybil jurors | Minimum stake and cooldown |
| Weak randomness for jury pick | Pseudo-random for demo, **documented limitation**, VRF as upgrade |
| Admin abuse | Role-based access, treasury behind timelock or multisig |
| Report leaks | Client-side encryption; only hash and CID on-chain |

**Honest limitation:** a smart contract cannot verify that a bug is real. It enforces *process and payment*; judgement is human (company or jury).

---

## 13. Testing and quality

- **Unit tests** for every function of every contract.
- **Fuzz and invariant tests**, for example: "escrow balance never goes below locked rewards".
- **Scenario tests:** happy path, rejection, timeout, dispute with 3 and 5 jurors, duplicate reports.
- **Static analysis:** Slither report included in submission.
- **Gas report** for key functions.
- **Frontend:** manual test checklist plus a recorded demo run.
- Target: 90%+ line coverage on contracts.

---

## 14. Syllabus mapping (Blockchain Technology)

| Syllabus module | Where it appears in the project |
|---|---|
| **1. DLT and Blockchain** (hashing, Merkle tree, consensus) | Report hash commitments; explanation of why Ethereum finality is trusted |
| **3. Ethereum and Smart Contracts** (EVM, MetaMask, Solidity, Remix, test networks, DApps, gas, vulnerabilities) | All 8 contracts, wallet flow, Sepolia deployment, gas optimisation, vulnerability handling |
| **5. Crypto Assets, NFTs** (ERC20, ERC721, tokenization) | BountyToken (ERC-20), ReputationSBT (ERC-721 variant) |
| **6. DeFi, DAO, Security** (staking, governance tokens, DAO, wallet attacks, EVM security, zk-SNARKs) | Juror staking and slashing, DAO-style jury, security testing, optional zk badge proof |
| **4. Hyperledger** | Not used. Add a short comparison slide: why a public chain suits open bounty trust |

---

## 15. Success metrics

| Metric | Target |
|---|---|
| Smart contracts deployed and verified | 7 |
| End-to-end flows demonstrated | Happy path, rejection, timeout, dispute |
| Test coverage | 90%+ |
| Critical or high Slither findings unresolved | 0 |
| Tx to confirmation feedback in UI | Under 1 second to show "pending" |
| Live demo without manual console use | Yes |

---

## 16. Milestones (suggested 8-week plan)

| Week | Deliverable |
|---|---|
| 1 | Finalise PRD, repo setup, roles, wireframes |
| 2 | BountyToken, ReputationSBT, Treasury plus tests |
| 3 | Factory, Escrow plus tests |
| 4 | ReportRegistry (commit-reveal) plus IPFS and encryption prototype |
| 5 | DisputeCourt plus integration tests |
| 6 | Frontend core: wallet, program pages, report flow |
| 7 | Live feed, vault animations, jury room, leaderboard |
| 8 | Security pass, Sepolia deploy, demo mode, report and slides |

---

## 17. Suggested team split (4 members)

1. **Contracts A:** Token, SBT, Treasury, Factory.
2. **Contracts B:** Escrow, Registry, Court, security tests.
3. **Frontend:** UI, animations, wallet integration, live feed.
4. **Integration and docs:** IPFS and encryption, deployment scripts, demo mode, report.

---

## 18. Deliverables

- GitHub repo with contracts, tests, frontend, and deployment scripts.
- Verified contracts on Sepolia with addresses listed in README.
- Live demo plus a 5-minute recorded walkthrough.
- Project report (architecture, security analysis, test results, limitations).
- Presentation deck.

---

## 19. Risks

| Risk | Impact | Plan |
|---|---|---|
| Scope too big | Delay | Lock MVP list in 8.1; stretch goals only after week 6 |
| Testnet faucet or RPC problems | Demo failure | Keep a local Anvil fallback and a recorded demo |
| Encryption complexity | Bugs | Build simplest hybrid scheme first; test with fixtures |
| Jury randomness criticism | Viva questions | Document honestly; show VRF upgrade path |
| Frontend polish eats time | Contracts suffer | Contracts frozen by week 5 |

---

## 20. Viva-ready one-liners

- **Why blockchain?** The money and the verdict shouldn't belong to one party.
- **Why 8 contracts?** Separation of concerns: money, evidence, judgement, and reputation each have their own contract.
- **Why commit-reveal?** Proves "I found it first" without exposing the bug.
- **Why soulbound reputation?** Reputation you can buy isn't reputation.
- **What can't it do?** It cannot decide if a bug is real; it only enforces a fair process.

---

## 21. Decisions on the open questions (resolved 2026-11-08)

1. **Testnet:** Ethereum Sepolia (after local Anvil).
2. **Toolchain:** Foundry (native Windows install; no WSL).
3. **Jury size for demo:** 3, stored as a configurable constant.
4. **zk stretch goal:** out of scope; mentioned as future work only.
5. **Project name and branding:** VaultHunt (working title; repo `vaulthunt-escrow-blockchain-project`).
