"use client";

import Link from "next/link";
import { Chip } from "@/components/ui/Chip";
import { NotchedCard } from "@/components/ui/NotchedCard";
import { VaultBar } from "@/components/programs/VaultBar";
import { useProfile } from "@/lib/hooks";
import { eth, shortAddress } from "@/lib/format";

export function ProgramCard({ program }) {
  const { data: profile } = useProfile(program.profileURI);
  return (
    <Link href={`/programs/${program.id}`} className="block transition-transform hover:-translate-y-1">
      <NotchedCard className="h-full p-6 pb-24">
        <div className="flex items-start justify-between gap-3">
          <h2 className="display-m !text-3xl">{profile?.name ?? `Program #${program.id}`}</h2>
          <Chip size="sm" tone={program.profileURI ? "glow" : "alert"}>{program.profileURI ? "Key published" : "No key yet"}</Chip>
        </div>
        <p className="mt-2 text-sm text-muted">by {shortAddress(program.owner)}</p>

        <p className="display-m mt-8 !text-4xl">{eth(program.balance)} ETH</p>
        <div className="mt-4">
          <VaultBar balance={program.balance} locked={program.locked} />
        </div>
        <p className="mt-6 text-sm uppercase text-muted">
          Rewards: {eth(program.rewards[0])} → {eth(program.rewards[3])} ETH
        </p>
      </NotchedCard>
    </Link>
  );
}
