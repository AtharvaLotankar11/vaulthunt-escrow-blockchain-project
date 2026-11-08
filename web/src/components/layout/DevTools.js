"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useChainId } from "wagmi";
import { Chip } from "@/components/ui/Chip";
import { useChainTime } from "@/lib/hooks";
import { duration } from "@/lib/format";
import { anvilRpc } from "@/lib/devtools";
import { anvil } from "@/lib/wagmi";

/** Demo controls, only on the local Anvil chain: move the chain's clock forward so deadlines pass. */
export function DevTools() {
  const chainId = useChainId();
  const { data: now } = useChainTime();
  const queryClient = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  if (chainId !== anvil.id) return null;

  async function jump(seconds) {
    setBusy(true);
    setError("");
    try {
      await anvilRpc("evm_increaseTime", [seconds]);
      await anvilRpc("evm_mine");
      await queryClient.invalidateQueries({ queryKey: ["vh"] });
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section aria-label="Demo controls" className="page-x border-t border-white/10 py-4">
      <div className="flex flex-wrap items-center gap-3">
        <Chip size="sm" tone="alert">Demo: time travel</Chip>
        <span className="text-sm text-muted">Chain clock: {now ? new Date(now * 1000).toLocaleTimeString() : "…"}</span>
        {[["+5 min", 300], ["+11 min", 660], ["+1 hour", 3600]].map(([label, seconds]) => (
          <button key={label} type="button" className="btn btn--ghost btn--sm" disabled={busy} onClick={() => jump(seconds)} title={`Move the local chain forward ${duration(seconds)}`}>
            {label}
          </button>
        ))}
        {error && <span role="alert" className="text-sm text-accent">{error}</span>}
      </div>
    </section>
  );
}
