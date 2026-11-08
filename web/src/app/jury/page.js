"use client";

import Link from "next/link";
import { useAccount } from "wagmi";
import { JurorPanel } from "@/components/jury/JurorPanel";
import { Chip } from "@/components/ui/Chip";
import { Countdown } from "@/components/ui/Countdown";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { TokenBar } from "@/components/ui/TokenBar";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { CASE } from "@/lib/chain";
import { shortAddress } from "@/lib/format";
import { useBook, useCases, useChainTime } from "@/lib/hooks";

export default function JuryPage() {
  const { address } = useAccount();
  const { chainId, book } = useBook();
  const { data: cases, isError } = useCases();
  const { data: now } = useChainTime();

  return (
    <section className="page-x py-12">
      <PageHeader chip="Jury" title="Jury room" />
      {!book ? (
        <NoDeployment chainId={chainId} />
      ) : isError ? (
        <ChainDown />
      ) : (
        <NeedWallet what="join the jury">
          <TokenBar />
          <JurorPanel />

          <h2 className="display-m mt-16 !text-4xl">Cases</h2>
          {cases === undefined ? (
            <p className="mt-6 text-muted">Loading…</p>
          ) : cases.length === 0 ? (
            <div className="mt-6"><StateMessage title="No cases">Disputes appear here when a hunter challenges a rejection or a company stays silent.</StateMessage></div>
          ) : (
            <div className="mt-6 overflow-x-auto">
              <table className="data">
                <thead><tr><th>Case</th><th>Report</th><th>Status</th><th>Phase</th><th>Your seat</th></tr></thead>
                <tbody>
                  {cases.map((c) => {
                    const seat = address && c.jurors.some((j) => j.toLowerCase() === address.toLowerCase());
                    const phase = c.status === CASE.Resolved ? (c.hunterWins ? "Hunter won" : "Company won") : now === undefined ? "…" : now <= c.commitDeadline ? "Voting (hidden)" : now <= c.revealDeadline ? "Revealing" : "Ready to resolve";
                    return (
                      <tr key={c.id}>
                        <td><Link className="underline" href={`/jury/${c.id}`}>#{c.id}</Link></td>
                        <td>#{c.reportId} · hunter {shortAddress(c.hunter)}</td>
                        <td><Chip size="sm" tone={c.status === CASE.Resolved ? "glow" : "alert"}>{c.status === CASE.Resolved ? "Resolved" : "Open"}</Chip></td>
                        <td>{phase} {c.status === CASE.Voting && now !== undefined && now <= c.revealDeadline ? <span className="text-muted">(<Countdown to={now <= c.commitDeadline ? c.commitDeadline : c.revealDeadline} now={now} />)</span> : null}</td>
                        <td>{seat ? <Chip size="sm" tone="glow">You are a juror</Chip> : "-"}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </NeedWallet>
      )}
    </section>
  );
}
