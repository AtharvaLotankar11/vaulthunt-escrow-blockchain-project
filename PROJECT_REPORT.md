# VaultHunt: A Decentralized Escrow for Bug Bounty Hunters

**Course:** Blockchain Technology (26ITPC71), Semester VII
**Team Members:** `Atharva Lotankar (20), Vaishnavi Avhad(02), Bhoomi Naik(22)` · **Subject:** `Blockchain Technology` · **Term Work:** `Mini Project`
**Repository:** https://github.com/AtharvaLotankar11/vaulthunt-escrow-blockchain-project
**Status:** Testnet prototype, not audited.

---

## 1. Abstract

Bug bounty programs depend on trust in both directions. Hunters fear that a company will reject a valid report and fix the bug for free, or leak the idea. Companies fear unverified claims. VaultHunt moves the money and the verdict out of any single party's hands. A company locks the reward in an on-chain vault; a hunter proves priority with a hash commitment and then encrypts the report so only the company can read it; and if the company rejects or stays silent, a randomly drawn, staked and slashable jury decides, and the contract pays out by code. The system consists of eight Solidity contracts (299 automated tests, 99.82% line coverage, no High static-analysis findings), a multi-page web app, and a live deployment on the Ethereum Sepolia test network, where a complete flow was executed through the user interface.

## 2. Problem and motivation

1. **Priority and theft.** Describing a bug to prove you found it first gives the idea away.
2. **Non-payment.** A company can reject a valid report, or ignore it, and the hunter has no recourse except reputation.
3. **Opaque judgement.** The party that pays is also the party that judges.
4. **Reputation that can be bought.** Platform scores are not portable and not trustless.

**Why a blockchain?** The money and the verdict should not belong to one party. A public ledger gives tamper-evident timestamps (priority), programmable escrow (payment), transparent rules (the jury), and non-transferable credentials (reputation).

## 3. Objectives and scope

**Goals:** trustless escrow; proof of priority without disclosure; confidentiality of the report; a fair dispute path that cannot be stalled by an unresponsive company; portable reputation; a usable interface; strong test evidence; deployment on a public test network.

**Non-goals (stated in the PRD):** deciding whether a bug is technically real (the system enforces a fair *process*, not truth); mainnet deployment; production-grade randomness; legal enforcement.

## 4. System overview

### 4.1 Roles and the main flow

```
Company: createProgram(deposit)  -->  vault (BountyEscrow clone)
Hunter : commitReport(hash)      -->  timestamped, content hidden
Hunter : revealReport(...)       -->  reward locked for the hunter
Company: acceptReport            -->  hunter paid, badge minted/updated
   or rejectReport               -->  hunter may escalate (pays the dispute fee)
   or silence                    -->  after the deadline anyone may escalate
Jury   : commit hidden votes --> reveal --> resolveCase --> verdict applied by the Registry
```

### 4.2 Architecture

Eight contracts, one rule: **the ReportRegistry is the only address that may lock, pay or refund an escrow.** The court never touches program money; it only reports a verdict back to the Registry.

| Contract | Responsibility |
|---|---|
| BountyToken | ERC-20 used for juror stakes and dispute fees; testnet faucet |
| BountyFactory | Creates one escrow clone per program (EIP-1167) |
| BountyEscrow | Funds, reward tiers, locks, credits (pull payments) |
| ReportRegistry | Report lifecycle, commit-reveal, XP and badges, calls the court |
| DisputeCourt | Staking, jury draw, hidden votes, slashing, verdicts. No owner. |
| ReputationSBT | Soulbound ERC-721 hunter badge |
| PlatformTreasury | Receives platform-side funds |
| ProgramDirectory | IPFS pointer to a program's public profile and public key |

### 4.3 Off-chain parts

