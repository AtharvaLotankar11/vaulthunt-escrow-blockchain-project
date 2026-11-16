"use client";

import { useState, useRef, useEffect } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { useIsClient } from "@/lib/useIsClient";
import { useWalletName } from "@/lib/useWalletName";
import { defaultChain } from "@/lib/wagmi";

function shorten(address) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

/**
 * Wallet button in the VaultHunt chip style. Shows the user's display name
 * (ENS name or locally-saved nickname) instead of the raw address.
 * Copy still copies the full public address.
 */
export function ConnectWallet() {
  const isClient = useIsClient();
  const { address, isConnected, chain, chainId: walletChainId } = useAccount();
  const { connect, connectors, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const { displayName, setLocalName } = useWalletName(address);

  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const inputRef = useRef(null);

  // Auto-focus the input when editing starts
  useEffect(() => {
    if (editing && inputRef.current) inputRef.current.focus();
  }, [editing]);

  // Same markup on the server and on the first client render (no hydration mismatch).
  if (!isClient) {
    return <span aria-hidden="true" className="chip chip--sm pointer-events-none opacity-0">Connect wallet</span>;
  }

  const walletMissing = error?.name === "ProviderNotFoundError" || error?.message?.includes("Provider not found");

  if (!isConnected) {
    return (
      <div className="flex items-center gap-2">
        {walletMissing ? (
          <a href="https://metamask.io/download" target="_blank" rel="noreferrer" className="chip chip--sm chip--alert">
            <span className="hidden sm:inline">Install MetaMask</span>
            <span className="sm:hidden">Install MM</span>
          </a>
        ) : (
          <button
            type="button"
            className="chip chip--sm cursor-pointer"
            disabled={isPending}
            onClick={() => connect({ connector: connectors[0], chainId: defaultChain.id })}
          >
            {isPending ? (
              <>
                <span className="hidden sm:inline">Confirm in wallet…</span>
                <span className="sm:hidden">Confirming…</span>
              </>
            ) : (
              <>
                <span className="hidden sm:inline">Connect wallet</span>
                <span className="sm:hidden">Connect</span>
              </>
            )}
          </button>
        )}
        {error && !walletMissing && (
          <span role="status" className="hidden text-sm text-muted md:inline">
            {error.shortMessage ?? "Connection failed"}
          </span>
        )}
      </div>
    );
  }

  const supported = Boolean(chain);
  if (!supported) {
    return (
      <button
        type="button"
        className="chip chip--sm chip--alert cursor-pointer"
        disabled={isSwitching}
        onClick={() => switchChain({ chainId: defaultChain.id })}
      >
        {isSwitching ? (
          <>
            <span className="hidden sm:inline">Switching…</span>
            <span className="sm:hidden">Switching…</span>
          </>
        ) : (
          <>
            <span className="hidden sm:inline">Wrong network ({walletChainId}): switch to {defaultChain.name}</span>
            <span className="sm:hidden">Switch to {defaultChain.name}</span>
          </>
        )}
      </button>
    );
  }

  // Show display name (ENS or local nickname), fall back to shortened address
  const label = displayName || shorten(address);

  const handleSaveName = () => {
    const trimmed = draft.trim();
    setLocalName(trimmed || null);
    setEditing(false);
  };

  return (
    <div className="flex items-center gap-2">
      <span className="chip chip--sm hidden sm:inline-flex">{chain.name}</span>
      <details className="relative">
        <summary className="chip chip--sm chip--glow cursor-pointer list-none">{label}</summary>
        <div className="absolute right-0 top-full z-40 mt-2 w-72 border border-white/15 bg-bg p-4">
          <p className="break-all text-sm text-muted">{address}</p>

          {/* Inline name editor */}
          {editing ? (
            <div className="mt-3 flex gap-2">
              <input
                ref={inputRef}
                type="text"
                className="min-w-0 flex-1 border border-white/20 bg-white/5 px-2 py-1 text-sm text-white outline-none focus:border-accent"
                placeholder="Enter display name"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") handleSaveName(); if (e.key === "Escape") setEditing(false); }}
                maxLength={32}
              />
              <button type="button" className="btn btn--ghost min-h-8! px-2! text-xs" onClick={handleSaveName}>
                Save
              </button>
            </div>
          ) : (
            displayName && (
              <p className="mt-1 text-xs text-accent">
                Display name: <strong>{displayName}</strong>
              </p>
            )
          )}

          <div className="mt-4 flex flex-wrap gap-2">
            <button type="button" className="btn btn--ghost min-h-10! px-3! text-sm" onClick={() => navigator.clipboard?.writeText(address)}>
              Copy
            </button>
            <button
              type="button"
              className="btn btn--ghost min-h-10! px-3! text-sm"
              onClick={() => { setDraft(displayName || ""); setEditing(true); }}
            >
              {displayName ? "Edit name" : "Set name"}
            </button>
            <button type="button" className="btn btn--ghost min-h-10! px-3! text-sm" onClick={() => disconnect()}>
              Disconnect
            </button>
          </div>
        </div>
      </details>
    </div>
  );
}
