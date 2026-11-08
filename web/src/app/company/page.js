"use client";

import Link from "next/link";
import { useAccount } from "wagmi";
import { CompanyReport } from "@/components/reports/CompanyReport";
import { Chip } from "@/components/ui/Chip";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { eth } from "@/lib/format";
import { useBook, useChainTime, useProfile, usePrograms, useRegistryConfig, useReports } from "@/lib/hooks";
import { companyKeys, downloadBackup } from "@/lib/secrets";

function ProgramBlock({ program, reports, now, registryConfig }) {
  const { data: profile } = useProfile(program.profileURI);
  return (
    <div className="mt-10">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <h2 className="display-m !text-3xl">{profile?.name ?? `Program #${program.id}`}</h2>
        <Chip size="sm">Free {eth(program.unlocked)} ETH</Chip>
        <Chip size="sm">Locked {eth(program.locked)} ETH</Chip>
        <Link href={`/programs/${program.id}`} className="text-sm underline">Open program</Link>
      </div>
      {reports.length === 0 ? (
        <p className="text-muted">No reports yet.</p>
      ) : (
        <div className="grid gap-4">
          {reports.map((r) => (
            <CompanyReport key={r.id} report={r} program={program} now={now} registryConfig={registryConfig} />
          ))}
        </div>
      )}
    </div>
  );
}

export default function CompanyPage() {
  const { address } = useAccount();
  const { chainId, book } = useBook();
  const { data: programs, isError } = usePrograms();
  const { data: reports } = useReports();
  const { data: now } = useChainTime();
  const { data: registryConfig } = useRegistryConfig();

  const mine = (programs ?? []).filter((p) => address && p.owner.toLowerCase() === address.toLowerCase());

  function backup() {
    const keys = companyKeys.load(chainId, address);
    if (keys) downloadBackup(`vaulthunt-company-key-${address.slice(0, 8)}.json`, keys);
  }

  return (
    <section className="page-x py-12">
      <PageHeader chip="Company" title="Review desk">
        <Link href="/programs/new" className="btn">Create a program</Link>
        {address && <button type="button" className="btn btn--ghost" onClick={backup}>Back up my encryption key</button>}
      </PageHeader>
      {!book ? (
        <NoDeployment chainId={chainId} />
      ) : isError ? (
        <ChainDown />
      ) : (
        <NeedWallet what="see your programs">
          {mine.length === 0 ? (
            <StateMessage title="No programs">This wallet owns no programs yet. <Link className="underline" href="/programs/new">Create one.</Link></StateMessage>
          ) : (
            mine.map((p) => (
              <ProgramBlock key={p.id} program={p} reports={(reports ?? []).filter((r) => r.programId === p.id)} now={now} registryConfig={registryConfig} />
            ))
          )}
        </NeedWallet>
      )}
    </section>
  );
}
