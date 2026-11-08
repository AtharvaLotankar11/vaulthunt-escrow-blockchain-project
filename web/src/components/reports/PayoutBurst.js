"use client";

import { motion } from "framer-motion";
import { LockOpen } from "lucide-react";
import { GlassArc } from "@/components/art/GlassArc";

/** Shown on a paid report: a lock opens, a glass arc pulses once. Decorative, text says "Paid". */
export function PayoutBurst() {
  return (
    <div aria-hidden="true" className="relative flex h-16 w-24 items-center justify-center">
      <GlassArc pulse className="absolute inset-0 opacity-70" />
      <motion.span initial={{ scale: 0.3, rotate: -25, opacity: 0 }} animate={{ scale: 1, rotate: 0, opacity: 1 }} transition={{ type: "spring", stiffness: 220, damping: 12 }} className="relative">
        <LockOpen size={28} />
      </motion.span>
    </div>
  );
}
