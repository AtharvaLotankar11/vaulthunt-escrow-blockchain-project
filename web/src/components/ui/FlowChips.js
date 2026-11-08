"use client";

import { motion } from "framer-motion";
import { Chip } from "@/components/ui/Chip";

/**
 * A row of chips joined by 1px hairlines (design.md 5.3). Chips appear one after another (80ms
 * stagger) when scrolled into view. Connectors hide on small screens where chips wrap.
 */
export function FlowChips({ steps, label = "Report journey" }) {
  return (
    <ol aria-label={label} className="flex flex-wrap items-center gap-y-4">
      {steps.map((step, index) => (
        <motion.li
          key={step}
          className="flex items-center"
          initial={{ opacity: 0, y: 8 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.35, delay: index * 0.08 }}
        >
          <Chip>{step}</Chip>
          {index < steps.length - 1 && <span aria-hidden="true" className="hairline hidden w-10 sm:block" />}
        </motion.li>
      ))}
    </ol>
  );
}