- **Encryption:** the company generates an RSA-2048 key pair in the browser (Web Crypto); the public key is published through ProgramDirectory; the hunter encrypts the report with a fresh AES-256-GCM key and wraps that key with the company's public key (RSA-OAEP, SHA-256); only the company's private key (kept in its browser) can decrypt. The hash committed on-chain lets the company verify it received exactly what was committed.
- **Storage:** encrypted reports and program profiles are stored through an API route (a local store, or Pinata/IPFS when a key is configured). Only a pointer and a hash go on-chain.
- **Frontend:** Next.js 16, wagmi/viem for wallet and reads, with a design system and a Demo Mode.

## 5. Smart contract design

### 5.1 Key design decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | **Commit-reveal** for reports | Proves "I found it first" without exposing the bug; a copied commit is useless to another hunter because the hash binds the hunter's address and salt |
| D2 | **Registry is the sole orchestrator** | Escrow, SBT and Court each trust exactly one caller; small trust surface |
| D3 | **Timeout escalation** | A silent company cannot stall a hunter; after the deadline anyone can send the report to the jury |
| D4 | **Soulbound reputation** | A score that can be bought or sold is not reputation |
| D5 | **Reward locked at reveal** | The company can no longer withdraw the money a valid report is entitled to |
| D6 | **Pull payments** | A hostile receiver (one that reverts or burns gas) cannot block anyone else; payment is credited and claimed |
| D7 | **Court without owner or admin** | Nobody can change the rules or the verdict after deployment |
| D8 | **Jurors drawn by lowest keccak score, no modulo** | Avoids modulo bias; hunter and company are never eligible |
| D9 | **Hidden jury votes (commit-reveal)** | Jurors cannot copy each other or be bribed by the visible tally |
| D10 | **Fixed tie-break rules** | A tie after a rejection goes to the company (status quo); a tie after a company timeout goes to the hunter (the company failed to act) |
| D11 | **Hunter pays the dispute fee** | A hunter can spam disputes only at a cost; fixes a static-analysis finding about arbitrary token transfers |

### 5.2 Access control summary

| Action | Allowed caller |
|---|---|
| Lock / pay / refund escrow funds | ReportRegistry only |
| Deposit / withdraw free funds | Program owner (cannot touch locked funds) |
| Accept / reject / start review | Program owner |
| Reveal / escalate a rejection | The committing hunter |
| Escalate after timeout, resolve a case, claim credit | Anyone |
| Mint / update badge | ReportRegistry only (it owns the SBT) |
| Open a court case | ReportRegistry only |

### 5.3 Reputation

XP per accepted report: Low 10, Medium 25, High 50, Critical 100. Levels at 100, 300 and 700 XP. The badge is minted once per hunter and its level updates as XP grows; every transfer attempt reverts.

## 6. Security analysis

### 6.1 Threats and mitigations

| Threat | Mitigation |
|---|---|
| Company rejects a valid report to avoid paying | Hunter escalates to a staked jury; the locked reward is paid on a hunter verdict |
| Company withdraws the reward after seeing a report | Reward locked at reveal; withdrawals can only touch free funds |
| Company shrinks a locked reward by withdrawing other funds | Pool size is stored at lock time; payment is the larger of the lock pool and the current pool (found and fixed during testing, see 6.3) |
| Another hunter copies a commit | Commit hash includes the hunter's address and a secret salt |
| Front-running a reveal | The reveal is only valid from the committing address with the matching salt |
| Reentrancy on payout | Checks-effects-interactions, pull payments, ReentrancyGuard on claims |
| Hostile receiver blocks a payout or badge | Credits are claimed by the receiver; badge minting is gas-capped and its failure cannot block acceptance |
| Jury bribery or copying | Hidden votes; slashing for votes against the majority and for non-reveals |
| Company or hunter sitting on their own jury | Excluded from the draw (tested) |
| Jury cannot be formed | Escalation fails atomically and the rejection stays; tested |
| Court bug blocks the Registry | Verdict application is atomic (resolve reverts as a whole if the Registry call fails) |
| Reputation trading | Soulbound: transfers and approvals revert (invariant-tested) |

