import { Chip } from "@/components/ui/Chip";
import { Hero } from "@/components/home/Hero";
import { HowItWorks } from "@/components/home/HowItWorks";
import { Roles } from "@/components/home/Roles";
import { LivePanel } from "@/components/home/LivePanel";

export default function HomePage() {
  return (
    <>
      <Hero />
      <Roles />
      <HowItWorks />
      <section id="live" className="page-x pb-24">
        <Chip>Live on chain</Chip>
        <div className="mt-10 grid gap-10 lg:grid-cols-[1fr_1.4fr] lg:items-center">
          <h2 className="display-m">Straight from the contracts.</h2>
          <LivePanel />
        </div>
      </section>
    </>
  );
}
