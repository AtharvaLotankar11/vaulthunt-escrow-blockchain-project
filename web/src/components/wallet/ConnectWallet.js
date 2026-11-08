"use client";

import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { useIsClient } from "@/lib/useIsClient";
import { anvil } from "@/lib/wagmi";

function shorten(address) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

/**
 * Wallet button in the VaultHunt chip style. States: Connect, Connecting, Install MetaMask,
 * Wrong network (one click asks the wallet to switch to or add Anvil), or network + account
 * with a small menu (copy address, disconnect). Built on wagmi hooks only.
 */
export function ConnectWallet() {
  const isClient = useIsClient();
  const { address, isConnected, chain, chainId: walletChainId } = useAccount();
  const { connect, connectors, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

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
            Install MetaMask
          </a>
        ) : (
          <button
            type="button"
            className="chip chip--sm cursor-pointer"
            disabled={isPending}
            onClick={() => connect({ connector: connectors[0], chainId: anvil.id })}
          >
            {isPending ? "Confirm in wallet…" : "Connect wallet"}
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
        onClick={() => switchChain({ chainId: anvil.id })}
      >
        {isSwitching ? "Switching…" : `Wrong network (${walletChainId}): switch to Anvil`}
      </button>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <span className="chip chip--sm hidden sm:inline-flex">{chain.name}</span>
      <details className="relative">
        <summary className="chip chip--sm chip--glow cursor-pointer list-none">{shorten(address)}</summary>
        <div className="absolute right-0 top-full z-40 mt-2 w-64 border border-white/15 bg-bg p-4">
          <p className="break-all text-sm text-muted">{address}</p>
          <div className="mt-4 flex gap-2">
            <button type="button" className="btn btn--ghost min-h-10! px-3! text-sm" onClick={() => navigator.clipboard?.writeText(address)}>
              Copy
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