### 6.2 Verification evidence

| Method | Result |
|---|---|
| Unit, integration and scenario tests | 299 tests pass across 20 suites |
| Fuzz tests (256 runs each) | Commit-reveal round trip; any tampering breaks reveal; copied commit useless to others; accept never pays more than the program holds; locked funds can never be withdrawn; solvency under random event sequences; court token balance stays balanced |
| Invariant tests (64 runs, 2,560 calls each) | Escrow: balance covers locks and credits, every wei accounted for, nothing locked is ever withdrawn, totals match individual records. SBT: badges non-transferable, balances add up to supply. Court: cases cannot resolve while votes are hidden, the court holds exactly what it owes, counters match reality |
| Mutation checks | The invariant tests were checked by deliberately breaking the contracts, to confirm that the tests fail when a rule is broken |
| Slither | 26 results, **0 High**; 2 Medium reviewed (a strict-equality check in the faucet, and a state write after a gas-capped badge mint) |
| Coverage | See 7.2 |

### 6.3 Problems found and fixed

| Found by | Problem | Fix |
|---|---|---|
| Slither (High) | `arbitrary-send-erc20` in the court's fee handling | The hunter now pays the fee from their own address through `payDisputeFee` |
| Scenario test | The company could shrink a locked reward by withdrawing free funds | The pool size is recorded at lock; payment uses the larger of the locked pool and the current pool |
| Automated browser run | Wallet gas estimates were occasionally too tight for transactions whose cost depends on their inputs | The app now estimates gas first and adds 30% headroom |

### 6.4 Residual risks (documented in `contracts/LIMITATIONS.md`)

The jury draw uses pseudo-randomness derived from `block.prevrandao`, which a block proposer can influence slightly; jurors see only the hunter's public summary, not the encrypted report; the system cannot judge technical truth; demo-sized windows; the contracts are not formally audited.

## 7. Testing and results

### 7.1 Test inventory

| Group | Tests |
|---|---|
| BountyToken | 9 |
| PlatformTreasury | 12 |
| ReputationSBT | 12 |
| BountyFactory | 15 |
| BountyEscrow (including a fuzz test) | 49 |
| ReportRegistry | 72 |
| DisputeCourt (including a fuzz test) | 70 |
| ProgramDirectory | 10 |
| Deployment wiring | 6 |
| Integration and registry integration | 10 |
| End-to-end scenarios (happy path, rejection and dispute, timeout escalation, dispute scenarios) | 22 |
| Fuzz suites (registry 5, escrow 4) | 9 |
| Invariant suites (escrow, SBT, court) | 3 suites, 9 invariants |
| **Total** | **299 passed, 0 failed** |

### 7.2 Coverage (src only)

| File | Lines | Statements | Branches | Functions |
|---|---|---|---|---|
| BountyEscrow | 100% (97/97) | 100% | 98.08% | 100% |
| BountyFactory | 100% (18/18) | 100% | 100% | 100% |
| BountyToken | 100% (9/9) | 100% | 100% | 100% |
| DisputeCourt | 100% (216/216) | 100% | 99.06% | 100% |
| PlatformTreasury | 100% (24/24) | 100% | 75.00% | 100% |
| ProgramDirectory | 100% (15/15) | 100% | 100% | 100% |
| ReportRegistry | 100% (143/143) | 100% | 98.63% | 100% |
| ReputationSBT | 97.37% (37/38) | 97.30% | 75.00% | 100% |
| **Total** | **99.82% (559/560)** | **99.82%** | **97.03%** | **100%** |

### 7.3 Frontend verification

- `pnpm lint` and `pnpm build` pass.
- The full flow was run by hand through the interface on a local Anvil chain: vault, encrypted report, rejection, dispute, three jurors voting in secret, reveal, and a "Hunter won" verdict with the payout received.
- Demo Mode (`/demo`) replays the full story automatically (10 steps).
- During development an automated browser-simulation test (45 checks) was used; it is not part of the repository.

