# TechStack.md: Decentralized Escrow System for Bug Bounty Hunters

**Companion to:** PRD.md (v0.1)
**Principle:** one tool per job, no overlap. Every tool below exists because a feature in the PRD needs it. If a tool has no feature to serve, it isn't here.

---

## 1. The stack at a glance (8 tools, 4 layers)

| Layer | Tool | Its one job | Serves PRD feature |
|---|---|---|---|
| **Contracts** | **Solidity + OpenZeppelin** | Write the 7 contracts using audited building blocks | All on-chain logic (Escrow, Registry, Court, SBT, Token, Factory, Treasury) |
| **Dev and test** | **Foundry** (forge, anvil, cast) | Compile, test, fuzz, deploy, and run a local chain | Testing (PRD section 13), deployment |
| **Frontend** | **Next.js + JavaScript** | The app itself: pages, routing, small server routes | Dashboards, program pages, report flow |
| **Frontend UI** | **Tailwind + shadcn/ui + Framer Motion** | Look, feel, animation | Vault animation, jury room, live feed (PRD section 9) |
| **Wallet and chain link** | **wagmi + viem + RainbowKit** | Connect MetaMask, send transactions, read state, listen to events | Wallet connect, live activity ticker |
| **Storage** | **IPFS via Pinata** | Hold encrypted report files | Private report storage |
| **Encryption** | **Web Crypto API** (built into the browser) | Encrypt report before upload, decrypt after | Report privacy |
| **Network** | **Anvil (local) then Sepolia (testnet)** | Where contracts live | Demo and submission |

Two helpers, not counted above: **Slither** (security scan) and **Remix** (quick first experiments and syllabus demo only).

---

## 2. How the tools connect (the "friends" map)

```
                     YOU WRITE                        YOU RUN
              +--------------------+          +----------------------+
              |  Solidity contracts|--forge-->|  Anvil (local chain) |
              |  (+ OpenZeppelin)  |  test    |  then Sepolia        |
              +---------+----------+          +----------+-----------+
                        |                                ^
              forge build makes ABIs                     | transactions / events
                        v                                |
              +--------------------+          +----------+-----------+
              |  sync-abis.js      |--ABIs--->|  wagmi + viem        |
              |  (copies ABIs and  | + addrs  |  (in Next.js app)    |
              |   addresses)       |          +----------+-----------+
              +--------------------+                     |
                                                         v
                  +-----------------+   upload/fetch   +-----------+
                  | Web Crypto      |----------------->|   IPFS    |
                  | (encrypt in     |  encrypted file  |  (Pinata) |
                  |  the browser)   |                  +-----------+
                  +-----------------+
```

**The one link that ties it together:** Foundry builds the contracts, and a tiny script (`sync-abis.js`, about 20 lines of Node) copies each contract's ABI and the deployed addresses into the web app. Change a contract, run the script, and the frontend has the new functions. No manual copy-pasting of ABIs and addresses.

---

## 3. One report's journey through the stack

This shows each tool doing its part, in order.

