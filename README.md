# VaultHunt

**A decentralized escrow system for bug bounty hunters.** A company locks a reward in its own on-chain vault. A hunter proves, without revealing the bug, that they found it first. The report is encrypted so only the company can read it. If the company rejects or ignores it, a randomly drawn, staked jury decides, and the verdict pays out by code.

> Testnet prototype for the Blockchain Technology course (26ITPC71, Semester VII). **Not audited. Never use real funds.**

| | |
|---|---|
| Network | Ethereum Sepolia (chain id 11155111), plus a local Anvil chain for development |
| Contracts | 8, all verified on Etherscan |
| Contracts language | Solidity 0.8.38, OpenZeppelin 5.7, built and tested with Foundry |
| App | Next.js 16 (JavaScript), Tailwind CSS 4, wagmi 2 + viem, Framer Motion |
| Tests | 299 passing (unit, integration, scenario, fuzz, invariant); 99.82% line coverage |
| Static analysis | Slither: 0 High findings |

Team Members: `Atharva Lotankar (20), Vaishnavi Avhad(02), Bhoomi Naik(22)` · Subject: `Blockchain Technology` · Term Work: `Mini Project` · Licence: `NA` (see "Licences" below)

---

## 1. What it does

| Role | What they do |
|---|---|
| **Company** | Opens a vault (name, scope, reward tiers, deposit). Publishes a public encryption key. Reads reports, accepts or rejects. |
| **Hunter** | Commits a hash of the finding (proof of who was first), encrypts and uploads the report, reveals it (which locks the reward). Gets paid by code, earns a soulbound reputation badge. |
| **Juror** | Stakes the platform token (BBT), is drawn at random for disputes, votes in secret, then reveals. Voting with the majority earns a share of the dispute fee; voting against it, or not revealing, is slashed. |

The story in one line: **lock it, prove it, get paid.**

## 2. The eight contracts

| Contract | Standard / pattern | Job |
|---|---|---|
| `BountyToken` (BBT) | ERC-20 | Staking and dispute fees; testnet faucet (100 BBT per claim) |
| `BountyFactory` | Factory + EIP-1167 minimal-proxy clones | Creates one cheap escrow per program |
| `BountyEscrow` | Clone, pull payments, ReentrancyGuard | Holds one program's funds, reward tiers, locks and credits |
| `ReportRegistry` | Commit-reveal, single orchestrator | The only address escrows obey; report lifecycle; calls Court and badge |
| `DisputeCourt` | Staked jury, hidden votes, slashing | Draws jurors, collects votes, applies the verdict. No owner, no admin. |
| `ReputationSBT` | ERC-721, soulbound | Hunter level badge (levels rise with XP, up to Legend); cannot be transferred |
| `PlatformTreasury` | Access-controlled vault | Receives platform-side funds (for example the pot when no juror reveals) |
| `ProgramDirectory` | Pointer registry | Lets a program owner publish an IPFS pointer to its public profile and public key |

```
 Company --> BountyFactory --clones--> BountyEscrow <-- lock / pay / refund (Registry ONLY)
                                                              ^
 Hunter  --> ReportRegistry ----------------------------------+--> ReputationSBT (badge)
                 ^   |
                 |   +--escalate--> DisputeCourt --verdict--> ReportRegistry
                 |                     |  stakes/fees: BountyToken, dust: PlatformTreasury
 Company/Hunter --> ProgramDirectory (profile + PUBLIC key pointer)
```

## 3. Live on Sepolia

Deployer (public address): `0xB5D97277532eb488e20F656ec3BACdbA8F8Db438`. The whole deployment cost about **0.0000256 ETH**. Addresses are also in `contracts/deployments/11155111.json`.

