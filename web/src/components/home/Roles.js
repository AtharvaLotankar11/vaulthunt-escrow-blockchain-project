import Link from "next/link";
import { NotchedCard } from "@/components/ui/NotchedCard";

const ROLES = [
  { href: "/programs", title: "Hunt", text: "Find a vault, prove your finding, get paid by code." },
  { href: "/programs/new", title: "Protect", text: "Lock a reward, receive encrypted reports, pay only for real bugs." },
  { href: "/jury", title: "Judge", text: "Stake BBT, vote on disputes, earn from honest verdicts." },
];

export function Roles() {
  return (
    <section className="page-x pb-24">
      <div className="grid gap-6 md:grid-cols-3">
        {ROLES.map((role) => (
          <Link key={role.href} href={role.href} className="block transition-transform hover:-translate-y-1">
            <NotchedCard className="h-full p-8 pb-14">
              <h2 className="display-m !text-5xl">{role.title}</h2>
              <p className="mt-4 text-muted">{role.text}</p>
              <p className="mt-6 text-sm uppercase text-accent">Open →</p>
            </NotchedCard>
          </Link>
        ))}
      </div>
    </section>
  );
}
