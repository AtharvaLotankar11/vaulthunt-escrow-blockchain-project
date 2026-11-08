"use client";

import { motion } from "framer-motion";
import { eth } from "@/lib/format";

/** Locked vs free money in a vault. The bar fills over 1s when the value changes. */
export function VaultBar({ balance, locked }) {
  const lockedPct = balance > 0n ? Math.min(100, Number((locked * 10000n) / balance) / 100) : 0;
  return (
    <div>
      <div className="vault" role="img" aria-label={`${lockedPct.toFixed(0)} percent of the vault is locked for reports`}>
        <motion.div className="vault__locked" initial={{ width: 0 }} animate={{ width: `${lockedPct}%` }} transition={{ duration: 1, ease: "easeOut" }} />
        <motion.div className="vault__free" initial={{ width: "100%" }} animate={{ width: `${100 - lockedPct}%` }} transition={{ duration: 1, ease: "easeOut" }} />
      </div>
      <p className="mt-2 text-sm text-muted">
        Locked {eth(locked)} ETH · Free {eth(balance > locked ? balance - locked : 0n)} ETH
      </p>
    </div>
  );
}
