"use client";

import { motion } from "framer-motion";
import { useId } from "react";
import { cn } from "@/lib/cn";

/**
 * The signature iridescent glass arc, drawn as SVG so no image file is needed
 * (the template uses a rendered PNG; see DESIGN_NOTES.md). Floats and rotates slowly (7s loop);
 * MotionConfig turns that off for people who prefer reduced motion. Decorative only.
 */
export function GlassArc({ flip = false, pulse = false, className }) {
  const id = "arc" + useId().replace(/[^a-zA-Z0-9]/g, "");
  return (
    <motion.div
      aria-hidden="true"
      className={cn("pointer-events-none select-none", className)}
      animate={pulse ? { scale: [1, 1.12, 1], rotate: [0, 4, 0] } : { y: [0, -12, 0], rotate: [-2, 2, -2] }}
      transition={pulse ? { duration: 1.4, ease: "easeOut" } : { duration: 7, ease: "easeInOut", repeat: Infinity }}
    >
      <svg viewBox="0 0 320 190" className={cn("size-full", flip && "-scale-x-100")}>
        <defs>
          <linearGradient id={`${id}-glass`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#0000d3" />
            <stop offset="28%" stopColor="#3a2bff" />
            <stop offset="48%" stopColor="#b13dff" />
            <stop offset="62%" stopColor="#ff01dc" />
            <stop offset="78%" stopColor="#38e6ff" />
            <stop offset="100%" stopColor="#0100ce" />
          </linearGradient>
        </defs>
        <path d="M 28 182 A 132 132 0 0 1 292 182" fill="none" stroke="#0a0096" strokeWidth="54" />
        <path d="M 28 172 A 132 132 0 0 1 292 172" fill="none" stroke={`url(#${id}-glass)`} strokeWidth="54" />
        <path d="M 22 172 A 138 138 0 0 1 298 172" fill="none" stroke="#fff" strokeOpacity="0.5" strokeWidth="2" />
        <path d="M 52 172 A 108 108 0 0 1 268 172" fill="none" stroke="#fff" strokeOpacity="0.28" strokeWidth="2" />
        <path d="M 70 120 A 118 118 0 0 1 130 62" fill="none" stroke="#fff" strokeOpacity="0.55" strokeWidth="5" strokeLinecap="round" />
      </svg>
    </motion.div>
  );
}
