"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useChainId } from "wagmi";
import { jumpTo } from "@/lib/devtools";
import { anvil } from "@/lib/wagmi";

/**
 * A demo button (local Anvil chain only) that moves the chain clock to an EXACT moment, for example
 * "the start of the reveal phase", so nobody has to race a countdown during a demo.
 */
export function DemoJump({ to, children }) {
  const chainId = useChainId();
  const queryClient = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  if (chainId !== anvil.id) return null;

  async function go() {
    setBusy(true);
    setError("");
    try {
      await jumpTo(to);
      await queryClient.invalidateQueries({ queryKey: ["vh"] });
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-3 flex flex-wrap items-center gap-3">
      <button type="button" className="btn btn--ghost btn--sm" disabled={busy} onClick={go}>{children}</button>
      <span className="text-xs text-muted">Demo control, local chain only</span>
      {error && <span role="alert" className="text-sm note-alert">{error}</span>}
    </div>
  );
}
