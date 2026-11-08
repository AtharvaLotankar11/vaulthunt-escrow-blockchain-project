import { useId } from "react";
import { cn } from "@/lib/cn";

function Wrapper({ label, hint, id, children }) {
  return (
    <div>
      <label htmlFor={id} className="field-label">{label}</label>
      {children}
      {hint && <p className="field-hint">{hint}</p>}
    </div>
  );
}

export function TextField({ label, hint, className, ...props }) {
  const id = useId();
  return (
    <Wrapper label={label} hint={hint} id={id}>
      <input id={id} className={cn("field", className)} {...props} />
    </Wrapper>
  );
}

export function TextAreaField({ label, hint, className, ...props }) {
  const id = useId();
  return (
    <Wrapper label={label} hint={hint} id={id}>
      <textarea id={id} className={cn("field", className)} {...props} />
    </Wrapper>
  );
}

export function SelectField({ label, hint, options, className, ...props }) {
  const id = useId();
  return (
    <Wrapper label={label} hint={hint} id={id}>
      <select id={id} className={cn("field", className)} {...props}>
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </Wrapper>
  );
}
