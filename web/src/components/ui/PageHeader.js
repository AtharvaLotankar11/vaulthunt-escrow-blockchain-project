import { Chip } from "@/components/ui/Chip";

export function PageHeader({ chip, title, children }) {
  return (
    <header className="mb-10 flex flex-wrap items-end justify-between gap-6">
      <div>
        <Chip>{chip}</Chip>
        <h1 className="display-m mt-6">{title}</h1>
      </div>
      {children && <div className="flex flex-wrap items-center gap-3">{children}</div>}
    </header>
  );
}
