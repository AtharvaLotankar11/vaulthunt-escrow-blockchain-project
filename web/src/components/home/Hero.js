import Link from "next/link";
import { Chip } from "@/components/ui/Chip";
import { HexPanel } from "@/components/ui/HexPanel";
import { GlassArc } from "@/components/art/GlassArc";
import { Ring } from "@/components/art/Ring";

/** Landing hero: the title slide of the template, for VaultHunt. */
export function Hero() {
  return (
    <section className="relative isolate flex min-h-[calc(100svh-5rem)] flex-col items-center justify-center overflow-hidden px-(--margin-x) py-16 text-center">
      <Ring className="-top-28 -right-28 size-[24rem] md:size-[34rem]" />
      <Ring flip className="-bottom-40 -left-32 size-[22rem] md:size-[32rem]" />
      <GlassArc className="absolute left-[2%] top-[3%] w-20 sm:w-28 md:w-32 xl:w-44 2xl:w-56" />
      <GlassArc flip className="absolute bottom-[3%] right-[2%] hidden w-32 md:block xl:w-44 2xl:w-56" />

      <h1 className="display-xl relative z-10">VaultHunt</h1>

      <div className="relative z-10 mt-8 sm:mt-10">
        <Chip variant="hero">Trustless bug bounties</Chip>
      </div>

      <HexPanel glow className="relative z-10 mt-10 w-full max-w-3xl sm:mt-12" innerClassName="pt-10 pb-14 sm:pb-16">
        <p className="mx-auto max-w-md text-balance">
          Lock the reward. Prove the find. Get paid by code.
        </p>
      </HexPanel>

      <div className="relative z-10 mt-10 flex flex-wrap justify-center gap-4">
        <Link href="/programs" className="btn">Browse programs</Link>
        <Link href="/programs/new" className="btn btn--ghost">Create a program</Link>
      </div>
    </section>
  );
}
