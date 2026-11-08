import { cn } from "@/lib/cn";

/**
 * Label chip (design.md 5.2): slate fill, square corners, magenta bar on the left edge.
 * variant="hero" adds a bar on the right too. size="sm" for navigation and tables.
 * tone="glow" = active, tone="alert" = dispute / attention (always pair with text, never color alone).
 */
export function Chip({ variant, size, tone, className, children, ...props }) {
  return (
    <span
      className={cn(
        "chip",
        variant === "hero" && "chip--hero",
        size === "sm" && "chip--sm",
        tone === "glow" && "chip--glow",
        tone === "alert" && "chip--alert",
        className,
      )}
      {...props}
    >
      {children}
    </span>
  );
}
