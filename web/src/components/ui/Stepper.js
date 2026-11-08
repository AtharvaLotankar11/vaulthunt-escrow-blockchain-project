import { Check, Clock } from "lucide-react";
import { cn } from "@/lib/cn";

/** Progress of a multi-step action. steps: [{ label, state: "todo" | "active" | "done" | "error" }] */
export function Stepper({ steps }) {
  return (
    <ol className="flex flex-wrap gap-2" aria-label="Progress">
      {steps.map((step, i) => (
        <li
          key={step.label}
          className={cn(
            "chip chip--sm gap-2",
            step.state === "active" && "chip--glow",
            step.state === "error" && "chip--alert",
            step.state === "todo" && "opacity-60",
          )}
        >
          {step.state === "done" ? <Check size={14} aria-hidden="true" /> : step.state === "active" ? <Clock size={14} aria-hidden="true" /> : <span aria-hidden="true">{i + 1}</span>}
          {step.label}
          <span className="sr-only"> ({step.state})</span>
        </li>
      ))}
    </ol>
  );
}
