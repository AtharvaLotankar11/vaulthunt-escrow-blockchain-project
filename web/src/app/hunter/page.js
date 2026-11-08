"use client";

import Link from "next/link";
import { useAccount } from "wagmi";
import { HunterReport } from "@/components/reports/HunterReport";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { TokenBar } from "@/components/ui/TokenBar";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { useBook, useCases, useChainTime, useCourtConfig, useRegistryConfig, useReports } from "@/lib/hooks";

export default function HunterPage() {
  const { address } = useAccount();
  const { chainId, book } = useBook();
  const { data: reports, isError } = useReports();
  const { data: cases } = useCases();
  const { data: now } = useChainTime();
  const { data: registryConfig } = useRegistryConfig();
  const { data: courtConfig } = useCourtConfig();

  const mine = (reports ?? []).filter((r) => address && r.hunter.toLowerCase() === address.toLowerCase());

  return (
    <section className="page-x py-12">
      <PageHeader chip="Hunter" title="My reports">
        <Link href="/programs" className="btn">Find a program</Link>
      </PageHeader>
      {!book ? (
        <NoDeployment chainId={chainId} />
      ) : isError ? (
        <ChainDown />
      ) : (
        <NeedWallet what="see your reports">
          <TokenBar />
          {mine.length === 0 ? (
            <StateMessage title="No reports yet">Pick a program and submit your first finding. <Link className="underline" href="/programs">Browse programs.</Link></StateMessage>
          ) : (
            <div className="grid gap-4">
              {mine.map((r) => (
                <HunterReport
                  key={r.id}
                  report={r}
                  programName={`Program #${r.programId}`}
                  now={now}
                  registryConfig={registryConfig}
                  courtConfig={courtConfig}
                  caseId={(cases ?? []).find((c) => c.reportId === r.id)?.id}
                />
              ))}
            </div>
          )}
        </NeedWallet>
      )}
    </section>
  );
}
