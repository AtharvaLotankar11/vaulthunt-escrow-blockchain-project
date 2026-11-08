"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { HexPanel } from "@/components/ui/HexPanel";
import { PageHeader } from "@/components/ui/PageHeader";
import { StatusChip } from "@/components/ui/StatusChip";
import { ChainDown, NoDeployment } from "@/components/ui/StateMessage";
import { LEVELS, LEVEL_XP, S, SEVERITY, levelFor } from "@/lib/chain";
import { shortAddress } from "@/lib/format";
import { useBook, useHunterProfile, useReports } from "@/lib/hooks";

export default function ProfilePage() {
  const { address } = useParams();
  const { chainId, book } = useBook();
  const { data: profile, isError } = useHunterProfile(address);
  const { data: reports } = useReports();

  if (!book) return <section className="page-x py-12"><NoDeployment chainId={chainId} /></section>;
  if (isError) return <section className="page-x py-12"><ChainDown /></section>;

  const level = profile ? (profile.hasBadge ? profile.level : levelFor(profile.xp)) : 1;
  const xp = profile?.xp ?? 0;
  const next = LEVEL_XP[level]; // undefined at the top level
  const from = LEVEL_XP[level - 1];
  const progress = next ? Math.min(100, ((xp - from) / (next - from)) * 100) : 100;
  const mine = (reports ?? []).filter((r) => r.hunter.toLowerCase() === String(address).toLowerCase());
  const paid = mine.filter((r) => r.status === S.Paid).length;

  return (
    <section className="page-x py-12">
      <PageHeader chip="Hunter profile" title={shortAddress(address)} />

      <div className="grid gap-6 lg:grid-cols-[1fr_1.2fr] lg:items-center">
        <HexPanel glow className="mx-auto w-full max-w-md" innerClassName="py-14 text-center">
          <p className="text-sm uppercase text-muted">Soulbound badge</p>
          <p className="display-m mt-2">{LEVELS[level - 1]}</p>
          <p className="mt-2">Level {level} · {xp} XP</p>
          <Chip size="sm" className="mt-4">{profile?.hasBadge ? `Badge #${profile.badgeId}` : "No badge yet"}</Chip>
        </HexPanel>

        <Card className="grid gap-4">
          <h2 className="field-label">Progress</h2>
          <div className="vault" role="img" aria-label={`${progress.toFixed(0)} percent of the way to the next level`}>
            <div className="vault__locked" style={{ width: `${progress}%` }} />
          </div>
          <p className="text-muted">{next ? `${next - xp} XP to ${LEVELS[level]}` : "Top level reached."}</p>
          <p>{mine.length} reports · {paid} paid</p>
          <p className="field-hint">XP: Low 10, Medium 25, High 50, Critical 100. The badge cannot be transferred or sold.</p>
        </Card>
      </div>

      <h2 className="display-m mt-16 !text-4xl">Reports</h2>
      {mine.length === 0 ? (
        <p className="mt-4 text-muted">No reports yet.</p>
      ) : (
        <div className="mt-6 overflow-x-auto">
          <table className="data">
            <thead><tr><th>#</th><th>Program</th><th>Claims</th><th>Status</th></tr></thead>
            <tbody>
              {mine.map((r) => (
                <tr key={r.id}>
                  <td>{r.id}</td>
                  <td><Link className="underline" href={`/programs/${r.programId}`}>#{r.programId}</Link></td>
                  <td>{r.status >= S.Revealed ? SEVERITY[r.claimedSeverity] : "hidden"}</td>
                  <td><StatusChip status={r.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
