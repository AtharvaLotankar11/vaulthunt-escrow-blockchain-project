"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { useAccount, useChainId, usePublicClient, useWriteContract } from "wagmi";
import { useToasts } from "@/components/ui/Toasts";
import { friendlyError } from "@/lib/errors";
import { wagmiConfig } from "@/lib/wagmi";

/**
 * Sends one contract transaction with plain-language toasts (pending, confirmed, failed) and
 * refreshes all chain data afterwards. Usage:
 *   const tx = useTx();
 *   const receipt = await tx({ label: "Accept report", address, abi, functionName, args, value });
 * Throws an Error with a human message if anything goes wrong.
 */
export function useTx() {
  const { writeContractAsync } = useWriteContract();
  const chainId = useChainId();
  const publicClient = usePublicClient({ chainId });
  const { address: account, isConnected, chainId: walletChainId } = useAccount();
  const toasts = useToasts();
  const queryClient = useQueryClient();

  return useCallback(
    async ({ label, address, abi, functionName, args = [], value }) => {
      if (!isConnected) throw new Error("Connect your wallet first.");
      if (walletChainId !== chainId) {
        const name = wagmiConfig.chains.find((c) => c.id === chainId)?.name ?? "the right network";
        throw new Error(`Switch your wallet to ${name}.`);
      }

      const id = toasts.push({ tone: "pending", title: label, text: "Confirm in your wallet…" });
      try {
        // Estimate first: a revert shows its reason BEFORE the wallet pops up. Then add 30% headroom,
        // because some calls (drawing jurors) cost a little different amounts depending on block data
        // that changes between the estimate and the mined block. Unused gas is refunded.
        const estimate = await publicClient.estimateContractGas({ address, abi, functionName, args, value, account });
        const gas = (estimate * 13n) / 10n;
        const hash = await writeContractAsync({ address, abi, functionName, args, value, chainId, gas });
        const explorer = publicClient.chain?.blockExplorers?.default?.url;
        toasts.update(id, { text: "Waiting for confirmation…", href: explorer ? `${explorer}/tx/${hash}` : undefined });
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        if (receipt.status !== "success") throw new Error("The transaction failed on-chain.");
        toasts.update(id, { tone: "success", text: "Done." });
        queryClient.invalidateQueries({ queryKey: ["vh"] });
        return receipt;
      } catch (error) {
        const message = friendlyError(error);
        toasts.update(id, { tone: "error", text: message });
        throw new Error(message, { cause: error });
      }
    },
    [account, isConnected, walletChainId, chainId, toasts, writeContractAsync, publicClient, queryClient],
  );
}
