"use client";

import { useState } from "react";
import { keccak256, toBytes } from "viem";
import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { Countdown } from "@/components/ui/Countdown";
import { SelectField } from "@/components/ui/Field";
import { StatusChip } from "@/components/ui/StatusChip";
import { S, SEVERITY, awaitingCompany } from "@/lib/chain";
import { abis } from "@/lib/contracts";
import { decryptReport } from "@/lib/crypto";
import { eth, shortAddress } from "@/lib/format";
import { useBook } from "@/lib/hooks";
import { getJson } from "@/lib/ipfs";
import { companyKeys } from "@/lib/secrets";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";

/** One report from the company's point of view: read it, then accept, reject or wait. */
export function CompanyReport({ report, program, now, registryConfig }) {
  const tx = useTx();
  const { chainId, book } = useBook();
  const { address } = useAccount();
  const act = useAction();
  const reader = useAction();
  const [view, setView] = useState(null);
  const [severity, setSeverity] = useState(String(report.claimedSeverity));

  const call = (label, functionName, args) =>
    act.run(() => tx({ label, address: book.ReportRegistry, abi: abis.ReportRegistry, functionName, args }));

  function read() {
    return reader.run(async () => {
      const keys = companyKeys.load(chainId, address);
      if (!keys) throw new Error("This browser does not hold your encryption key. Open the Company page in the browser where you created the program.");
      const payload = await getJson(report.cid);
      const text = await decryptReport(payload.package, keys.privateJwk);
      setView({ report: JSON.parse(text), verified: keccak256(toBytes(text)) === report.contentHash, summary: payload.summary });
    });
  }

  const waiting = awaitingCompany(report.status);
  const disputeEnds = report.rejectedAt + (registryConfig?.disputeWindow ?? 0);

  return (
    <Card className="grid gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <span className="display-m !text-3xl">Report #{report.id}</span>
          <StatusChip status={report.status} />
          {report.status >= S.Revealed && <Chip size="sm">Claims {SEVERITY[report.claimedSeverity]}</Chip>}
        </div>
        <span className="text-sm text-muted">Hunter {shortAddress(report.hunter)}</span>
      </div>

      {report.status === S.Committed && <p className="text-muted">Committed, not revealed yet. The hunter still has to encrypt and reveal the report.</p>}

      {waiting && (
        <p className="text-sm text-muted">
          You have until the deadline <Countdown to={report.reviewDeadline} now={now} passedLabel="has passed" /> to answer. After it, the hunter may send this to the jury.
        </p>
      )}

      {report.status >= S.Revealed && (
        <div>
          <button type="button" className="btn btn--ghost btn--sm" disabled={reader.busy} onClick={read}>{reader.busy ? "Decrypting…" : view ? "Read again" : "Read report"}</button>
          {reader.error && <p role="alert" className="mt-2 note-alert">{reader.error}</p>}
          {view && (
            <div className="mt-4 border border-white/15 p-4">
              <p className="text-sm uppercase">{view.verified ? "✓ Matches the hash the hunter committed" : "✗ Does NOT match the committed hash"}</p>
              <h3 className="display-m mt-3 !text-2xl">{view.report.title}</h3>
              <p className="mt-3 whitespace-pre-wrap">{view.report.body}</p>
              {view.summary && <p className="mt-4 text-sm text-muted">Public summary: {view.summary}</p>}
            </div>
          )}
        </div>
      )}

      {waiting && (
        <div className="flex flex-wrap items-end gap-3">
          {report.status === S.Revealed && (
            <button type="button" className="btn btn--ghost btn--sm" disabled={act.busy} onClick={() => call("Start review", "startReview", [BigInt(report.id)])}>Start review</button>
          )}
          <div className="w-48">
            <SelectField label="Pay as" value={severity} onChange={(e) => setSeverity(e.target.value)} options={SEVERITY.map((label, i) => ({ value: String(i), label: `${label} · ${eth(program.rewards[i])} ETH` }))} />
          </div>
          <button type="button" className="btn btn--sm" disabled={act.busy} onClick={() => call("Accept report", "acceptReport", [BigInt(report.id), Number(severity)])}>Accept and pay</button>
          <button type="button" className="btn btn--danger btn--sm" disabled={act.busy} onClick={() => call("Reject report", "rejectReport", [BigInt(report.id)])}>Reject</button>
        </div>
      )}

      {report.status === S.Rejected && (
        <p className="text-sm text-muted">
          Rejected. The hunter can still go to the jury until the dispute window ends <Countdown to={disputeEnds} now={now} passedLabel="(it has ended)" />.
          {now !== undefined && now > disputeEnds && (
            <button type="button" className="btn btn--ghost btn--sm ml-3" disabled={act.busy} onClick={() => call("Finalize rejection", "finalizeRejection", [BigInt(report.id)])}>Release the locked reward</button>
          )}
        </p>
      )}
      {report.status === S.Disputed && <p className="text-sm text-muted">With the jury. The reward stays locked until they decide.</p>}
      {report.status === S.Paid && <p className="text-sm text-muted">Paid at {SEVERITY[report.paidSeverity]}.</p>}
      {act.error && <p role="alert" className="note-alert">{act.error}</p>}
    </Card>
  );
}
