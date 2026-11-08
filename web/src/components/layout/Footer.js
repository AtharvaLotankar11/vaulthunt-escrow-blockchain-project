"use client";

import { useChainId } from "wagmi";
import { addressesFor } from "@/lib/contracts";
import { wagmiConfig } from "@/lib/wagmi";

const LINKED = ["BountyToken", "PlatformTreasury", "ReputationSBT", "BountyFactory", "ReportRegistry", "DisputeCourt", "ProgramDirectory"];

export function Footer() {
  const chainId = useChainId();
  const explorer = wagmiConfig.chains.find((c) => c.id === chainId)?.blockExplorers?.default;
  const book = addressesFor(chainId);

  return (
    <footer className="page-x border-t border-white/10 py-10 text-sm text-muted">
      {explorer && book && (
        <nav aria-label="Contracts on the block explorer" className="mb-6 flex flex-wrap gap-x-5 gap-y-2">
          <span className="uppercase">Verified contracts on {explorer.name}:</span>
          {LINKED.map((name) => (
            <a key={name} href={`${explorer.url}/address/${book[name]}`} target="_blank" rel="noreferrer" className="underline">
              {name}
            </a>
          ))}
        </nav>
      )}
      <p>VaultHunt: a decentralized escrow for bug bounty hunters. Testnet prototype, not audited. Never use real funds.</p>
    </footer>
  );
}
