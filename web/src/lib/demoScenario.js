// Demo Mode: plays the whole VaultHunt story by itself on the LOCAL Anvil chain, using Anvil's
// built-in (public, worthless) test accounts. No wallet is needed. Used for presentations.
import { createPublicClient, createWalletClient, encodeAbiParameters, formatEther, http, keccak256, parseAbiParameters, parseEther, parseEventLogs, toBytes } from "viem";
import { abis } from "@/lib/contracts";
import { decryptReport, encryptReport, generateCompanyKeys, randomBytes32 } from "@/lib/crypto";
import { jumpTo } from "@/lib/devtools";
import { putJson } from "@/lib/ipfs";
import { anvil } from "@/lib/wagmi";

export const ACCOUNTS = {
  deployer: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  company: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  hunter: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
};

const eth = (wei) => Number(formatEther(wei)).toLocaleString(undefined, { maximumFractionDigits: 4 });

export function createContext(book) {
  const publicClient = createPublicClient({ chain: anvil, transport: http() });
  const wallet = createWalletClient({ chain: anvil, transport: http() });
  const ctx = {
    book,
    publicClient,
    s: {}, // state shared between steps
    read: (address, abi, functionName, args = []) => publicClient.readContract({ address, abi, functionName, args }),
    /** One transaction from an Anvil account: estimate, add 30% headroom, send, wait. */
    async send(from, address, abi, functionName, args = [], value) {
      const estimate = await publicClient.estimateContractGas({ address, abi, functionName, args, value, account: from });
      const hash = await wallet.writeContract({ address, abi, functionName, args, value, account: from, gas: (estimate * 13n) / 10n });
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success") throw new Error(`${functionName} failed on-chain`);
      return receipt;
    },
  };
  return ctx;
}

async function commit(c, key, title, body) {
  const plaintext = JSON.stringify({ title, body, hunter: ACCOUNTS.hunter, createdAt: new Date().toISOString() });
  const contentHash = keccak256(toBytes(plaintext));
  const salt = randomBytes32();
  const commitHash = keccak256(encodeAbiParameters(parseAbiParameters("bytes32, bytes32, address"), [contentHash, salt, ACCOUNTS.hunter]));
  const receipt = await c.send(ACCOUNTS.hunter, c.book.ReportRegistry, abis.ReportRegistry, "commitReport", [c.s.programId, commitHash]);
  const [log] = parseEventLogs({ abi: abis.ReportRegistry, eventName: "ReportCommitted", logs: receipt.logs });
  c.s[key] = { id: log.args.reportId, plaintext, contentHash, salt };
  return log.args.reportId;
}

async function reveal(c, key) {
  const r = c.s[key];
  const encrypted = await encryptReport(r.plaintext, c.s.keys.publicJwk);
  const cid = await putJson({ v: 1, hunter: ACCOUNTS.hunter, reportId: Number(r.id), contentHash: r.contentHash, summary: "Demo report (public summary)", package: encrypted });
  r.cid = cid;
  await c.send(ACCOUNTS.hunter, c.book.ReportRegistry, abis.ReportRegistry, "revealReport", [r.id, cid, r.contentHash, r.salt, 2]);
}

