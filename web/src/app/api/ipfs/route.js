import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

export const runtime = "nodejs";

const MAX_BYTES = 1_000_000;
export const STORE_DIR = path.join(process.cwd(), ".data", "ipfs");

/**
 * POST a JSON document, get back a content id.
 *  - PINATA_JWT set (server side only): pinned to real IPFS through Pinata.
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

  const jwt = process.env.PINATA_JWT;
  if (jwt) {
    const form = new FormData();
    form.append("file", new Blob([text], { type: "application/json" }), "vaulthunt.json");
    const pinned = await fetch("https://api.pinata.cloud/pinning/pinFileToIPFS", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}` },
      body: form,
    });
    if (!pinned.ok) return Response.json({ error: `Pinata refused the upload (${pinned.status})` }, { status: 502 });
    const result = await pinned.json();
    return Response.json({ cid: result.IpfsHash, store: "pinata" });
  }

  const hash = createHash("sha256").update(text).digest("hex");
  await fs.mkdir(STORE_DIR, { recursive: true });
  await fs.writeFile(path.join(STORE_DIR, `${hash}.json`), text);
  return Response.json({ cid: `local-${hash}`, store: "local" });
}
