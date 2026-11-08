// All on-chain reads, as plain async functions. They take { publicClient, book } (the client
// for the current chain and the synced contract addresses) and return plain objects.
import { zeroAddress } from "viem";
import { abis } from "@/lib/contracts";

const read = (publicClient, address, abi, functionName, args = []) =>
  publicClient.readContract({ address, abi, functionName, args });

export async function fetchProgram({ publicClient, book }, id) {
  const escrow = await read(publicClient, book.BountyFactory, abis.BountyFactory, "programs", [BigInt(id)]);
  if (escrow === zeroAddress) return null;
  const e = (fn, args = []) => read(publicClient, escrow, abis.BountyEscrow, fn, args);

  const [owner, funded, locked, unlocked, owed, b0, b1, b2, b3, r0, r1, r2, r3, profileURI, balance] = await Promise.all([
    e("owner"),
    e("fundedAmount"),
    e("totalLocked"),
    e("unlockedBalance"),
    e("totalClaimable"),
    e("payoutBps", [0]),
    e("payoutBps", [1]),
    e("payoutBps", [2]),
    e("payoutBps", [3]),
    e("rewardFor", [0]),
    e("rewardFor", [1]),
    e("rewardFor", [2]),
    e("rewardFor", [3]),
    read(publicClient, book.ProgramDirectory, abis.ProgramDirectory, "profileURI", [BigInt(id)]),
    publicClient.getBalance({ address: escrow }),
  ]);

  return {
    id: Number(id),
    escrow,
    owner,
    funded,
    locked,
    unlocked,
    owed,
    balance,
    bps: [b0, b1, b2, b3].map(Number),
    rewards: [r0, r1, r2, r3],
    profileURI,
  };
}

export async function fetchPrograms(ctx) {
  const { publicClient, book } = ctx;
  const count = Number(await read(publicClient, book.BountyFactory, abis.BountyFactory, "programCount"));
  const programs = await Promise.all(Array.from({ length: count }, (_, i) => fetchProgram(ctx, i)));
  return programs.filter(Boolean);
}

function shapeReport(id, r) {
  return {
    id,
    ...r,
    programId: Number(r.programId),
    status: Number(r.status),
    claimedSeverity: Number(r.claimedSeverity),
    paidSeverity: Number(r.paidSeverity),
    committedAt: Number(r.committedAt),
    revealedAt: Number(r.revealedAt),
    reviewDeadline: Number(r.reviewDeadline),
    rejectedAt: Number(r.rejectedAt),
  };
}

export async function fetchReports({ publicClient, book }) {
  const count = Number(await read(publicClient, book.ReportRegistry, abis.ReportRegistry, "reportCount"));
  const reports = await Promise.all(
    Array.from({ length: count }, (_, i) =>
      read(publicClient, book.ReportRegistry, abis.ReportRegistry, "getReport", [BigInt(i + 1)]).then((r) => shapeReport(i + 1, r)),
    ),
  );
  return reports.reverse(); // newest first
}

export async function fetchRegistryConfig({ publicClient, book }) {
  const r = (fn) => read(publicClient, book.ReportRegistry, abis.ReportRegistry, fn);
  const [reviewPeriod, revealWindow, disputeWindow] = await Promise.all([r("reviewPeriod"), r("revealWindow"), r("disputeWindow")]);
  return { reviewPeriod: Number(reviewPeriod), revealWindow: Number(revealWindow), disputeWindow: Number(disputeWindow) };
}

export async function fetchCourtConfig({ publicClient, book }) {
  const c = (fn) => read(publicClient, book.DisputeCourt, abis.DisputeCourt, fn);
  const [jurorsPerCase, minStake, slashPerJuror, disputeFee, commitPeriod, revealPeriod, unstakeCooldown, poolSize, reserve] =
    await Promise.all([c("jurorsPerCase"), c("minStake"), c("slashPerJuror"), c("disputeFee"), c("commitPeriod"), c("revealPeriod"), c("unstakeCooldown"), c("poolSize"), c("reserve")]);
  return {
    jurorsPerCase: Number(jurorsPerCase),
    minStake,
    slashPerJuror,
    disputeFee,
    commitPeriod: Number(commitPeriod),
    revealPeriod: Number(revealPeriod),
    unstakeCooldown: Number(unstakeCooldown),
    poolSize: Number(poolSize),
    reserve,
  };
}

function shapeCase(id, c) {
  return {
    id,
    ...c,
    reportId: Number(c.reportId),
    status: Number(c.status),
    openedAt: Number(c.openedAt),
    commitDeadline: Number(c.commitDeadline),
    revealDeadline: Number(c.revealDeadline),
    hunterVotes: Number(c.hunterVotes),
    companyVotes: Number(c.companyVotes),
    revealedCount: Number(c.revealedCount),
  };
}

export async function fetchCases({ publicClient, book }) {
  const count = Number(await read(publicClient, book.DisputeCourt, abis.DisputeCourt, "caseCount"));
  const cases = await Promise.all(
    Array.from({ length: count }, (_, i) =>
      read(publicClient, book.DisputeCourt, abis.DisputeCourt, "getCase", [BigInt(i + 1)]).then((c) => shapeCase(i + 1, c)),
    ),
  );
  return cases.reverse();
}

export async function fetchVotes({ publicClient, book }, caseId, jurors) {
  return Promise.all(
    jurors.map((juror) =>
      read(publicClient, book.DisputeCourt, abis.DisputeCourt, "voteInfo", [BigInt(caseId), juror]).then((v) => ({ juror, ...v })),
    ),
  );
}

