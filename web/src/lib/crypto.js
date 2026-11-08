// Report encryption (browser only, Web Crypto). The company owns an RSA key pair. A hunter
// encrypts the report with a fresh AES key and wraps that key with the company's PUBLIC key,
// so only the company's private key can open it.
const encoder = new TextEncoder();
const decoder = new TextDecoder();

function toBase64(bytes) {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  return btoa(binary);
}

function fromBase64(text) {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

const RSA = { name: "RSA-OAEP", hash: "SHA-256" };

export async function generateCompanyKeys() {
  const pair = await crypto.subtle.generateKey(
    { ...RSA, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
    true,
    ["encrypt", "decrypt"],
  );
  return {
    publicJwk: await crypto.subtle.exportKey("jwk", pair.publicKey),
    privateJwk: await crypto.subtle.exportKey("jwk", pair.privateKey),
  };
}

export async function encryptReport(plaintext, publicJwk) {
  const aesKey = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, ["encrypt", "decrypt"]);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, aesKey, encoder.encode(plaintext));

  const publicKey = await crypto.subtle.importKey("jwk", publicJwk, RSA, false, ["encrypt"]);
  const wrapped = await crypto.subtle.encrypt({ name: "RSA-OAEP" }, publicKey, await crypto.subtle.exportKey("raw", aesKey));

  return {
    v: 1,
    alg: "RSA-OAEP-256+AES-256-GCM",
    iv: toBase64(iv),
    wrappedKey: toBase64(new Uint8Array(wrapped)),
    ciphertext: toBase64(new Uint8Array(ciphertext)),
  };
}

export async function decryptReport(pkg, privateJwk) {
  const privateKey = await crypto.subtle.importKey("jwk", privateJwk, RSA, false, ["decrypt"]);
  const rawAes = await crypto.subtle.decrypt({ name: "RSA-OAEP" }, privateKey, fromBase64(pkg.wrappedKey));
  const aesKey = await crypto.subtle.importKey("raw", rawAes, "AES-GCM", false, ["decrypt"]);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: fromBase64(pkg.iv) }, aesKey, fromBase64(pkg.ciphertext));
  return decoder.decode(plain);
}

/** A random 32-byte value as 0x-hex (used for commit salts). */
export function randomBytes32() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return "0x" + [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}
