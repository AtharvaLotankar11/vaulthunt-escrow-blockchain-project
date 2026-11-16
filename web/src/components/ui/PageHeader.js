import { Chip } from "@/components/ui/Chip";

export function PageHeader({ chip, title, subtitle, children }) {
  return (
    <header className="mb-10 flex flex-wrap items-end justify-between gap-6">
      <div>
        <Chip>{chip}</Chip>
        <h1 className="display-m mt-6">{title}</h1>
        {subtitle && <p className="mt-2 text-sm text-muted">{subtitle}</p>}
      </div>
      {children && <div className="flex flex-wrap items-center gap-3">{children}</div>}
    </header>
  );
}
