import { Chip } from "@/components/ui/Chip";

/**
 * A row of chips joined by 1px hairlines (design.md 5.3). Used for the report journey:
 * Committed, Revealed, Under review, Paid. Connectors hide on small screens where chips wrap.
 */
export function FlowChips({ steps, label = "Report journey" }) {
  return (
    <ol aria-label={label} className="flex flex-wrap items-center gap-y-4">
      {steps.map((step, index) => (
        <li key={step} className="flex items-center">
          <Chip>{step}</Chip>
          {index < steps.length - 1 && <span aria-hidden="true" className="hairline hidden w-10 sm:block" />}
        </li>
      ))}
    </ol>
  );
}
