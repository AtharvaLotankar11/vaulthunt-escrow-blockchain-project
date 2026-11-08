"use client";

import { motion } from "framer-motion";
import { useId } from "react";
import { cn } from "@/lib/cn";

/**
 * Elongated hexagon with a 1px white hairline outline (design.md 5.4). The outline DRAWS IN when it
 * scrolls into view (0.9s). The outline is an SVG polygon (a CSS clip-path would cut a border off).
 * glow = the bottom half fades into electric blue.
 */
export function HexPanel({ glow = false, inset = 13, className, innerClassName, children }) {
  const gradientId = "hex" + useId().replace(/[^a-zA-Z0-9]/g, "");
  const points = `${inset},0 ${100 - inset},0 100,50 ${100 - inset},100 ${inset},100 0,50`;

  return (
    <div className={cn("relative", className)}>
      <svg
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 size-full"
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
      >
        {glow && (
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="45%" stopColor="#020020" stopOpacity="0" />
              <stop offset="100%" stopColor="#0f00d0" />
            </linearGradient>
          </defs>
        )}
        <motion.polygon
          points={points}
          fill={glow ? `url(#${gradientId})` : "none"}
          stroke="#ffffff"
          strokeWidth="1"
          vectorEffect="non-scaling-stroke"
          initial={{ pathLength: 0 }}
          whileInView={{ pathLength: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.9, ease: "easeInOut" }}
        />
      </svg>
      <div className={cn("relative px-[16%] py-10 sm:py-12", innerClassName)}>{children}</div>
    </div>
  );
}
