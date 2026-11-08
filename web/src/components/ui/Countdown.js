import { duration } from "@/lib/format";

/** "in 5m 20s" until a chain timestamp, or "passed". `now` is the CHAIN's clock. */
export function Countdown({ to, now, passedLabel = "passed" }) {
  if (now === undefined) return <span>…</span>;
  const left = Number(to) - Number(now);
  return <span>{left > 0 ? `in ${duration(left)}` : passedLabel}</span>;
}
