"use client";

import Link from "next/link";
import { useState } from "react";
import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { Countdown } from "@/components/ui/Countdown";
import { StatusChip } from "@/components/ui/StatusChip";
import { S, SEVERITY, awaitingCompany } from "@/lib/chain";
import { abis } from "@/lib/contracts";
import { eth } from "@/lib/format";
import { useBook, useChainQuery } from "@/lib/hooks";
import { reportSecrets } from "@/lib/secrets";
import { useAction } from "@/lib/useAction";
import { useEscalate, useReveal } from "@/lib/useFlows";
import { useTx } from "@/lib/useTx";

/** One report from the hunter's point of view, with the next action that makes sense. */
export function HunterReport({ report, programName, now, registryConfig, courtConfig, caseId }) {
  const tx = useTx();
  const { chainId, book } = useBook();
  const { address } = useAccount();
  const reveal = useReveal();
  const escalate = useEscalate();
  const act = useAction();
  const [step, setStep] = useState("");

  const { data: claimable } = useChainQuery(
    ["claimable", report.escrow, address],
    ({ publicClient }) => publicClient.readContract({ address: report.escrow, abi: abis.BountyEscrow, functionName: "claimable", args: [address] }),
    { enabled: report.status === S.Paid },
  );

  const secret = report.status === S.Committed ? reportSecrets.load(chainId, report.commitHash) : null;
  const disputeEnds = report.rejectedAt + (registryConfig?.disputeWindow ?? 0);
  const revealEnds = report.committedAt + (registryConfig?.revealWindow ?? 0);
  const fee = courtConfig?.disputeFee ?? 0n;

  const registryCall = (label, functionName) =>
    act.run(() => tx({ label, address: book.ReportRegistry, abi: abis.ReportRegistry, functionName, args: [BigInt(report.id)] }));

  return (
    <Card className="grid gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <span className="display-m !text-3xl">Report #{report.id}</span>
          <StatusChip status={report.status} />
          {report.status >= S.Revealed && <Chip size="sm">Claims {SEVERITY[report.claimedSeverity]}</Chip>}
        </div>
        <span className="text-sm text-muted">{programName}</span>
      </div>

      {report.status === S.Committed && (
        <div className="grid gap-3">
          <p className="text-muted">Your proof is on-chain. Finish by encrypting, uploading and revealing the report. Reveal window ends <Countdown to={revealEnds} now={now} passedLabel="(it has ended)" />.</p>
          {secret ? (
            <div>
              <button type="button" className="btn btn--sm" disabled={act.busy} onClick={() => act.run(() => reveal({ reportId: report.id, programId: report.programId, secret, onStep: setStep }))}>
                {act.busy ? `Working: ${step || "starting"}…` : "Encrypt, upload and reveal"}
              </button>
            </div>
          ) : (
            <p role="alert" className="text-accent">This browser does not hold the report text and salt for this commit, so it cannot be revealed from here.</p>
          )}
        </div>
      )}

      {awaitingCompany(report.status) && (
        <div className="grid gap-3">
          <p className="text-sm text-muted">Waiting for the company. Its deadline <Countdown to={report.reviewDeadline} now={now} passedLabel="has passed" />. Your reward ({SEVERITY[report.claimedSeverity]}) is locked for you meanwhile.</p>
          {now !== undefined && now > report.reviewDeadline && (
            <div>
              <button type="button" className="btn btn--sm" disabled={act.busy} onClick={() => registryCall("Send to the jury (company timed out)", "escalateAfterTimeout")}>The company did not answer: go to the jury</button>
            </div>
          )}
        </div>
      )}

      {report.status === S.Rejected && (
        <div className="grid gap-3">
          {now !== undefined && now <= disputeEnds ? (
            <>
              <p className="text-muted">The company rejected this report. You can dispute it before the window ends <Countdown to={disputeEnds} now={now} />. A jury of staked users decides. The fee is {eth(fee, 2)} BBT, paid by you and shared with the jurors who vote with the verdict.</p>
              <div>
                <button type="button" className="btn btn--sm" disabled={act.busy} onClick={() => act.run(() => escalate({ reportId: report.id, fee }))}>Dispute with the jury</button>
              </div>
            </>
          ) : (
            <>
              <p className="text-muted">The dispute window has ended. Anyone can release the locked reward back to the company.</p>
              <div>
                <button type="button" className="btn btn--ghost btn--sm" disabled={act.busy} onClick={() => registryCall("Finalize rejection", "finalizeRejection")}>Close this report</button>
              </div>
            </>
          )}
        </div>
      )}

      {report.status === S.Disputed && (
        <p className="text-muted">The jury is deciding. {caseId ? <Link className="underline" href={`/jury/${caseId}`}>Follow case #{caseId}</Link> : null}</p>
      )}

      {report.status === S.Paid && (
        <div className="grid gap-3">
          <p className="text-muted">Paid at {SEVERITY[report.paidSeverity]}. Reputation updated.</p>
          {claimable > 0n && (
            <div>
              <button type="button" className="btn btn--sm" disabled={act.busy} onClick={() => act.run(() => tx({ label: "Claim reward", address: report.escrow, abi: abis.BountyEscrow, functionName: "claim" }))}>
                Claim {eth(claimable)} ETH
              </button>
              <p className="field-hint">It normally arrives by itself; this is only needed if the automatic transfer to your wallet was not possible.</p>
            </div>
          )}
        </div>
      )}

      {report.status === S.Refunded && <p className="text-muted">Closed. The reward went back to the company.</p>}
      {act.error && <p role="alert" className="text-accent">{act.error}</p>}
    </Card>
  );
}
