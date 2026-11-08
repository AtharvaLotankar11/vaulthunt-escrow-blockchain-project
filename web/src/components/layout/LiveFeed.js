"use client";

import { useActivity } from "@/lib/hooks";

/** A slow ticker of what just happened on-chain. Pauses on hover; reduced motion stops it. */
export function LiveFeed() {
  const { data } = useActivity();
  if (!data || data.length === 0) return null;
  const items = [...data, ...data]; // doubled for a seamless loop
  return (
    <div className="ticker overflow-hidden border-t border-white/10 py-3" role="region" aria-label="Live activity">
      <div className="ticker__track gap-12 text-sm text-muted">
        {items.map((item, i) => (
          <span key={`${item.key}-${i}`} className="whitespace-nowrap">
            <span aria-hidden="true" className="mr-3 text-white/50">✳</span>
            {item.text}
          </span>
        ))}
      </div>
    </div>
  );
}
