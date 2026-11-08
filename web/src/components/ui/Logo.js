import Link from "next/link";

/** The magenta asterisk plus the product name (design.md 5.1). */
export function Logo() {
  return (
    <Link href="/" className="inline-flex items-center gap-2.5 text-xl" aria-label="VaultHunt home">
      <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="#ff01dc" strokeWidth="2.2" strokeLinecap="round">
        <line x1="10" y1="1.5" x2="10" y2="18.5" />
        <line x1="1.5" y1="10" x2="18.5" y2="10" />
        <line x1="4" y1="4" x2="16" y2="16" />
        <line x1="16" y1="4" x2="4" y2="16" />
      </svg>
      <span>VaultHunt</span>
    </Link>
  );
}
