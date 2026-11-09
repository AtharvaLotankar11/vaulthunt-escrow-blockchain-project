import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

export const runtime = "nodejs";

const MAX_BYTES = 1_000_000;
export const STORE_DIR = path.join(process.cwd(), ".data", "ipfs");

/** Pin one JSON document on Pinata. Tries the current upload API first, then the older one. */
async function pinWithPinata(jwt, text) {
  const headers = { Authorization: `Bearer ${jwt}` };
  let lastStatus = 0;

  try {
    const form = new FormData();
    form.append("network", "public");
    form.append("name", "vaulthunt.json");
    form.append("file", new Blob([text], { type: "application/json" }), "vaulthunt.json");
    const response = await fetch("https://uploads.pinata.cloud/v3/files", { method: "POST", headers, body: form, signal: AbortSignal.timeout(20000) });
    lastStatus = response.status;
    if (response.ok) {
      const body = await response.json();
      if (body?.data?.cid) return { cid: body.data.cid };
    }
  } catch {
    lastStatus = lastStatus || 0;
  }

  try {
    const form = new FormData();
    form.append("file", new Blob([text], { type: "application/json" }), "vaulthunt.json");
    const response = await fetch("https://api.pinata.cloud/pinning/pinFileToIPFS", { method: "POST", headers, body: form, signal: AbortSignal.timeout(20000) });
    lastStatus = response.status;
    if (response.ok) {
      const body = await response.json();
      if (body?.IpfsHash) return { cid: body.IpfsHash };
    }
  } catch {
    lastStatus = lastStatus || 0;
  }
  return { status: lastStatus };
}

/**
 * POST a JSON document, get back a content id.
 *  - PINATA_JWT set (server side only): pinned to real IPFS through Pinata.
 *  - no key and running on Vercel: refused with a clear message (a hosted server cannot keep files).
 *  - otherwise: stored under .data/ipfs as local-<sha256>, good for local demos.
 * The browser never sees the Pinata key.
 */
export async function POST(request) {
  const text = await request.text();
  if (Buffer.byteLength(text) > MAX_BYTES) {
    return Response.json({ error: "Document too large (1 MB limit)" }, { status: 413 });
  }
  try {
    JSON.parse(text);
  } catch {
    return Response.json({ error: "Body must be JSON" }, { status: 400 });
  }

  const jwt = process.env.PINATA_JWT?.trim();
  if (jwt) {
    const result = await pinWithPinata(jwt, text);
    if (result.cid) return Response.json({ cid: result.cid, store: "pinata" });
    return Response.json({ error: `Pinata refused the upload (status ${result.status || "no answer"}). Check PINATA_JWT and its permissions.` }, { status: 502 });
  }

  if (process.env.VERCEL) {
    return Response.json({ error: "Report storage is not set up on this server. Add PINATA_JWT in the hosting settings." }, { status: 503 });
  }

  try {
    const hash = createHash("sha256").update(text).digest("hex");
    await fs.mkdir(STORE_DIR, { recursive: true });
    await fs.writeFile(path.join(STORE_DIR, `${hash}.json`), text);
    return Response.json({ cid: `local-${hash}`, store: "local" });
  } catch {
    return Response.json({ error: "Could not write to the local store." }, { status: 500 });
  }
}
