"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { keccak256, encodeAbiParameters, parseAbiParameters } from "viem";
import { useAccount, useChainId } from "wagmi";
import { ProgramLabel } from "@/components/programs/ProgramLabel";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { Countdown } from "@/components/ui/Countdown";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { DemoJump } from "@/components/layout/DemoJump";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { CASE, SEVERITY } from "@/lib/chain";
import { abis } from "@/lib/contracts";
import { randomBytes32 } from "@/lib/crypto";
import { bbt, shortAddress } from "@/lib/format";
import { useBook, useCases, useChainQuery, useChainTime, useCourtConfig, useReports, useVotes } from "@/lib/hooks";
import { getJson } from "@/lib/ipfs";
import { voteSecrets } from "@/lib/secrets";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";

export default function CasePage() {
  const { caseId } = useParams();
  const { address } = useAccount();
  const chainId = useChainId();
  const { book } = useBook();
  const tx = useTx();
  const act = useAction();
  const { data: cases, isError } = useCases();
  const { data: reports } = useReports();
  const { data: now } = useChainTime();
  const { data: court } = useCourtConfig();
  const [choice, setChoice] = useState("hunter");

  const courtCase = (cases ?? []).find((c) => String(c.id) === String(caseId));
  const report = courtCase && (reports ?? []).find((r) => r.id === courtCase.reportId);
  const { data: votes } = useVotes(caseId, courtCase?.jurors);
  const { data: disclosure } = useChainQuery(["disclosure", report?.cid ?? ""], () => getJson(report.cid), { enabled: Boolean(report?.cid), refetchInterval: false });

  if (!book) return <section className="page-x py-12"><NoDeployment chainId={chainId} /></section>;
  if (isError) return <section className="page-x py-12"><ChainDown /></section>;
  if (cases === undefined) return <section className="page-x py-12"><p className="text-muted">Loading…</p></section>;
  if (!courtCase) return <section className="page-x py-12"><StateMessage title="Not found">There is no case #{caseId}.</StateMessage></section>;

  const mine = address ? (votes ?? []).find((v) => v.juror.toLowerCase() === address.toLowerCase()) : undefined;
  const resolved = courtCase.status === CASE.Resolved;
  const committing = now !== undefined && now <= courtCase.commitDeadline;
  const revealing = now !== undefined && now > courtCase.commitDeadline && now <= courtCase.revealDeadline;
  const canResolve = !resolved && now !== undefined && (courtCase.revealedCount === courtCase.jurors.length || now > courtCase.revealDeadline);
  const stored = address ? voteSecrets.load(chainId, caseId, address) : null;

  const call = (label, functionName, args) => act.run(() => tx({ label, address: book.DisputeCourt, abi: abis.DisputeCourt, functionName, args }));

  function commit() {
    return act.run(async () => {
      const hunterWins = choice === "hunter";
      const salt = randomBytes32();
      voteSecrets.save(chainId, caseId, address, { hunterWins, salt }); // before sending: it is needed to reveal
      const hash = keccak256(encodeAbiParameters(parseAbiParameters("bool, bytes32, address, uint256"), [hunterWins, salt, address, BigInt(caseId)]));
      await tx({ label: "Commit vote", address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "commitVote", args: [BigInt(caseId), hash] });
    });
  }

  return (
    <section className="page-x py-12">
      <PageHeader chip={`Case #${courtCase.id}`} title={resolved ? (courtCase.hunterWins ? "Hunter won" : "Company won") : "Jury decision"}>
        <Link href="/jury" className="btn btn--ghost">All cases</Link>
      </PageHeader>

      <div className="grid gap-6 xl:grid-cols-2">
        <Card className="grid gap-3">
          <h2 className="field-label">The dispute</h2>
          <p>Report #{courtCase.reportId} in {report ? <ProgramLabel programId={report.programId} /> : "…"}. Hunter {shortAddress(courtCase.hunter)} against the company.</p>
          <p className="text-sm text-muted">{courtCase.byTimeout ? "Opened because the company did not answer in time." : "Opened because the hunter disputes a rejection."}</p>
          {report && <p>The hunter claims <strong>{SEVERITY[report.claimedSeverity]}</strong> severity.</p>}
          <div className="border border-white/15 p-4">
            <p className="text-sm uppercase text-muted">Public summary from the hunter</p>
            <p className="mt-2 whitespace-pre-wrap">{disclosure?.summary || "The hunter wrote no public summary. In this prototype jurors cannot read the encrypted report."}</p>
          </div>
          <p className="field-hint">Rule: majority of revealed votes wins. A tie after a rejection goes to the company; a tie after a company timeout goes to the hunter.</p>
        </Card>

        <Card className="grid gap-3">
          <h2 className="field-label">Voting</h2>
          <p>
            {resolved ? "Closed." : committing ? <>Votes are hidden. Commit window closes <Countdown to={courtCase.commitDeadline} now={now} />.</> : revealing ? <>Reveal your vote. Window closes <Countdown to={courtCase.revealDeadline} now={now} />.</> : "Voting is over."}
          </p>
          <p className="text-sm text-muted">Revealed so far: hunter {courtCase.hunterVotes} · company {courtCase.companyVotes} · {courtCase.revealedCount} of {courtCase.jurors.length} revealed</p>
          {!resolved && committing && <DemoJump to={courtCase.commitDeadline + 1}>Demo: jump to the reveal phase</DemoJump>}
          {!resolved && revealing && <DemoJump to={courtCase.revealDeadline + 1}>Demo: jump to the end of voting</DemoJump>}
          <ul className="grid gap-2">
            {courtCase.jurors.map((j, i) => {
              const v = (votes ?? [])[i];
              return (
                <li key={j} className="flex flex-wrap items-center gap-2">
                  <span>{shortAddress(j)}{address && j.toLowerCase() === address.toLowerCase() ? " (you)" : ""}</span>
                  <Chip size="sm" tone={v?.revealed ? "glow" : undefined}>{v?.revealed ? (v.hunterWins ? "voted hunter" : "voted company") : v?.committed ? "committed" : "not voted"}</Chip>
                </li>
              );
            })}
          </ul>
        </Card>
      </div>

      <div className="mt-6">
        <NeedWallet what="vote">
          {mine && !resolved && (
            <Card className="grid gap-4">
              <h2 className="display-m !text-3xl">Your vote</h2>
              {committing && !mine.committed && (
                <>
                  <fieldset className="grid gap-2">
                    <legend className="field-label">Who should win?</legend>
                    {[["hunter", "The hunter: the report is valid"], ["company", "The company: the rejection stands"]].map(([value, label]) => (
                      <label key={value} className="flex items-center gap-3">
                        <input type="radio" name="vote" value={value} checked={choice === value} onChange={() => setChoice(value)} />
                        {label}
                      </label>
                    ))}
                  </fieldset>
                  <div><button type="button" className="btn" disabled={act.busy} onClick={commit}>Commit my vote (hidden)</button></div>
                </>
              )}
              {mine.committed && !mine.revealed && !revealing && <p className="text-muted">Your vote is committed. Come back when the reveal window opens.</p>}
              {revealing && mine.committed && !mine.revealed && (
                stored ? (
                  <div><button type="button" className="btn" disabled={act.busy} onClick={() => call("Reveal vote", "revealVote", [BigInt(caseId), stored.hunterWins, stored.salt])}>Reveal my vote ({stored.hunterWins ? "hunter" : "company"})</button></div>
                ) : (
                  <p role="alert" className="note-alert">This browser does not hold your vote and salt, so it cannot reveal. You will lose {bbt(court?.slashPerJuror)} BBT if you do not reveal.</p>
                )
              )}
              {mine.revealed && <p className="text-muted">You voted for the {mine.hunterWins ? "hunter" : "company"}. Waiting for the others.</p>}
            </Card>
          )}
          {address && !mine && !resolved && <p className="text-muted">You are not a juror in this case.</p>}
        </NeedWallet>
      </div>

      {canResolve && (
        <div className="mt-6">
          <button type="button" className="btn" disabled={act.busy} onClick={() => call("Resolve case", "resolveCase", [BigInt(caseId)])}>Resolve the case</button>
          <p className="field-hint">Anyone can do this once everyone revealed or the reveal window ended. The verdict pays the winner at once.</p>
        </div>
      )}
      {act.error && <p role="alert" className="mt-4 note-alert">{act.error}</p>}
    </section>
  );
}
