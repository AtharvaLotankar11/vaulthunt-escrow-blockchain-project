import { cn } from "@/lib/cn";

/** Rectangular callout, blue to midnight, square corners (design.md 5.5). */
export function GradientPanel({ className, children }) {
  return <div className={cn("gradient-panel", className)}>{children}</div>;
}
