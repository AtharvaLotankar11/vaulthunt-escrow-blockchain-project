"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Check, Clock, Play, X } from "lucide-react";
import { useRef, useState } from "react";
import { useChainId } from "wagmi";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { PayoutBurst } from "@/components/reports/PayoutBurst";
import { NoDeployment, StateMessage } from "@/components/ui/StateMessage";
import { useQueryClient } from "@tanstack/react-query";
import { addressesFor } from "@/lib/contracts";
import { createContext, STEPS } from "@/lib/demoScenario";
import { anvil } from "@/lib/wagmi";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Plays the whole scenario step by step, with a pause between steps so an audience can follow. */
export function DemoRunner() {
  const chainId = useChainId();
  const queryClient = useQueryClient();
  const book = addressesFor(chainId);
  const running = useRef(false);
  const [busy, setBusy] = useState(false);
  const [states, setStates] = useState({}); // index -> { status, detail }
  const [finished, setFinished] = useState(false);
  const [error, setError] = useState("");

  if (chainId !== anvil.id) {
    return <StateMessage tone="alert" title="Local chain only">Demo Mode uses Anvil&apos;s built-in test accounts, so it only runs on the local chain (chain id {anvil.id}).</StateMessage>;
  }
  if (!book) return <NoDeployment chainId={chainId} />;

  async function play() {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    setStates({});
    setFinished(false);
    setError("");
    const ctx = createContext(book);
    try {
      for (let i = 0; i < STEPS.length; i++) {
        setStates((s) => ({ ...s, [i]: { status: "active" } }));
        const detail = await STEPS[i].run(ctx);
        setStates((s) => ({ ...s, [i]: { status: "done", detail } }));
        await queryClient.invalidateQueries({ queryKey: ["vh"] });
        await sleep(900);
      }
      setFinished(true);
    } catch (e) {
      setError(e.shortMessage ?? e.message);
      setStates((s) => {
        const active = Object.keys(s).find((k) => s[k].status === "active");
        return active === undefined ? s : { ...s, [active]: { status: "error", detail: e.shortMessage ?? e.message } };
      });
    } finally {
      running.current = false;
      setBusy(false);
    }
  }

  const doneCount = Object.values(states).filter((s) => s.status === "done").length;

  return (
    <div className="grid max-w-4xl gap-6">
      <Card className="grid gap-4">
        <p className="text-muted">
          This plays the whole story by itself: a vault, an encrypted report, payment, a rejection, a jury dispute and a verdict. It uses Anvil&apos;s built-in test accounts
          directly, so no wallet pop-ups appear. Each run creates a new vault. Needs the Deploy and Seed scripts to have run (the jury must exist).
        </p>
        <div className="flex flex-wrap items-center gap-4">
          <button type="button" className="btn" disabled={busy} onClick={play}>
            <Play size={16} aria-hidden="true" /> {Object.keys(states).length ? "Run it again" : "Simulate full scenario"}
          </button>
          <Chip size="sm">{doneCount} of {STEPS.length} steps</Chip>
        </div>
        <div className="vault" role="progressbar" aria-valuemin={0} aria-valuemax={STEPS.length} aria-valuenow={doneCount} aria-label="Scenario progress">
          <motion.div className="vault__locked" animate={{ width: `${(doneCount / STEPS.length) * 100}%` }} transition={{ duration: 0.6, ease: "easeOut" }} />
        </div>
        <p className="field-hint">Using these accounts leaves MetaMask&apos;s remembered transaction numbers stale. If MetaMask hangs afterwards: Settings, Advanced, Clear activity tab data.</p>
      </Card>

      <ol className="grid gap-3" aria-live="polite">
        <AnimatePresence>
          {STEPS.map((step, i) => {
            const st = states[i];
            if (!st) return null;
            return (
              <motion.li key={step.title} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.35 }} className="card flex gap-4">
                <span className="mt-1" aria-hidden="true">{st.status === "done" ? <Check size={20} /> : st.status === "error" ? <X size={20} /> : <Clock size={20} />}</span>
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-3">
                    <span className="display-m !text-2xl">{i + 1}. {step.title}</span>
                    <Chip size="sm" tone={st.status === "error" ? "alert" : st.status === "done" ? "glow" : undefined}>
                      {st.status === "done" ? "Done" : st.status === "error" ? "Failed" : "Running"} · {step.actor}
                    </Chip>
                  </p>
                  {st.detail && <p className={st.status === "error" ? "note-alert mt-2" : "mt-2 text-muted"}>{st.detail}</p>}
                </div>
              </motion.li>
            );
          })}
        </AnimatePresence>
      </ol>

      {finished && (
        <div className="gradient-panel flex items-center gap-6" role="status">
          <PayoutBurst />
          <div>
            <p className="display-m !text-4xl">Demo complete</p>
            <p className="mt-2 text-muted">Open Programs, Hunter, Jury or the Leaderboard to see everything that just happened, on-chain.</p>
          </div>
        </div>
      )}
      {error && <p role="alert" className="note-alert">{error}</p>}
    </div>
  );
}