| Step | What happens | Tool doing the work |
|---|---|---|
| 1 | Hunter writes report, clicks Submit | Next.js + shadcn/ui |
| 2 | Report is encrypted in the browser (AES key, wrapped for the company's public key) | Web Crypto |
| 3 | Encrypted file is uploaded; a CID (file address) comes back | Pinata / IPFS |
| 4 | Hunter signs `commit(hash)` then later `reveal(cid, salt)` | wagmi + viem + MetaMask |
| 5 | `ReportRegistry` stores hash and timestamp, emits an event | Solidity on Sepolia |
| 6 | Company's dashboard updates instantly from the event | viem event watching |
| 7 | Company clicks Accept; `BountyEscrow` pays the hunter | wagmi, then Solidity |
| 8 | Vault animation plays, XP bar rises, badge minted | Framer Motion, `ReputationSBT` |
| 9 | If disputed: `DisputeCourt` runs the jury vote | Solidity, with live UI via events |

---

## 4. Why each choice (short and honest)

### Solidity + OpenZeppelin
Solidity is the syllabus language (Module 3). OpenZeppelin gives ready, audited code for ERC-20, ERC-721, access control, reentrancy guard, and minimal-proxy clones, so we write business logic, not boilerplate.

### Foundry (chosen over Hardhat)
- Tests are written in Solidity, the same language as the contracts: less context switching.
- Built-in fuzz and invariant testing, which directly supports the security goals.
- Anvil gives an instant local chain; deploy scripts are also Solidity.
- Its build output (ABI JSON files) is plain JSON, which a JavaScript frontend can import directly.
- *Trade-off:* Hardhat has more beginner tutorials. If the team strongly prefers JavaScript tests, Hardhat is a valid swap, but pick one, never both.

### Next.js + JavaScript (chosen over TypeScript)
One framework gives routing, components, and small server routes (needed to keep the Pinata key secret). Plain JavaScript keeps the learning curve low: no type definitions to write, faster to build, easier for every team member to read.
- *Trade-off:* JavaScript will not warn you at build time if you pass the wrong argument to a contract call. Reduce this risk with **ESLint** (comes with Next.js), by keeping all contract calls in one small `lib/contracts.js` file, and by testing each flow on Anvil early.

### wagmi + viem + RainbowKit
- **viem:** the low-level tool to read, write, and listen to the chain.
- **wagmi:** React hooks on top of viem (`useWriteContract`, `useWatchContractEvent`).
- **RainbowKit:** a ready wallet-connect modal. Saves days of UI work.
These three are designed as a set; treat them as one unit.

### Tailwind + shadcn/ui + Framer Motion
Tailwind for styling, shadcn/ui for ready-made components (cards, dialogs, tabs), Framer Motion for the "alive" feel: filling vaults, level-up bursts, step transitions. Together they deliver the interactive look without a custom design system.

### IPFS via Pinata
Reports are too large and too private for the chain. Only the CID (a short address) goes on-chain. Pinata gives a free tier and a simple API.

### Web Crypto API (no extra library)
Built into every modern browser. Plan:
- Encrypt the report with **AES-GCM**.
- Wrap the AES key with the company's **RSA-OAEP public key**.
- The company holds the private key and decrypts in its own browser.

> **Demo simplification (state this openly in the viva):** for disputes, the hunter re-wraps the file key for a "court key" so jurors can read the report. A production system would use threshold encryption or a trusted-execution design.

### Sepolia (after local Anvil)
Develop and test on Anvil for speed, then deploy to Sepolia for the real public-testnet demo and Etherscan verification. One testnet only.

---

## 5. What we deliberately are NOT using

| Skipped | Reason |
|---|---|
| **A backend server and database** | The chain is the database. Only a tiny Next.js route hides the Pinata key. Fewer parts, fewer bugs. |
| **The Graph / subgraph** | Event watching in viem plus a one-time log fetch on page load is enough for our scale. |
| **Chainlink VRF** | Needs subscription setup; jury uses simple pseudo-randomness for the demo (documented limitation). Listed as future work. |
| **Hardhat alongside Foundry** | Two toolchains = confusion. |
| **Redux or other state libraries** | wagmi's built-in query cache handles on-chain state. |
| **Hyperledger Fabric** | Not suited to an open, public-trust bounty market; covered by a comparison slide only. |
| **Layer 2 / cross-chain** | Out of MVP scope. |

---

## 6. Repository layout (one repo, two folders)

```
vaulthunt/
├── contracts/                 # Foundry project
│   ├── src/                   # the 7 contracts
│   ├── test/                  # unit, fuzz, invariant, scenario tests
│   ├── script/                # Deploy.s.sol
│   └── foundry.toml
├── web/                       # Next.js app
│   ├── src/app/               # pages (programs, report, dispute, profile)
│   ├── src/components/        # vault card, ticker, stepper, jury room
│   ├── src/lib/               # crypto.js, ipfs.js, contracts.js
│   ├── src/contracts/         # ABIs + addresses.json (copied by the sync script)
│   └── scripts/sync-abis.js   # run after every build or deploy
└── README.md
```

---

## 7. Setup cheat-sheet

**Contracts**
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge init contracts && cd contracts
forge install OpenZeppelin/openzeppelin-contracts
forge test            # run tests
anvil                 # start local chain (separate terminal)
```

**Frontend**
```bash
pnpm create next-app web --js --tailwind
cd web
pnpm add wagmi viem @tanstack/react-query @rainbow-me/rainbowkit framer-motion
npx shadcn@latest init
```

**Link them:** after `forge build` or a deploy, run `node web/scripts/sync-abis.js`. It reads `contracts/out/*.json` and the deploy output, then writes ABIs and `addresses.json` into `web/src/contracts/`.

**Deploy**
```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC --broadcast --verify
```

**Environment variables (never commit these)**
```
SEPOLIA_RPC=            # from any RPC provider
PRIVATE_KEY=            # test wallet only, never a real one
ETHERSCAN_API_KEY=      # for contract verification
PINATA_JWT=             # server-side only (Next.js route)
NEXT_PUBLIC_WALLETCONNECT_ID=
```

> Commands and package names change over time. Check each tool's official docs at build time.

---

## 8. Who owns which tool (matches PRD team split)

| Member | Tools |
|---|---|
| Contracts A | Solidity, OpenZeppelin, Foundry tests |
| Contracts B | Solidity, Foundry fuzz and invariant tests, Slither |
| Frontend | Next.js, Tailwind, shadcn/ui, Framer Motion, wagmi |
| Integration and docs | Web Crypto, Pinata, `sync-abis.js` link, deployment scripts |

---

## 9. PRD to stack: quick consistency check

| PRD requirement | Covered by |
|---|---|
| 7 smart contracts | Solidity + OpenZeppelin |
| Commit-reveal and private reports | Web Crypto + IPFS + `ReportRegistry` |
| Automatic payout | `BountyEscrow` via wagmi transactions |
| Live, game-like UI | Next.js + Framer Motion + viem events |
| Soulbound reputation | OpenZeppelin ERC-721 with transfer override |
| Juror staking and slashing | `BountyToken` (ERC-20) + `DisputeCourt` |
| 90%+ test coverage, fuzzing | Foundry (`forge coverage`, fuzz, invariants) |
| Security analysis | Slither + Foundry tests |
| Testnet demo | Anvil, then Sepolia + Etherscan verify |

**Result:** 8 tools, 1 language per side (Solidity for chain, JavaScript for app), no server, no database, one tiny script bridging them.
