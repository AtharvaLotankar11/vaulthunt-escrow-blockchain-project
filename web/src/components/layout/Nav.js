"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAccount } from "wagmi";
import { Logo } from "@/components/ui/Logo";
import { ConnectWallet } from "@/components/wallet/ConnectWallet";
import { cn } from "@/lib/cn";
import { useIsClient } from "@/lib/useIsClient";

const LINKS = [
  { href: "/programs", label: "Programs" },
  { href: "/hunter", label: "My reports" },
  { href: "/company", label: "Company" },
  { href: "/jury", label: "Jury" },
  { href: "/leaderboard", label: "Leaderboard" },
];

export function Nav() {
  const pathname = usePathname();
  const isClient = useIsClient();
  const { address } = useAccount();
  const links = isClient && address ? [...LINKS, { href: `/profile/${address}`, label: "Profile" }] : LINKS;

  return (
    <header className="sticky top-0 z-30 border-b border-white/10 bg-bg/90 backdrop-blur">
      <div className="page-x flex h-16 items-center justify-between gap-4">
        <Logo />
        <ConnectWallet />
      </div>
      <nav aria-label="Main" className="page-x flex gap-1 overflow-x-auto pb-2">
        {links.map((link) => {
          const active = pathname === link.href || pathname.startsWith(link.href + "/");
          return (
            <Link
              key={link.href}
              href={link.href}
              aria-current={active ? "page" : undefined}
              className={cn("whitespace-nowrap border-b-2 px-3 py-2 text-sm uppercase hover:text-accent", active ? "border-accent" : "border-transparent")}
            >
              {link.label}
            </Link>
          );
        })}
      </nav>
    </header>
  );
}
