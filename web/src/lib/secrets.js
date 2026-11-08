// Secrets that never leave this browser: the company's private key, a hunter's report text
// and salt, a juror's vote and salt. They are needed later (to reveal, to decrypt, to reveal a
// vote), so they are kept in localStorage per chain. Losing them means losing the ability to
// reveal or read, which is why the UI offers a backup download.
const PREFIX = "vaulthunt";

function key(chainId, ...parts) {
  return [PREFIX, chainId, ...parts].join(":");
}

function read(k) {
  try {
    const raw = window.localStorage.getItem(k);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function write(k, value) {
  window.localStorage.setItem(k, JSON.stringify(value));
}

export const companyKeys = {
  load: (chainId, address) => read(key(chainId, "company", address.toLowerCase())),
  save: (chainId, address, keys) => write(key(chainId, "company", address.toLowerCase()), keys),
};

/** Keyed by the commit hash, so it can be saved BEFORE the commit transaction is sent. */
export const reportSecrets = {
  load: (chainId, commitHash) => read(key(chainId, "report", commitHash.toLowerCase())),
  save: (chainId, commitHash, secret) => write(key(chainId, "report", commitHash.toLowerCase()), secret),
};

export const voteSecrets = {
  load: (chainId, caseId, address) => read(key(chainId, "vote", caseId, address.toLowerCase())),
  save: (chainId, caseId, address, secret) => write(key(chainId, "vote", caseId, address.toLowerCase()), secret),
};

export function downloadBackup(filename, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}
