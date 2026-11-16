"use client";

import { useState, useCallback, useSyncExternalStore } from "react";
import { createPublicClient, http } from "viem";
import { mainnet } from "viem/chains";

const STORAGE_KEY = "vaulthunt_wallet_names";

/** Mainnet client for ENS reverse lookups (ENS lives on L1). */
const ensClient = createPublicClient({
  chain: mainnet,
  transport: http("https://cloudflare-eth.com"),
});

/* ---- localStorage as an external store ---- */

let listeners = new Set();
function emitChange() { listeners.forEach((fn) => fn()); }

function subscribeNames(cb) {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

function getSnapshot() {
  try { return localStorage.getItem(STORAGE_KEY) || "{}"; } catch { return "{}"; }
}

function getServerSnapshot() { return "{}"; }

/* ---- ENS cache (module-level, survives re-renders) ---- */
const ensCache = new Map();

/**
 * Returns { displayName, ensName, localName, setLocalName } for the given address.
 *
 * Resolution order:
 *   1. ENS reverse name (e.g. "vitalik.eth")
 *   2. User-set local name stored in localStorage
 *   3. null (caller should fall back to shortened address)
 */
export function useWalletName(address) {
  const raw = useSyncExternalStore(subscribeNames, getSnapshot, getServerSnapshot);
  const stored = JSON.parse(raw);
  const localName = address ? (stored[address.toLowerCase()] ?? null) : null;

  // ENS lookup: use module-level cache and a re-render trigger
  const [, setTick] = useState(0);
  const key = address?.toLowerCase();

  if (key && !ensCache.has(key)) {
    // Mark as in-flight
    ensCache.set(key, { status: "loading", name: null });
    ensClient
      .getEnsName({ address })
      .then((name) => {
        ensCache.set(key, { status: "done", name: name ?? null });
        setTick((t) => t + 1);
      })
      .catch(() => {
        ensCache.set(key, { status: "done", name: null });
        setTick((t) => t + 1);
      });
  }

  const ensEntry = key ? ensCache.get(key) : null;
  const ensName = ensEntry?.name ?? null;

  // Save a custom local name for this address
  const setLocalName = useCallback(
    (name) => {
      if (!address) return;
      const k = address.toLowerCase();
      try {
        const current = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
        if (name) {
          current[k] = name;
        } else {
          delete current[k];
        }
        localStorage.setItem(STORAGE_KEY, JSON.stringify(current));
      } catch {
        // ignore
      }
      emitChange();
    },
    [address],
  );

  // Priority: ENS > local name > null
  const displayName = ensName || localName || null;

  return { displayName, ensName, localName, setLocalName };
}
