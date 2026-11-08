import { useId } from "react";
import { cn } from "@/lib/cn";

/** Large, partly cropped ring that fades into the background (design.md 5.8). Decorative only. */
export function Ring({ flip = false, className }) {
  const id = "ring" + useId().replace(/[^a-zA-Z0-9]/g, "");
  return (
    <svg
      aria-hidden="true"
      viewBox="0 0 400 400"
      className={cn("pointer-events-none absolute -z-10", flip && "-scale-x-100", className)}
    >
      <defs>
        <linearGradient id={id} x1="0" y1="1" x2="1" y2="0">
          <stop offset="0%" stopColor="#0f00c9" />
          <stop offset="100%" stopColor="#020020" />
        </linearGradient>
      </defs>
      <circle cx="200" cy="200" r="160" fill="none" stroke={`url(#${id})`} strokeWidth="76" />
    </svg>
  );
}
