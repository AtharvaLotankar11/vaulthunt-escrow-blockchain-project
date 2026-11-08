"use client";

import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { Countdown } from "@/components/ui/Countdown";
import { abis } from "@/lib/contracts";
import { bbt, duration } from "@/lib/format";
import { useBook, useChainTime, useCourtConfig, useJuror } from "@/lib/hooks";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";

/** Become a juror: stake BBT, stay in the pool, leave and withdraw. */
export function JurorPanel() {
  const { address } = useAccount();
  const { book } = useBook();
  const tx = useTx();
  const { data: config } = useCourtConfig();
  const { data: juror } = useJuror(address);
  const { data: now } = useChainTime();
  const act = useAction();

  if (!config || !juror) return null;

  const needsStake = juror.stake < config.minStake;
  const topUp = needsStake ? config.minStake - juror.stake : 0n;

  async function stake() {
    if (juror.allowance < topUp) {
      await tx({ label: "Allow BBT for staking", address: book.BountyToken, abi: abis.BountyToken, functionName: "approve", args: [book.DisputeCourt, topUp] });
    }
    await tx({ label: "Stake BBT", address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "stake", args: [topUp] });
  }

  return (
    <Card className="grid gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="display-m !text-3xl">Be a juror</h2>
        <Chip size="sm" tone={juror.inPool ? "glow" : undefined}>{juror.inPool ? "In the pool" : "Not in the pool"}</Chip>
      </div>
      <p className="text-muted">
        Stake at least {bbt(config.minStake)} BBT to be drawn for disputes. Vote with the majority and you share the fee and the stake of those who did not.
        Vote against it, or forget to reveal, and you lose {bbt(config.slashPerJuror)} BBT. The pool has {config.poolSize} jurors.
      </p>
      <p>Your stake: <strong>{bbt(juror.stake)} BBT</strong> · Open cases: {juror.active}</p>
      <div className="flex flex-wrap gap-3">
        {needsStake && !juror.pending && (
          <button type="button" className="btn btn--sm" disabled={act.busy || juror.balance < topUp} onClick={() => act.run(stake)}>
            Stake {bbt(topUp)} BBT
          </button>
        )}
        {juror.stake > 0n && !juror.pending && (
          <button type="button" className="btn btn--ghost btn--sm" disabled={act.busy || juror.active > 0} onClick={() => act.run(() => tx({ label: "Leave the pool", address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "requestUnstake" }))}>
            Leave the pool
          </button>
        )}
        {juror.pending && (
          <button type="button" className="btn btn--sm" disabled={act.busy || now === undefined || now < juror.unstakeAt} onClick={() => act.run(() => tx({ label: "Withdraw stake", address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "withdrawStake" }))}>
            Withdraw {bbt(juror.stake)} BBT
          </button>
        )}
      </div>
      {needsStake && juror.balance < topUp && <p className="field-hint">You need {bbt(topUp)} BBT first. Use the faucet above.</p>}
      {juror.pending && <p className="field-hint">Cooldown: withdraw possible <Countdown to={juror.unstakeAt} now={now} passedLabel="now" /> (cooldown is {duration(config.unstakeCooldown)}).</p>}
      {juror.active > 0 && <p className="field-hint">You cannot leave while you sit on an open case.</p>}
      {act.error && <p role="alert" className="text-accent">{act.error}</p>}
    </Card>
  );
}
