import { cn } from "@/lib/cn";

/** Rounded card with one corner cut away (design.md 5.6; the exact notch is estimated). */
export function NotchedCard({ className, children }) {
  return <div className={cn("notched", className)}>{children}</div>;
}
