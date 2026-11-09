"use client";

import Link from "next/link";
import { useChainId } from "wagmi";
import { LogoFull } from "@/components/ui/Logo";
import { addressesFor } from "@/lib/contracts";
import { wagmiConfig } from "@/lib/wagmi";

const REPO = "https://github.com/AtharvaLotankar11/vaulthunt-escrow-blockchain-project";
const LINKED = ["BountyToken", "PlatformTreasury", "ReputationSBT", "BountyFactory", "ReportRegistry", "DisputeCourt", "ProgramDirectory"];
const EXPLORE = [
  { href: "/programs", label: "Programs" },
  { href: "/hunter", label: "My reports" },
  { href: "/company", label: "Company" },
  { href: "/jury", label: "Jury" },
  { href: "/leaderboard", label: "Leaderboard" },
  { href: "/demo", label: "Demo mode" },
];
const TEAM = [
  { name: "Atharva Lotankar", roll: "20" },
  { name: "Vaishnavi Avhad", roll: "02" },
  { name: "Bhoomi Naik", roll: "22" },
];

export function Footer() {
  const chainId = useChainId();
  const explorer = wagmiConfig.chains.find((c) => c.id === chainId)?.blockExplorers?.default;
  const book = addressesFor(chainId);

  return (
    <footer className="border-t border-white/10 text-sm text-muted">
      <div className="page-x grid gap-10 py-12 md:grid-cols-2 xl:grid-cols-[1.4fr_0.8fr_1.2fr]">
        <section aria-label="About VaultHunt" className="max-w-md">
          <LogoFull height={44} title="VaultHunt" />
          <p className="mt-5 text-base font-medium text-white">Lock it. Prove it. Get paid.</p>
          <p className="mt-3">
            A decentralized escrow system that keeps bug bounty hunters and companies honest: locked rewards, encrypted reports and a fair,
            jury-based dispute process.
          </p>
        </section>

        <nav aria-label="Explore VaultHunt">
          <h2 className="footer-label">Explore</h2>
          <ul className="mt-5 grid gap-2">
            {EXPLORE.map((link) => (
              <li key={link.href}>
                <Link href={link.href} className="footer-link">{link.label}</Link>
              </li>
            ))}
            <li>
              <a href={REPO} target="_blank" rel="noreferrer" className="footer-link">Source code on GitHub <span aria-hidden="true">↗</span></a>
            </li>
            <li>
              <a href={`${REPO}/blob/main/PROJECT_REPORT.md`} target="_blank" rel="noreferrer" className="footer-link">Project report <span aria-hidden="true">↗</span></a>
            </li>
          </ul>
        </nav>

        <section aria-label="Project team">
          <h2 className="footer-label">Designed and developed by</h2>
          <ul className="mt-5 grid gap-3">
            {TEAM.map((member) => (
              <li key={member.name} className="flex flex-wrap items-center gap-x-3 gap-y-1">
                <span className="text-base font-medium text-white">{member.name}</span>
                <span className="roll">Roll No. {member.roll}</span>
              </li>
            ))}
          </ul>
          <p className="mt-5 text-pretty">Course project: Blockchain Technology (26ITPC71), Semester&nbsp;VII.</p>
        </section>
      </div>

      {explorer && book && (
        <nav aria-label="Contracts on the block explorer" className="page-x flex flex-wrap gap-x-5 gap-y-2 border-t border-white/10 py-5">
          <span className="uppercase">Verified contracts on {explorer.name}:</span>
          {LINKED.map((name) => (
            <a key={name} href={`${explorer.url}/address/${book[name]}`} target="_blank" rel="noreferrer" className="footer-link underline">
              {name}
            </a>
          ))}
        </nav>
      )}

      <div className="page-x flex flex-col gap-2 border-t border-white/10 py-6 text-xs md:flex-row md:items-center md:justify-between">
        <p>© 2026 VaultHunt. Built with care by Atharva Lotankar, Vaishnavi Avhad and Bhoomi Naik.</p>
        <p>Testnet prototype, not audited. Never use real funds.</p>
      </div>
    </footer>
  );
}
