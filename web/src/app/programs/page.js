"use client";

import Link from "next/link";
import { ProgramCard } from "@/components/programs/ProgramCard";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { useBook, usePrograms } from "@/lib/hooks";

export default function ProgramsPage() {
  const { chainId, book } = useBook();
  const { data: programs, isLoading, isError } = usePrograms();

  return (
    <section className="page-x py-12">
      <PageHeader chip="Programs" title="Bounty vaults">
        <Link href="/programs/new" className="btn">Create a program</Link>
      </PageHeader>

      {!book ? (
        <NoDeployment chainId={chainId} />
      ) : isError ? (
        <ChainDown />
      ) : isLoading || programs === undefined ? (
        <p className="text-muted">Loading vaults…</p>
      ) : programs.length === 0 ? (
        <StateMessage title="No programs yet">Be the first: create a program and lock a reward.</StateMessage>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          {[...programs].reverse().map((program) => (
            <ProgramCard key={program.id} program={program} />
          ))}
        </div>
      )}
    </section>
  );
}
