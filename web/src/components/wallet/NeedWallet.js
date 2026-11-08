"use client";

import { useAccount, useChainId, useConnect, useSwitchChain } from "wagmi";
import { StateMessage } from "@/components/ui/StateMessage";
import { useIsClient } from "@/lib/useIsClient";

/** Shows its children only when a wallet is connected to the right network; otherwise explains and offers the fix. */
export function NeedWallet({ children, what = "do this" }) {
  const isClient = useIsClient();
  const { isConnected, chainId: walletChainId } = useAccount();
  const chainId = useChainId();
  const { connect, connectors, isPending } = useConnect();
  const { switchChain, isPending: switching } = useSwitchChain();

  if (!isClient) return null;

  if (!isConnected) {
    return (
      <StateMessage title="Wallet needed">
        <p>Connect your wallet to {what}.</p>
        <button type="button" className="btn mt-4" disabled={isPending} onClick={() => connect({ connector: connectors[0], chainId })}>
          {isPending ? "Confirm in wallet…" : "Connect wallet"}
        </button>
      </StateMessage>
    );
  }
  if (walletChainId !== chainId) {
    return (
      <StateMessage tone="alert" title="Wrong network">
        <p>Your wallet is on chain {walletChainId}. This app is using chain {chainId}.</p>
        <button type="button" className="btn mt-4" disabled={switching} onClick={() => switchChain({ chainId })}>
          {switching ? "Switching…" : "Switch network"}
        </button>
      </StateMessage>
    );
  }
  return children;
}