## 8. The Sepolia deployment

### 8.1 Procedure

The deployer was a fresh wallet created with `cast wallet new` and stored as an encrypted Foundry keystore; no private key was typed on a command line. Contracts were deployed and verified in one command (`forge script … --account sepolia-deployer --broadcast --verify`). An Alchemy endpoint and an Etherscan API key were kept in git-ignored files.

### 8.2 Result

- 8 contracts deployed in one block (12,092,383) and **all 8 verified** on Etherscan.
- Total cost **0.0000255663 ETH**.
- Observation: on Sepolia the gas *units* reported were several times higher than on the local chain (a plain ETH transfer used 204,600 gas rather than 21,000), but the gas *price* was extremely low (about 0.0002 gwei), so the cost stayed negligible.

| Contract | Address |
|---|---|
| BountyToken | `0xCC21a5053aA68448c8d3f834f871AB2e4ABe548b` |
| PlatformTreasury | `0xABbB286C7004AC155107339a949E1c31Fb1f2f3A` |
| ReputationSBT | `0xF03bEAE3815844a43F8B6E42f67597Bc73dA07Ef` |
| BountyFactory | `0x3818c819040026d00FCb8b48F087ECcC2fC610f2` |
| BountyEscrow (logic) | `0x0988548a351306f8902Fce08fE588bD5635E3767` |
| ReportRegistry | `0xDd9567FB62acaAd7443676cBF818E68c9307384F` |
| DisputeCourt | `0x1Cba892C2375a0d5546EdE336Df45cB27Ca3d30f` |
| ProgramDirectory | `0x227B36b2a0650F9Ddf5e8C16b9ac5e4fBB935B7E` |

Deployment transactions: BountyToken `0x6288f410a7d3aae717a87b0687b380258d9449d799f71bc9604e5bc2632eee94`, ReputationSBT `0xa6e9e5c9b1a2eefa51ab31aeceb6acae289b19ddc83a97795be6facabc248c49`, PlatformTreasury `0x056764cf08852d974165b048ff1af5197fb985301917bd4fa7e14c87206da218`, BountyFactory `0x580b2a0f22905ec4acd326a3660186bc8a6c24399d5b8c26a70cc9c13c5d0d95`, ReportRegistry `0x1c57b5f4001c2b96d848607a1fb3dd5db83cf6e095ad05c0a4b18b4d7e35d064`, DisputeCourt `0x86e7ce8071fd3207409c1ba37fe84bbf06f6d91736608ce247ea1f6b3856cd0c`, ProgramDirectory `0x40a12a0e656074e7f375858f9def6e7a895b31f9f9456b6491463c56cab29815`.

### 8.3 Live flow on Sepolia

Five fresh accounts (company, hunter, three jurors) were funded from the deployer. Through the web app: the company created the program "Acme Sepolia" with a 0.05 ETH deposit; the hunter committed and revealed an encrypted report (claiming High); the company decrypted it, confirmed it matched the committed hash, and accepted; the hunter was paid and the report showed **Paid**.

Evidence on Etherscan (Registry events): `ReportCommitted`, `ReportRevealed` (claimed severity 2 = High) and `RewardPaid` (severity 2, to the hunter).

