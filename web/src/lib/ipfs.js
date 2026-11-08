// Off-chain storage through the app's own API route. With no setup it stores files locally
// (ids look like "local-<sha256>"); with PINATA_JWT set on the server it pins to real IPFS.
export async function putJson(value) {
  const response = await fetch("/api/ipfs", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(value),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error ?? `Upload failed (${response.status})`);
  return body.cid;
}

export async function getJson(cid) {
  const response = await fetch(`/api/ipfs/${encodeURIComponent(cid)}`);
  if (!response.ok) throw new Error(`Could not load ${cid} (${response.status})`);
  return response.json();
}
