/** Turn wallet and contract errors into one plain sentence. */
export function friendlyError(error) {
  const rejected = /user rejected|user denied|rejected the request|request rejected/i;
  const text = error?.shortMessage || error?.message || String(error);
  if (rejected.test(text)) return "You rejected the request in your wallet.";

  const reason = error?.walk?.((e) => typeof e?.reason === "string")?.reason;
  if (reason) return reason.replace(/^[A-Za-z]+: /, "");

  const match = text.match(/reason:\s*(.+)/i) || text.match(/reverted with the following reason:\s*(.+)/i);
  if (match) return match[1].split("\n")[0].replace(/^[A-Za-z]+: /, "").trim();
  return text.split("\n")[0].slice(0, 220);
}