export async function fetchJuror({ publicClient, book }, address) {
  const c = (fn, args) => read(publicClient, book.DisputeCourt, abis.DisputeCourt, fn, args);
  const t = (fn, args) => read(publicClient, book.BountyToken, abis.BountyToken, fn, args);
  const [stake, unstakeAt, pending, active, inPool, balance, allowance, lastFaucet] = await Promise.all([
    c("jurorStake", [address]),
    c("unstakeAt", [address]),
    c("unstakePending", [address]),
    c("activeCases", [address]),
    c("isInPool", [address]),
    t("balanceOf", [address]),
    t("allowance", [address, book.DisputeCourt]),
    t("lastFaucetTime", [address]),
  ]);
  return { stake, unstakeAt: Number(unstakeAt), pending, active: Number(active), inPool, balance, allowance, lastFaucet: Number(lastFaucet) };
}

export async function fetchHunterProfile({ publicClient, book }, address) {
  const r = (fn, args) => read(publicClient, book.ReportRegistry, abis.ReportRegistry, fn, args);
  const [xp, hasBadge, badgeId] = await Promise.all([r("hunterXp", [address]), r("hasBadge", [address]), r("badgeOf", [address])]);
  let level;
  if (hasBadge) {
    const [onChainLevel] = await read(publicClient, book.ReputationSBT, abis.ReputationSBT, "getReputation", [badgeId]);
    level = Number(onChainLevel);
  }
  return { address, xp: Number(xp), hasBadge, badgeId: Number(badgeId), level };
}

const registryEvent = (publicClient, book, eventName) =>
  publicClient.getContractEvents({
    address: book.ReportRegistry,
    abi: abis.ReportRegistry,
    eventName,
    fromBlock: BigInt(book.DeploymentBlock ?? 0),
    strict: true,
  });

/** Hunters ranked by XP. Built from the reports themselves, so it needs no event history. */
export async function fetchLeaderboard(ctx) {
  const reports = await fetchReports(ctx);
  const hunters = [...new Set(reports.map((r) => r.hunter))];
  const rows = await Promise.all(hunters.map((address) => fetchHunterProfile(ctx, address)));
  return rows.sort((a, b) => b.xp - a.xp);
}

/** Recent platform activity as short sentences, newest first (the live feed). */
async function activityFromLogs({ publicClient, book }) {
  const from = BigInt(book.DeploymentBlock ?? 0);
  const [programs, committed, revealed, paid, rejected, escalated, verdicts] = await Promise.all([
    publicClient.getContractEvents({ address: book.BountyFactory, abi: abis.BountyFactory, eventName: "ProgramCreated", fromBlock: from, strict: true }),
    registryEvent(publicClient, book, "ReportCommitted"),
    registryEvent(publicClient, book, "ReportRevealed"),
    registryEvent(publicClient, book, "RewardPaid"),
    registryEvent(publicClient, book, "ReportRejected"),
    registryEvent(publicClient, book, "ReportEscalated"),
    registryEvent(publicClient, book, "VerdictApplied"),
  ]);
  const short = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;
  const items = [
    ...programs.map((l) => ({ l, text: `Program #${l.args.programId} opened by ${short(l.args.programOwner)}` })),
    ...committed.map((l) => ({ l, text: `${short(l.args.hunter)} committed report #${l.args.reportId}` })),
    ...revealed.map((l) => ({ l, text: `Report #${l.args.reportId} revealed and its reward locked` })),
    ...paid.map((l) => ({ l, text: `${short(l.args.hunter)} was paid for report #${l.args.reportId}` })),
    ...rejected.map((l) => ({ l, text: `Report #${l.args.reportId} was rejected` })),
    ...escalated.map((l) => ({ l, text: `Report #${l.args.reportId} went to the jury${l.args.byTimeout ? " (company timed out)" : ""}` })),
    ...verdicts.map((l) => ({ l, text: `Jury verdict on report #${l.args.reportId}: ${l.args.hunterWins ? "hunter wins" : "company wins"}` })),
  ];
  return items
    .sort((a, b) => Number(b.l.blockNumber - a.l.blockNumber) || b.l.logIndex - a.l.logIndex)
    .slice(0, 12)
    .map(({ l, text }) => ({ key: `${l.blockNumber}-${l.logIndex}`, text }));
}

/** Fallback when the node refuses big event queries: rebuild a short feed from the reports and cases. */
async function activityFromState(ctx) {
  const short = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;
  const [reports, cases, programs] = await Promise.all([fetchReports(ctx), fetchCases(ctx), fetchPrograms(ctx)]);
  const items = [];
  for (const p of programs) items.push({ at: 0, text: `Program #${p.id} opened by ${short(p.owner)}` });
  for (const r of reports) {
    items.push({ at: r.committedAt, text: `${short(r.hunter)} committed report #${r.id}` });
    if (r.revealedAt) items.push({ at: r.revealedAt, text: `Report #${r.id} revealed and its reward locked` });
    if (r.rejectedAt) items.push({ at: r.rejectedAt, text: `Report #${r.id} was rejected` });
    if (r.status === 5) items.push({ at: r.rejectedAt || r.reviewDeadline, text: `Report #${r.id} went to the jury` });
    if (r.status === 6) items.push({ at: r.revealedAt + 1, text: `${short(r.hunter)} was paid for report #${r.id}` });
  }
  for (const c of cases) {
    if (c.status === 2) items.push({ at: c.revealDeadline, text: `Jury verdict on report #${c.reportId}: ${c.hunterWins ? "hunter wins" : "company wins"}` });
  }
  return items
    .sort((a, b) => b.at - a.at)
    .slice(0, 12)
    .map((item, i) => ({ key: `s-${i}`, text: item.text }));
}

export async function fetchActivity(ctx) {
  try {
    return await activityFromLogs(ctx);
  } catch {
    return activityFromState(ctx);
  }
}
