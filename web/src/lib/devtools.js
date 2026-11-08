// Demo helpers for the LOCAL Anvil chain only.
import { anvil } from "@/lib/wagmi";

export async function anvilRpc(method, params = []) {
  const response = await fetch(anvil.rpcUrls.default.http[0], {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const body = await response.json();
  if (body.error) throw new Error(body.error.message);
  return body.result;
}

/** Move the chain clock to an exact moment (seconds), then mine a block there. */
export async function jumpTo(timestamp) {
  await anvilRpc("evm_setNextBlockTimestamp", [Number(timestamp)]);
  await anvilRpc("evm_mine");
}