![Factory contract verified](screenshots/01-etherscan-factory.png)
![Registry events: payment](screenshots/02-etherscan-registry-paid.png)
![Registry events: commit and deployment](screenshots/03-etherscan-registry-commit-deploy.png)

   Transaction links: [commit](https://sepolia.etherscan.io/tx/0x39c3f3c755134ceacde0ec65504ae3145de3b22c7c97e5a858acba2aa5d58c7c), [reveal](https://sepolia.etherscan.io/tx/0x8d398e84ba1112deb9d1f691d21ab7356b26871c7d870d256f8406a50da873cf), [accept and pay](https://sepolia.etherscan.io/tx/0x03ace2c806bc9d3257d2589ee60dadd5eff376c2ddfcd3e61cd6c8170f6e667e).

The jury path was executed on the local chain (where time can be advanced) and covered by the automated scenario tests; it was not repeated on Sepolia because its windows run in real time.

## 9. Frontend and user experience

Pages: Programs (list, detail, create, submit), Company (read, decrypt, accept, reject, withdraw), Hunter (my reports, dispute, faucet), Jury (stake, cases, vote, reveal, resolve), Profile (badge and XP), Leaderboard, Demo Mode, and a live activity ticker.

Notable choices: chips, hexagons and a glass-arc motif from a written design system; animations with reduced-motion support; keyboard focus rings and live-region announcements; plain-language errors; a pre-flight gas estimate; polling speed that depends on the network; a leaderboard and feed that still work when a node refuses large event queries; links from each transaction and from the footer to Etherscan on Sepolia.

## 10. Mapping to the syllabus (26ITPC71)

| Module | Topic | Where it appears |
|---|---|---|
| 1 | Hash functions, block structure, consensus | keccak256 commitments and content hashes; the report explains finality on Ethereum. Merkle trees are discussed conceptually and are not implemented. |
| 3 | EVM, MetaMask, EOAs vs contract accounts, transactions (nonce, gas, value, data) | Wallet flows on both networks; escrow clones and the Registry as contract accounts; a stale-nonce problem after restarting the local chain was met and solved |
| 3 | Solidity, development environment, test networks, DApps | Eight contracts with Foundry (a modern alternative to Remix/Truffle), local Anvil, Sepolia deployment, a full DApp |
| 3 (self-learning) | Gas optimisation, vulnerabilities, wallet security | EIP-1167 clones; gas headroom; reentrancy, access control, front-running (commit-reveal), randomness weakness, hostile receivers; keystore-based deployment |
| 4 | Hyperledger Fabric | Not used. A public chain suits open bounties because anyone can verify the escrow and the verdict without trusting an operator; Fabric would suit a closed consortium with known members. |
| 5 | ERC-20, ERC-721, tokenisation, digital ownership | BountyToken (ERC-20); ReputationSBT (ERC-721, non-transferable); rewards tokenised as escrow credits |
| 6 | Staking, DAO-style governance, DeFi and EVM security, privacy | Juror staking and slashing; a jury that governs disputes with no admin; the security analysis; privacy through commit-reveal and encryption. zk-SNARKs are noted as future work. |

## 11. Limitations and future work

- Verifiable randomness (a VRF) for the jury draw; economic analysis of stake and fee sizes.
- Let jurors see the decrypted evidence under a controlled disclosure scheme.
- Real IPFS storage by default and key backup or recovery for the company's decryption key.
- Governance of parameters; multi-severity disputes; a formal audit.
- A zero-knowledge proof of reputation level for privacy-preserving credentials.

## 12. Conclusion

VaultHunt shows that the three things bug bounties lack, provable priority, guaranteed payment and an accountable judge, can be built from a small set of well-tested contracts. The project is backed by 299 passing tests, 99.82% line coverage, a clean static-analysis result at High severity, a published and verified deployment, and a working interface.

## Appendix A: viva one-liners

- **Why blockchain?** The money and the verdict shouldn't belong to one party.
- **Why eight contracts?** Separation of concerns: money, evidence, judgement, reputation and discovery each have their own contract.
- **Why commit-reveal?** It proves "I found it first" without exposing the bug.
- **Why soulbound reputation?** Reputation you can buy isn't reputation.
- **What can't it do?** It cannot decide whether a bug is real; it only enforces a fair process.
- **What if the company goes silent?** After the deadline anyone can escalate; ties after a timeout go to the hunter.
- **Why pull payments?** A hostile receiver can't block anyone else's payout.
