"use client";

import { useAccount, useChainId, useReadContracts } from "wagmi";
import { Chip } from "@/components/ui/Chip";
import { GradientPanel } from "@/components/ui/GradientPanel";
import { abis, addressesFor } from "@/lib/contracts";

function short(address) {
  return address ? `${address.slice(0, 6)}…${address.slice(-4)}` : "-";
}

function Stat({ label, value }) {
  return (
    <div>
      <div className="display-m">{value}</div>
      <div className="mt-2 text-sm uppercase text-muted">{label}</div>
    </div>
  );
}

/**
 * Reads live numbers straight from the deployed contracts. This is the proof that the wallet
 * connection, the synced ABIs and the addresses all work together.
 */
export function LivePanel() {
  const chainId = useChainId();
  const { address, isConnected } = useAccount();
  const book = addressesFor(chainId);

  const { data, isLoading } = useReadContracts({
    contracts: book
      ? [
          { chainId, address: book.BountyFactory, abi: abis.BountyFactory, functionName: "programCount" },
          { chainId, address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "poolSize" },
          { chainId, address: book.ReportRegistry, abi: abis.ReportRegistry, functionName: "reportCount" },
          { chainId, address: book.ReportRegistry, abi: abis.ReportRegistry, functionName: "court" },
        ]
      : [],
    query: { enabled: Boolean(book), refetchInterval: 4000 },
  });

  if (!book) {
    return (
      <GradientPanel>
        <Chip size="sm" tone="alert">No deployment</Chip>
        <p className="mt-4 max-w-md">
          No contracts are synced for chain {chainId}. Deploy them, then run <code>pnpm sync</code>.
        </p>
      </GradientPanel>
    );
  }

  const results = data ?? [];
  const reachable = results.some((r) => r?.status === "success");
  const programs = results[0]?.result;
  const jurors = results[1]?.result;
  const reports = results[2]?.result;
  const wired = results[3]?.result?.toLowerCase() === book.DisputeCourt.toLowerCase();

  if (!isLoading && !reachable) {
    return (
      <GradientPanel>
        <Chip size="sm" tone="alert">Chain not reachable</Chip>
        <p className="mt-4 max-w-md">
          Could not read the contracts on chain {chainId}. Start <code>anvil</code>, then run the Deploy
          and Seed scripts.
        </p>
      </GradientPanel>
    );
  }

  const show = (value) => (value === undefined ? "…" : String(value));

  return (
    <GradientPanel>
      <div className="flex flex-wrap gap-2">
        <Chip size="sm">Chain {chainId}</Chip>
        <Chip size="sm" tone={wired ? "glow" : "alert"}>{wired ? "Contracts wired" : "Check wiring"}</Chip>
        <Chip size="sm">{isConnected ? short(address) : "No wallet connected"}</Chip>
      </div>
      <div className="mt-8 grid grid-cols-3 gap-6">
        <Stat label="Programs" value={show(programs)} />
        <Stat label="Jurors" value={show(jurors)} />
        <Stat label="Reports" value={show(reports)} />
      </div>
    </GradientPanel>
  );
}
