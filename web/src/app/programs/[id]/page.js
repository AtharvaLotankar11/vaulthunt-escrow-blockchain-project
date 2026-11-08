"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { parseEther } from "viem";
import { useAccount } from "wagmi";
import { VaultBar } from "@/components/programs/VaultBar";
import { StatusChip } from "@/components/ui/StatusChip";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { TextAreaField, TextField } from "@/components/ui/Field";
import { PageHeader } from "@/components/ui/PageHeader";
import { ChainDown, NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { SEVERITY } from "@/lib/chain";
import { abis } from "@/lib/contracts";
import { eth, pct, shortAddress } from "@/lib/format";
import { useBook, useProfile, useProgram, useReports } from "@/lib/hooks";
import { uploadProfile } from "@/lib/profiles";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";

function OwnerTools({ program, profile }) {
  const tx = useTx();
  const { chainId, book } = useBook();
  const { address } = useAccount();
  const funds = useAction();
  const publish = useAction();
  const [amount, setAmount] = useState("1");
  const [name, setName] = useState(profile?.name ?? "");
  const [description, setDescription] = useState(profile?.description ?? "");

  return (
    <div className="grid gap-6 xl:grid-cols-2">
      <Card className="grid gap-4">
        <h2 className="display-m !text-3xl">Your vault</h2>
        <TextField label="Amount (ETH)" type="number" min="0" step="0.1" value={amount} onChange={(e) => setAmount(e.target.value)} />
        <div className="flex flex-wrap gap-3">
          <button type="button" className="btn" disabled={funds.busy || !(Number(amount) > 0)} onClick={() => funds.run(() => tx({ label: "Add funds", address: program.escrow, abi: abis.BountyEscrow, functionName: "deposit", value: parseEther(amount) }))}>
            Add funds
          </button>
          <button type="button" className="btn btn--ghost" disabled={funds.busy || !(Number(amount) > 0)} onClick={() => funds.run(() => tx({ label: "Withdraw free funds", address: program.escrow, abi: abis.BountyEscrow, functionName: "withdraw", args: [parseEther(amount)] }))}>
            Withdraw
          </button>
        </div>
        <p className="field-hint">You can only withdraw money that is not locked for a report. Free now: {eth(program.unlocked)} ETH.</p>
        {funds.error && <p role="alert" className="note-alert">{funds.error}</p>}
      </Card>

      <Card className="grid gap-4">
        <h2 className="display-m !text-3xl">{program.profileURI ? "Update profile" : "Publish profile"}</h2>
        <TextField label="Program name" value={name} onChange={(e) => setName(e.target.value)} />
        <TextAreaField label="Scope" value={description} onChange={(e) => setDescription(e.target.value)} />
        <div>
          <button
            type="button"
            className="btn"
            disabled={publish.busy || name.trim().length < 3}
            onClick={() =>
              publish.run(async () => {
                const cid = await uploadProfile(chainId, address, { name, description });
                await tx({ label: "Publish program profile", address: book.ProgramDirectory, abi: abis.ProgramDirectory, functionName: "setProfile", args: [BigInt(program.id), cid] });
              })
            }
          >
            {publish.busy ? "Working…" : "Publish"}
          </button>
        </div>
        <p className="field-hint">Publishes your name, scope and PUBLIC encryption key. Hunters cannot submit until this exists.</p>
        {publish.error && <p role="alert" className="note-alert">{publish.error}</p>}
      </Card>
    </div>
  );
}

export default function ProgramPage() {
  const { id } = useParams();
  const { chainId, book } = useBook();
  const { address } = useAccount();
  const { data: program, isLoading, isError } = useProgram(id);
  const { data: profile } = useProfile(program?.profileURI);
  const { data: reports } = useReports();

  if (!book) return <section className="page-x py-12"><NoDeployment chainId={chainId} /></section>;
  if (isError) return <section className="page-x py-12"><ChainDown /></section>;
  if (isLoading || program === undefined) return <section className="page-x py-12"><p className="text-muted">Loading…</p></section>;
  if (!program) return <section className="page-x py-12"><StateMessage tone="alert" title="Not found">There is no program #{id}.</StateMessage></section>;

  const isOwner = address && address.toLowerCase() === program.owner.toLowerCase();
  const mine = (reports ?? []).filter((r) => r.programId === program.id);

  return (
    <section className="page-x py-12">
      <PageHeader chip={`Program #${program.id}`} title={profile?.name ?? `Program #${program.id}`}>
        {program.profileURI ? (
          <Link href={`/programs/${program.id}/submit`} className="btn">Submit a report</Link>
        ) : (
          <Chip tone="alert">Owner has not published a key yet</Chip>
        )}
      </PageHeader>

      <div className="grid gap-6 xl:grid-cols-[1.4fr_1fr]">
        <div className="gradient-panel">
          <p className="text-sm uppercase text-muted">Vault balance</p>
          <p className="display-m mt-2">{eth(program.balance)} ETH</p>
          <div className="mt-6 max-w-xl"><VaultBar balance={program.balance} locked={program.locked} /></div>
          <p className="mt-6 text-sm text-muted">Owner {shortAddress(program.owner)}{isOwner ? " (you)" : ""} · Escrow {shortAddress(program.escrow)}</p>
        </div>
        <Card>
          <h2 className="field-label">Rewards today</h2>
          <table className="data">
            <thead><tr><th>Severity</th><th>Share</th><th>Pays</th></tr></thead>
            <tbody>
              {SEVERITY.map((label, i) => (
                <tr key={label}><td>{label}</td><td>{pct(program.bps[i])}</td><td>{eth(program.rewards[i])} ETH</td></tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>

      {profile?.description && (
        <Card className="mt-6">
          <h2 className="field-label">Scope</h2>
          <p className="whitespace-pre-wrap">{profile.description}</p>
        </Card>
      )}

      {isOwner && <div className="mt-6"><OwnerTools key={program.profileURI} program={program} profile={profile} /></div>}

      <h2 className="display-m mt-16 !text-4xl">Reports</h2>
      {mine.length === 0 ? (
        <p className="mt-4 text-muted">No reports yet.</p>
      ) : (
        <div className="mt-6 overflow-x-auto">
          <table className="data">
            <thead><tr><th>#</th><th>Hunter</th><th>Claims</th><th>Status</th></tr></thead>
            <tbody>
              {mine.map((r) => (
                <tr key={r.id}>
                  <td>{r.id}</td>
                  <td><Link className="underline" href={`/profile/${r.hunter}`}>{shortAddress(r.hunter)}</Link></td>
                  <td>{r.status >= 2 ? SEVERITY[r.claimedSeverity] : "hidden until revealed"}</td>
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
