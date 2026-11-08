"use client";

import { useQuery } from "@tanstack/react-query";
import { useChainId, usePublicClient } from "wagmi";
import { addressesFor } from "@/lib/contracts";
import { getJson } from "@/lib/ipfs";
import * as q from "@/lib/queries";

/** The chain the app reads from, its public client and the synced contract addresses. */
export function useBook() {
  const chainId = useChainId();
  const publicClient = usePublicClient({ chainId });
  return { chainId, publicClient, book: addressesFor(chainId) };
}

/** Run a read function against the current chain, refreshed every few seconds. */
export function useChainQuery(key, fn, { enabled = true, refetchInterval = 4000 } = {}) {
  const { chainId, publicClient, book } = useBook();
  return useQuery({
    queryKey: ["vh", chainId, ...key],
    enabled: Boolean(book && publicClient) && enabled,
    refetchInterval,
    queryFn: () => fn({ publicClient, book, chainId }),
  });
}

export const usePrograms = () => useChainQuery(["programs"], q.fetchPrograms);
export const useProgram = (id) => useChainQuery(["program", String(id)], (ctx) => q.fetchProgram(ctx, id), { enabled: id !== undefined && id !== "" });
export const useReports = () => useChainQuery(["reports"], q.fetchReports);
export const useRegistryConfig = () => useChainQuery(["registryConfig"], q.fetchRegistryConfig, { refetchInterval: 60000 });
export const useCourtConfig = () => useChainQuery(["courtConfig"], q.fetchCourtConfig);
export const useCases = () => useChainQuery(["cases"], q.fetchCases);
export const useLeaderboard = () => useChainQuery(["leaderboard"], q.fetchLeaderboard);
export const useActivity = () => useChainQuery(["activity"], q.fetchActivity);
export const useHunterProfile = (address) =>
  useChainQuery(["hunter", address], (ctx) => q.fetchHunterProfile(ctx, address), { enabled: Boolean(address) });
export const useJuror = (address) =>
  useChainQuery(["juror", address], (ctx) => q.fetchJuror(ctx, address), { enabled: Boolean(address) });
export const useVotes = (caseId, jurors) =>
  useChainQuery(["votes", String(caseId)], (ctx) => q.fetchVotes(ctx, caseId, jurors), { enabled: Boolean(jurors?.length) });

/** The chain's own clock in seconds. On Anvil it can be moved forward, so countdowns use THIS, not the PC clock. */
export const useChainTime = () =>
  useChainQuery(["time"], async ({ publicClient }) => Number((await publicClient.getBlock()).timestamp), { refetchInterval: 3000 });

/** A program profile (name, scope, public encryption key) stored off-chain. */
export function useProfile(uri) {
  return useQuery({
    queryKey: ["vh-profile", uri],
    enabled: Boolean(uri),
    staleTime: Infinity,
    queryFn: () => getJson(uri),
  });
}
