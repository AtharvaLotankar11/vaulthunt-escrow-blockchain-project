import { Check, Clock, Lock, Scale, X } from "lucide-react";
import { Chip } from "@/components/ui/Chip";
import { S, STATUS } from "@/lib/chain";

/** Report status as icon + text + chip tone (never color alone). */
export function StatusChip({ status, size = "sm" }) {
  const icon =
    status === S.Paid ? <Check size={14} aria-hidden="true" /> :
    status === S.Rejected || status === S.Refunded ? <X size={14} aria-hidden="true" /> :
    status === S.Disputed ? <Scale size={14} aria-hidden="true" /> :
    status === S.Committed ? <Lock size={14} aria-hidden="true" /> :
    <Clock size={14} aria-hidden="true" />;
  const tone = status === S.Paid ? "glow" : status === S.Rejected || status === S.Disputed ? "alert" : undefined;
  return (
    <Chip size={size} tone={tone} className="gap-2">
      {icon}
      {STATUS[status]}
    </Chip>
  );
}
