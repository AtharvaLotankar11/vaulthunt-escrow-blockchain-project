import { formatEther } from "viem";

export const shortAddress = (address) => (address ? `${address.slice(0, 6)}…${address.slice(-4)}` : "-");

/** 1.5 ETH style, trimmed (0.5, 10, 0.0001). */
export function eth(wei, digits = 4) {
  if (wei === undefined || wei === null) return "…";
  const [whole, fraction = ""] = formatEther(BigInt(wei)).split(".");
  const trimmed = fraction.slice(0, digits).replace(/0+$/, "");
  return trimmed ? `${whole}.${trimmed}` : whole;
}

export function bbt(wei) {
  return eth(wei, 2);
}

/** "2d 4h", "3h 12m", "45s", "now". */
export function duration(seconds) {
  let s = Math.max(0, Math.floor(Number(seconds)));
  if (s === 0) return "now";
  const d = Math.floor(s / 86400); s -= d * 86400;
  const h = Math.floor(s / 3600); s -= h * 3600;
  const m = Math.floor(s / 60); s -= m * 60;
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m ${s}s`;
  return `${s}s`;
}

export function pct(bps) {
  return `${Number(bps) / 100}%`;
}