export const STEPS = [
  {
    title: "The company opens a vault and publishes its encryption key",
    actor: "Company",
    async run(c) {
      c.s.keys = await generateCompanyKeys();
      const cid = await putJson({ v: 1, name: `Demo Corp ${new Date().toLocaleTimeString()}`, description: "Created by Demo Mode.", owner: ACCOUNTS.company, publicKey: c.s.keys.publicJwk, createdAt: new Date().toISOString() });
      const receipt = await c.send(ACCOUNTS.company, c.book.BountyFactory, abis.BountyFactory, "createProgram", [ACCOUNTS.company, [500, 1500, 3000, 5000]], parseEther("10"));
      const [created] = parseEventLogs({ abi: abis.BountyFactory, eventName: "ProgramCreated", logs: receipt.logs });
      c.s.programId = created.args.programId;
      c.s.escrow = created.args.escrow;
      await c.send(ACCOUNTS.company, c.book.ProgramDirectory, abis.ProgramDirectory, "setProfile", [c.s.programId, cid]);
      return `Vault #${c.s.programId} now holds 10 ETH. Only this company's key can open reports sent to it.`;
    },
  },
  {
    title: "A hunter commits proof of a bug, without showing it",
    actor: "Hunter",
    async run(c) {
      const id = await commit(c, "r1", "SQL injection in login", "POST /login with username=' OR 1=1 -- bypasses authentication.");
      return `Report #${id}: only a hash and a timestamp are public. Nobody can steal the idea now.`;
    },
  },
  {
    title: "The report is encrypted, uploaded, and the reward is locked",
    actor: "Hunter",
    async run(c) {
      await reveal(c, "r1");
      const locked = await c.read(c.s.escrow, abis.BountyEscrow, "totalLocked");
      return `Locked for the hunter: ${eth(locked)} ETH. The company can no longer withdraw it.`;
    },
  },
  {
    title: "The company decrypts the report and checks it against the hash",
    actor: "Company",
    async run(c) {
      const report = await c.read(c.book.ReportRegistry, abis.ReportRegistry, "getReport", [c.s.r1.id]);
      const stored = await (await fetch(`/api/ipfs/${report.cid}`)).json();
      const text = await decryptReport(stored.package, c.s.keys.privateJwk);
      const ok = keccak256(toBytes(text)) === report.contentHash;
      if (!ok) throw new Error("The decrypted report does not match the committed hash");
      return `Decrypted in the browser. The text matches the hash committed earlier: "${JSON.parse(text).title}".`;
    },
  },
  {
    title: "The company accepts, and the hunter is paid by code",
    actor: "Company",
    async run(c) {
      const before = await c.publicClient.getBalance({ address: ACCOUNTS.hunter });
      await c.send(ACCOUNTS.company, c.book.ReportRegistry, abis.ReportRegistry, "acceptReport", [c.s.r1.id, 2]);
      const after = await c.publicClient.getBalance({ address: ACCOUNTS.hunter });
      const xp = await c.read(c.book.ReportRegistry, abis.ReportRegistry, "hunterXp", [ACCOUNTS.hunter]);
      return `The hunter received ${eth(after - before)} ETH. Reputation is now ${xp} XP on a soulbound badge.`;
    },
  },
  {
    title: "A second report is submitted, and this time the company rejects it",
    actor: "Hunter, Company",
    async run(c) {
      await commit(c, "r2", "Stored XSS in profile page", "The display name field renders raw HTML.");
      await reveal(c, "r2");
      await c.send(ACCOUNTS.company, c.book.ReportRegistry, abis.ReportRegistry, "rejectReport", [c.s.r2.id]);
      return "Report rejected. Its reward stays locked while the hunter decides whether to dispute.";
    },
  },
  {
    title: "The hunter disputes it, and the court draws 3 random jurors",
    actor: "Hunter",
    async run(c) {
      const b = c.book;
      const fee = await c.read(b.DisputeCourt, abis.DisputeCourt, "disputeFee");
      const balance = await c.read(b.BountyToken, abis.BountyToken, "balanceOf", [ACCOUNTS.hunter]);
      if (balance < fee) await c.send(ACCOUNTS.hunter, b.BountyToken, abis.BountyToken, "faucet");
      const allowance = await c.read(b.BountyToken, abis.BountyToken, "allowance", [ACCOUNTS.hunter, b.DisputeCourt]);
      if (allowance < fee) await c.send(ACCOUNTS.hunter, b.BountyToken, abis.BountyToken, "approve", [b.DisputeCourt, fee]);
      await c.send(ACCOUNTS.hunter, b.DisputeCourt, abis.DisputeCourt, "payDisputeFee", [c.s.r2.id]);
      await c.send(ACCOUNTS.hunter, b.ReportRegistry, abis.ReportRegistry, "escalate", [c.s.r2.id]);
      c.s.caseId = await c.read(b.DisputeCourt, abis.DisputeCourt, "caseOfReport", [c.s.r2.id]);
      c.s.jurors = await c.read(b.DisputeCourt, abis.DisputeCourt, "jurorsOf", [c.s.caseId]);
      return `Case #${c.s.caseId} opened. Jurors: ${c.s.jurors.map((j) => `${j.slice(0, 6)}…${j.slice(-4)}`).join(", ")}. The hunter and the company can never be drawn.`;
    },
  },
  {
    title: "The jurors vote in secret (hidden votes)",
    actor: "Jurors",
    async run(c) {
      c.s.salts = {};
      for (const juror of c.s.jurors) {
        const salt = randomBytes32();
        c.s.salts[juror] = salt;
        const hash = keccak256(encodeAbiParameters(parseAbiParameters("bool, bytes32, address, uint256"), [true, salt, juror, c.s.caseId]));
        await c.send(juror, c.book.DisputeCourt, abis.DisputeCourt, "commitVote", [c.s.caseId, hash]);
      }
      return "Three votes committed as hashes. No juror can see another's vote or copy it.";
    },
  },
  {
    title: "Time jumps to the reveal phase, and the jurors reveal",
    actor: "Jurors",
    async run(c) {
      const courtCase = await c.read(c.book.DisputeCourt, abis.DisputeCourt, "getCase", [c.s.caseId]);
      await jumpTo(Number(courtCase.commitDeadline) + 1);
      for (const juror of c.s.jurors) {
        await c.send(juror, c.book.DisputeCourt, abis.DisputeCourt, "revealVote", [c.s.caseId, true, c.s.salts[juror]]);
      }
      return "All three revealed: hunter 3, company 0. (The clock jump is a demo shortcut; real windows run on real time.)";
    },
  },
  {
    title: "The verdict is applied and the hunter is paid",
    actor: "Anyone",
    async run(c) {
      const before = await c.publicClient.getBalance({ address: ACCOUNTS.hunter });
      await c.send(ACCOUNTS.deployer, c.book.DisputeCourt, abis.DisputeCourt, "resolveCase", [c.s.caseId]);
      const after = await c.publicClient.getBalance({ address: ACCOUNTS.hunter });
      const report = await c.read(c.book.ReportRegistry, abis.ReportRegistry, "getReport", [c.s.r2.id]);
      if (Number(report.status) !== 6) throw new Error("The report is not paid after the verdict");
      return `Hunter won. The jury's verdict paid ${eth(after - before)} ETH at once, and the jurors who voted with it share the dispute fee.`;
    },
  },
];