| Contract | Address (Etherscan) |
|---|---|
| BountyToken | [`0xCC21a5053aA68448c8d3f834f871AB2e4ABe548b`](https://sepolia.etherscan.io/address/0xCC21a5053aA68448c8d3f834f871AB2e4ABe548b) |
| BountyFactory | [`0x3818c819040026d00FCb8b48F087ECcC2fC610f2`](https://sepolia.etherscan.io/address/0x3818c819040026d00FCb8b48F087ECcC2fC610f2) |
| BountyEscrow (logic) | [`0x0988548a351306f8902Fce08fE588bD5635E3767`](https://sepolia.etherscan.io/address/0x0988548a351306f8902Fce08fE588bD5635E3767) |
| ReportRegistry | [`0xDd9567FB62acaAd7443676cBF818E68c9307384F`](https://sepolia.etherscan.io/address/0xDd9567FB62acaAd7443676cBF818E68c9307384F) |
| DisputeCourt | [`0x1Cba892C2375a0d5546EdE336Df45cB27Ca3d30f`](https://sepolia.etherscan.io/address/0x1Cba892C2375a0d5546EdE336Df45cB27Ca3d30f) |
| ReputationSBT | [`0xF03bEAE3815844a43F8B6E42f67597Bc73dA07Ef`](https://sepolia.etherscan.io/address/0xF03bEAE3815844a43F8B6E42f67597Bc73dA07Ef) |
| PlatformTreasury | [`0xABbB286C7004AC155107339a949E1c31Fb1f2f3A`](https://sepolia.etherscan.io/address/0xABbB286C7004AC155107339a949E1c31Fb1f2f3A) |
| ProgramDirectory | [`0x227B36b2a0650F9Ddf5e8C16b9ac5e4fBB935B7E`](https://sepolia.etherscan.io/address/0x227B36b2a0650F9Ddf5e8C16b9ac5e4fBB935B7E) |

A full flow (vault, deposit, commit, reveal, accept, pay) was run on Sepolia through the app; see `PROJECT_REPORT.md` and `screenshots/`. Windows on Sepolia: company review 10 min, reveal 10 min, dispute 10 min; jury commit 5 min, reveal 5 min, unstake cooldown 10 min (short on purpose, for demos).

## 4. Folder structure

```
contracts/            Foundry project
  src/                the 8 contracts + interfaces
  test/               unit, integration, scenario, fuzz, invariant tests
  script/             Deploy.s.sol, Seed.s.sol (local demo data), DeployBase.sol
  deployments/        <chainId>.json address files (31337 is git-ignored; 11155111 is committed)
  SECURITY.md         threat model, mitigations, problems found and fixed
  LIMITATIONS.md      what this prototype does NOT do
web/                  Next.js app (JavaScript)
  src/app/            pages: programs, company, hunter, jury, profile, leaderboard, demo, API routes
  src/components/     UI parts (chips, hexagons, panels), wallet button, jury and report components
  src/lib/            wagmi config, contract reads, encryption, transactions
  src/contracts/      ABIs and addresses, generated by `pnpm sync`
  DEMO_SCRIPT.md      a 6-minute walkthrough
tasks-docs/           PRD, TechStack, design system, milestone log
screenshots/          evidence (Etherscan pages and app screens)
```

## 5. Setup (Windows)

**Install once:** Git, Node.js 20.9 or newer (tested on 24), pnpm 12, Foundry (`forge`, `anvil`, `cast`), MetaMask in your browser. Optional: Python 3 and `pip install slither-analyzer` for static analysis.

```text
git clone https://github.com/AtharvaLotankar11/vaulthunt-escrow-blockchain-project
cd vaulthunt-escrow-blockchain-project
```

OpenZeppelin and forge-std are in `contracts\lib`. If that folder is missing, run `forge install OpenZeppelin/openzeppelin-contracts@v5.7.0 foundry-rs/forge-std` inside `contracts`.

### Run the tests
```text
cd contracts
forge test
forge coverage --report summary --no-match-coverage "script|test"
slither . --filter-paths "test|script|lib"
```

### Run everything locally (3 terminals)
1. `anvil`
2. In `contracts`:
   ```text
   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <Anvil account 0 key printed by anvil>
   forge script script/Seed.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   ```
   Anvil's keys are public test keys. Run Seed once per fresh Anvil.
3. In `web`:
   ```text
   pnpm install
   pnpm sync
   pnpm dev
   ```
   Open http://localhost:3000. For the wallet: import Anvil accounts into MetaMask, add the Anvil network when the app offers. After restarting Anvil, clear MetaMask's activity data (Settings, Advanced).

**Fastest demo:** open `/demo` and click "Simulate full scenario". It plays the whole story with Anvil's built-in accounts, no wallet needed.

### Run on Sepolia
1. In `contracts`, create `.env` (git-ignored): `SEPOLIA_RPC=<your Alchemy Sepolia link>` and `ETHERSCAN_API_KEY=<your key>`.
2. Create a deployer keystore (the private key is never printed): `cast wallet new "%USERPROFILE%\.foundry\keystores" sepolia-deployer`. Fund its address from a Sepolia faucet.
3. Deploy and verify:
   ```text
   forge script script/Deploy.s.sol --rpc-url sepolia --account sepolia-deployer --sender <deployer address> --broadcast --verify
   ```
4. In `web`, create `.env.local` (git-ignored): `NEXT_PUBLIC_DEFAULT_CHAIN=sepolia` and `NEXT_PUBLIC_SEPOLIA_RPC=<your Alchemy link>`, then `pnpm sync` and `pnpm dev`. Use fresh MetaMask accounts for Sepolia (never the Anvil accounts: their keys are public and bots sweep them).

### Configuration files
| File | Contains | In git? |
|---|---|---|
| `contracts/.env` | `SEPOLIA_RPC`, `ETHERSCAN_API_KEY` | No |
| `web/.env.local` | `NEXT_PUBLIC_DEFAULT_CHAIN`, `NEXT_PUBLIC_SEPOLIA_RPC`, optional `PINATA_JWT` | No |
| `.env.example`, `web/.env.local.example` | empty templates | Yes |
| Foundry keystore (`~/.foundry/keystores`) | encrypted deployer key | No (outside the repo) |

## 6. Test and audit results

Run on the final code (Windows, Foundry 1.9.1-nightly, Solc 0.8.38):

| Check | Result |
|---|---|
| `forge test` | **299 passed, 0 failed** (20 suites: unit tests for all 8 contracts, integration, end-to-end scenarios, fuzz tests, and 9 invariants in 3 suites) |
| Coverage (src only) | **99.82% lines**, 99.82% statements, 97.03% branches, 100% functions |
| Slither | 26 results, **0 High**; the 2 Medium are reviewed and documented, the rest are Low or Informational |
| `pnpm lint`, `pnpm build` | pass (12 pages, 2 API routes) |
| Secrets | `.env` and `.env.local` are not tracked; only `.env.example` files are |

Details, the bugs found and fixed, and the mutation checks are in `contracts/SECURITY.md` and `PROJECT_REPORT.md`.

## 7. Limitations and known issues

Full list in `contracts/LIMITATIONS.md`. The important ones:
- **Juror selection uses pseudo-randomness derived from `block.prevrandao`**, which a block proposer can influence slightly. Production would use a verifiable random function.
- **Jurors cannot read the encrypted report**; they see only the hunter's public summary.
- **Reports and profiles are stored through a local API route** (`web/.data`) unless a Pinata key is set. Secrets (company key, unrevealed report, juror vote) live in one browser's localStorage. Back them up.
- **Time windows are demo-sized** (minutes). Real programs would use days.
- **Fonts:** the licensed fonts are not installed; fallbacks are used (see `web/DESIGN_NOTES.md`).
- **Sepolia's lifetime:** it was scheduled to be retired in September 2026; a report from October 2026 says support was extended through 2027. Check before relying on it.
- **MetaMask after restarting Anvil** shows stale transaction numbers; clear activity data.

## 8. Licences and credits

Built with OpenZeppelin Contracts (MIT), Foundry, Next.js, Tailwind CSS, wagmi and viem, Framer Motion, lucide-react. The project licence is for the team to choose (`NA`).
