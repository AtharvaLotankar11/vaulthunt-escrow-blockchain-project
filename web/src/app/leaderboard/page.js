"use client";

import Link from "next/link";
import { Chip } from "@/components/ui/Chip";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { LEVELS, levelFor } from "@/lib/chain";
import { shortAddress } from "@/lib/format";
import { useBook, useLeaderboard } from "@/lib/hooks";

export default function LeaderboardPage() {
  const { chainId, book } = useBook();
  const { data: rows, isLoading, isError } = useLeaderboard();

  return (
    <section className="page-x py-12">
      <PageHeader chip="Leaderboard" title="Top hunters" />
      {!book ? (
        <NoDeployment chainId={chainId} />
      ) : isError ? (
        <ChainDown />
      ) : isLoading || rows === undefined ? (
        <p className="text-muted">Loading…</p>
      ) : !rows || rows.length === 0 ? (
        <StateMessage title="Nobody yet">Hunters appear here after their first report.</StateMessage>
      ) : (
        <div className="overflow-x-auto">
          <table className="data">
            <thead><tr><th>Rank</th><th>Hunter</th><th>Level</th><th>XP</th></tr></thead>
            <tbody>
              {rows.map((row, i) => {
                const level = row.hasBadge ? row.level : levelFor(row.xp);
                return (
                  <tr key={row.address}>
                    <td className="display-m !text-3xl">{i + 1}</td>
                    <td><Link className="underline" href={`/profile/${row.address}`}>{shortAddress(row.address)}</Link></td>
                    <td><Chip size="sm" tone={level >= 3 ? "glow" : undefined}>{LEVELS[level - 1]}</Chip></td>
                    <td>{row.xp}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
