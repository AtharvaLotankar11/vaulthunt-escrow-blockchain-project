"use client";

import Link from "next/link";
import { useId } from "react";

// VaultHunt brand (see web/public/brand): a vault hexagon with a keyhole and a crosshair.
// The name is drawn as outlines (Inter Display), so it looks the same on every computer.
const HEX_OUTER = "M128.0 25.0 L217.2 76.5 L217.2 179.5 L128.0 231.0 L38.8 179.5 L38.8 76.5 Z";
const HEX_INNER = "M128.0 52.0 L193.8 90.0 L193.8 166.0 L128.0 204.0 L62.2 166.0 L62.2 90.0 Z";
const TICKS = "M102 124 L76 124 M154 124 L180 124 M128 98 L128 72";
const STEM = "M119 135 L137 135 L142 175 L114 175 Z";
const WORD_VAULT = "M332.1 170.9H347.5L378.2 85.1H364.6L348.1 133.5C346 139.7 343.4 148 340 159.3C336.4 148 333.8 139.7 331.7 133.5L314.7 85.1H300.9Z M398.1 171.9C408.6 171.9 413.5 167.2 416.1 162.3H416.3V170.9H428.3V129.2C428.3 116.8 419.1 108.9 404.1 108.9C388.9 108.9 379.1 117.1 378.5 128.6H390.4C390.9 123 396.2 118.8 404 118.8C411.7 118.8 416.2 123.1 416.2 129V129.5C416.2 133.9 412.4 133.8 401 135.2C388.6 136.6 377 139.6 377 153.5C377 165.7 386 171.9 398.1 171.9ZM400.6 162.1C393.5 162.1 389.1 159 389.1 153.8C389.1 147.6 395.1 145.2 401.7 144.2C408.2 143.3 414.6 142.3 416.3 141V148.2C416.3 155.7 411.3 162.1 400.6 162.1Z M462.8 172.1C470.9 172.1 477.1 168.7 481.2 161.8V170.9H493.1V110.1H481V145.1C481 156.4 474.6 161.2 466.3 161.2C457.9 161.2 453 156.2 453 146.5V110.1H440.8V148C440.8 163.9 450.3 172.1 462.8 172.1Z M517.8 85.1H505.7V170.9H517.8Z M559.7 110.1H547.3V93.5H535.1V110.1H524.4V120.1H535.1V156.4C535.1 166.2 540.6 170.9 552 170.9H559.7V160.9H553.7C548.9 160.9 547.3 159.3 547.3 154.8V120.1H559.7Z";
const WORD_HUNT = "M568.2 170.9H589V136.1H621.6V170.9H642.4V85.1H621.6V118.4H589V85.1H568.2Z M673.2 172.2C682.3 172.2 688.5 168 692.5 161.1V170.9H712.1V110.1H692.3V143.2C692.3 151.5 688.3 155.3 682 155.3C675.7 155.3 672.1 151.4 672.1 144.2V110.1H652.2V148.3C652.2 163.3 660 172.2 673.2 172.2Z M741.8 137.9C741.8 129.6 745.8 125.7 752.1 125.7C758.4 125.7 762 129.6 762 136.8V170.9H781.9V132.7C781.9 117.7 774.1 108.8 760.9 108.8C751.8 108.8 745.6 113 741.6 119.9V110.1H722V170.9H741.8Z M830.1 110.1H817.6V93.5H797.7V110.1H787.3V125.4H797.7V153.8C797.7 165.6 804.2 170.9 818.8 170.9H830.1V155.6H823.2C818.8 155.6 817.6 154.4 817.6 150.5V125.4H830.1Z";
const FULL_WIDTH = 843;
const CENTER = { x: 128, y: 124 };

function Mark({ id }) {
  return (
    <>
      <defs>
        <linearGradient id={id} x1="30" y1="14" x2="226" y2="242" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#5CE1E6" />
          <stop offset="0.5" stopColor="#3F5CFF" />
          <stop offset="1" stopColor="#7A2FE6" />
        </linearGradient>
      </defs>
      <path d={HEX_OUTER} fill={`url(#${id})`} stroke={`url(#${id})`} strokeWidth="18" strokeLinejoin="round" />
      <path d={HEX_INNER} fill="none" stroke="#FFFFFF" strokeOpacity="0.32" strokeWidth="3.5" strokeLinejoin="round" />
      <circle cx={CENTER.x} cy={CENTER.y} r="38" fill="none" stroke="#FFFFFF" strokeWidth="5" />
      <path d={TICKS} fill="none" stroke="#FFFFFF" strokeWidth="5" strokeLinecap="round" />
      <circle cx={CENTER.x} cy={CENTER.y} r="18.5" fill="#FFFFFF" />
      <path d={STEM} fill="#FFFFFF" stroke="#FFFFFF" strokeWidth="5" strokeLinejoin="round" />
    </>
  );
}

function useGradientId() {
  return "vh" + useId().replace(/[^a-zA-Z0-9]/g, "");
}

/** The icon alone. Pass `title` when it is the only thing naming the product; otherwise it is decorative. */
export function LogoMark({ size = 40, title, className }) {
  const id = useGradientId();
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 256 256"
      width={size}
      height={size}
      className={className}
      role={title ? "img" : undefined}
      aria-hidden={title ? undefined : "true"}
      focusable="false"
    >
      {title && <title>{title}</title>}
      <Mark id={id} />
    </svg>
  );
}

/** Icon plus the name, for dark backgrounds (white "Vault", cyan "Hunt"). */
export function LogoFull({ height = 38, title, className }) {
  const id = useGradientId();
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox={`0 0 ${FULL_WIDTH} 256`}
      width={(height * FULL_WIDTH) / 256}
      height={height}
      className={className}
      role={title ? "img" : undefined}
      aria-hidden={title ? undefined : "true"}
      focusable="false"
    >
      {title && <title>{title}</title>}
      <Mark id={id} />
      <path d={WORD_VAULT} fill="#FFFFFF" />
      <path d={WORD_HUNT} fill="#5CE1E6" />
    </svg>
  );
}

/** The header logo: links home. */
export function Logo() {
  return (
    <Link href="/" aria-label="VaultHunt home" title="VaultHunt: fair bounties for bug hunters" className="inline-flex items-center">
      <LogoFull height={44} />
    </Link>
  );
}
