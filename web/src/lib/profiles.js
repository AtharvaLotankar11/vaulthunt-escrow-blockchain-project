import { companyKeys } from "@/lib/secrets";
import { generateCompanyKeys } from "@/lib/crypto";
import { putJson } from "@/lib/ipfs";

/** The company's encryption key pair for this browser, created on first use. */
export async function ensureCompanyKeys(chainId, address) {
  let keys = companyKeys.load(chainId, address);
  if (!keys) {
    keys = await generateCompanyKeys();
    companyKeys.save(chainId, address, keys);
  }
  return keys;
}

/** Uploads the public profile (name, description, PUBLIC key) and returns its content id. */
export async function uploadProfile(chainId, address, { name, description }) {
  const keys = await ensureCompanyKeys(chainId, address);
  return putJson({
    v: 1,
    name: name.trim(),
    description: description.trim(),
    owner: address,
    publicKey: keys.publicJwk,
    createdAt: new Date().toISOString(),
  });
}
