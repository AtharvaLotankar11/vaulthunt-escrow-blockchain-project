import fs from "node:fs/promises";
import path from "node:path";
import { STORE_DIR } from "../route";

export const runtime = "nodejs";

const LOCAL = /^local-([a-f0-9]{64})$/;
const REAL = /^[A-Za-z0-9]{46,100}$/;

export async function GET(_request, { params }) {
  const { cid } = await params;
  const headers = { "content-type": "application/json", "cache-control": "public, max-age=31536000, immutable" };

  const local = LOCAL.exec(cid);
  if (local) {
    try {
      const text = await fs.readFile(path.join(STORE_DIR, `${local[1]}.json`), "utf8");
      return new Response(text, { headers });
    } catch {
      return Response.json({ error: "Not found in the local store" }, { status: 404 });
    }
  }

  if (REAL.test(cid)) {
    const gateway = process.env.IPFS_GATEWAY || "https://gateway.pinata.cloud/ipfs";
    const upstream = await fetch(`${gateway}/${cid}`);
    if (!upstream.ok) return Response.json({ error: "Not found on IPFS" }, { status: 404 });
    return new Response(await upstream.text(), { headers });
  }

  return Response.json({ error: "Invalid content id" }, { status: 400 });
}
