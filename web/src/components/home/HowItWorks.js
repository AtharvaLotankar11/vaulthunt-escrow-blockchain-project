import { Chip } from "@/components/ui/Chip";
import { FlowChips } from "@/components/ui/FlowChips";
import { GradientPanel } from "@/components/ui/GradientPanel";
import { HexPanel } from "@/components/ui/HexPanel";

const POINTS = [
  "A company locks the reward in its own escrow before any hunter starts.",
  "A hunter commits a hash first: proof of who found the bug, while the bug stays secret.",
  "Accepted means paid by code. Rejected or ignored means a staked jury decides.",
];

export function HowItWorks() {
  return (
    <section id="how" className="page-x py-24">
      <Chip>How it works</Chip>

      <div className="mt-10 grid gap-12 lg:grid-cols-2 lg:items-center">
        <h2 className="display-m">
          Lock it.
          <br />
          Prove it.
          <br />
          Get paid.
        </h2>

        <HexPanel innerClassName="py-12">
          <ul className="space-y-6">
            {POINTS.map((point) => (
              <li key={point} className="flex gap-3">
                <span aria-hidden="true" className="mt-2 size-1.5 shrink-0 rounded-full bg-white" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </HexPanel>
      </div>

      <div className="mt-20">
        <FlowChips steps={["Committed", "Revealed", "Under review", "Paid"]} />
        <p className="mt-4 max-w-xl text-muted">
          Every report moves through the same visible steps. Each step is a transaction anyone can verify.
        </p>
      </div>

      <GradientPanel className="mt-16 max-w-3xl">
        <p>
          Rewards are locked on-chain the moment a report is revealed. The company can never take
          them back mid-review.
        </p>
      </GradientPanel>
    </section>
  );
}
