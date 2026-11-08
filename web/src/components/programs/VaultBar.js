import { eth } from "@/lib/format";

/** Locked vs free money in a vault, as a bar plus words. */
export function VaultBar({ balance, locked }) {
  const lockedPct = balance > 0n ? Math.min(100, Number((locked * 10000n) / balance) / 100) : 0;
  return (
    <div>
      <div className="vault" role="img" aria-label={`${lockedPct.toFixed(0)} percent of the vault is locked for reports`}>
        <div className="vault__locked" style={{ width: `${lockedPct}%` }} />
        <div className="vault__free" style={{ width: `${100 - lockedPct}%` }} />
      </div>
      <p className="mt-2 text-sm text-muted">
        Locked {eth(locked)} ETH · Free {eth(balance > locked ? balance - locked : 0n)} ETH
      </p>
    </div>
  );
}
