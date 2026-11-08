# DESIGN_NOTES.md (web app)

What was built in Phase 6, and where it deliberately differs from `tasks-docs/design.md`.
Tags follow design.md: **MEASURED** (exact), **ESTIMATED**, **EXTENSION**.

## Implemented
- Color and gradient tokens, type scale (display-xl/l/m, label, body), 81px margins, label chip, flow chips, hexagon panel, gradient panel, notched card, glass arcs, rings, buttons, focus ring, reduced-motion rules, safe-area padding. All in `src/app/globals.css` and `src/components/`.
- Landing page (hero, how it works, live on-chain panel), navigation, footer, wallet button.

## Differences from design.md (decisions, not mistakes)
| Item | design.md | Built | Reason |
|---|---|---|---|
| Fonts | Telegraf (headings), Open Sauce One (body), Medium only | Fallback stack: Telegraf / Open Sauce One if installed, else Inter, Segoe UI, system-ui; weight 500 | Assumption A-3: licences not confirmed. To enable the real fonts, put the files in `public/fonts/` and add the `@font-face` rules described in `public/fonts/README.md` |
| Glass arc | Rendered PNG | SVG drawn in code (`GlassArc.js`), uses cobalt, purple, magenta and cyan sheen | No image asset available; keeps the app dependency-free. Art only, never used for UI state |
| Notched card | Exact notch shape | `clip-path` polygon + 40px radius (**ESTIMATED**) | Tune by eye against the template |
| Tailwind | `tailwind.config.js` | Tailwind v4, tokens in CSS with `@theme` | Tailwind v4 is CSS-first (milestone Phase 6 anticipated this) |
| shadcn/ui | In the stack | Not initialised yet | Add components one at a time in Phase 7+ with `pnpm dlx shadcn@latest add <name>`; the first ones needed are dialog and tabs |
| Wallet button | RainbowKit button restyled | Custom button on wagmi's `injected` connector | RainbowKit made the Next.js 16 build fail (optional payment SDKs); see TechStack.md |
| Motion | Framer Motion everywhere | CSS float animation only; framer-motion installed, used in Phase 9 | Keeps Phase 6 small |

## Not yet checked
- **Visual comparison against the template** was not possible in the build environment (no browser). Check the page by eye at 1440, 1024, 768 and 390 px and adjust the **ESTIMATED** items.
- Contrast numbers in design.md section 2.5 were calculated, not measured on screen.

## Checklist status (design.md section 13)
- Background `#020020`: done. Only the five core colors plus gradients in UI: done (white at 10 to 15% opacity for borders).
- Headline line-height 1.0, tight tracking, labels uppercase: done.
- Chip: square corners, 6px magenta bar, 60px high: done (48px on phones).
- Hexagon: 1px white outline drawn as SVG: done.
- Glass arcs never cover text: done by placement (check on small screens).
- Every state has icon plus text: wallet states use text chips; icons come with the dashboards in Phase 7.
- Reduced motion: CSS rule added; not yet tested in a browser.
- Fonts and imagery licences: fonts pending (A-3); no third-party imagery used.

## Phases 7 and 8 (the app pages)
- Every page uses the same few parts: chip, hexagon, gradient panel, notched card, slate card with a magenta bar, square fields. Status is always icon + text + chip tone.
- Wallet: wagmi's injected connector only (see TechStack.md). Transactions go through one hook (`useTx`): estimate first (revert reasons show before MetaMask opens), 30% gas headroom, plain-language toasts.
- The chain's own clock drives all countdowns (so the demo time-travel bar works).
- Not yet tested in a real browser by the author's tooling: responsive layouts, focus order, reduced motion. Check by eye.
- Known gaps: no tests for the visual layer; no Pinata test (needs a key); jurors read only the hunter's public summary (documented limitation).

## Phase 9: polish (what was done, and the design.md section 13 checklist)

Done in code and covered by the automated test where possible:
- Motion (Framer Motion): glass arcs float and rotate (7s loop), vault bars fill over 1s, hexagon outlines draw in when scrolled into view (0.9s), flow chips appear one by one (80ms stagger), page transitions (fade plus 12px rise, 0.35s), a lock-opens and arc-pulse burst on a paid report, the XP bar fills on the profile.
- Reduced motion: `MotionConfig reducedMotion="user"` plus a CSS rule. People who prefer reduced motion get no float or rotation; fades stay.
- Layout: two-column layouts stack until 1280px; the glass arcs shrink on tablets, the second arc is hidden on phones, and arcs sit in the corners, never beside the title; chips are 48px high and rows wrap on phones; tables scroll inside their own box.
- Accessibility: one visible focus style (2px magenta outline, 2px offset) on everything; toasts and countdowns are announced politely (`aria-live="polite"`); decorative art is `aria-hidden`; every status is icon plus text plus tone; all actions are real buttons, links, radios and selects, so Tab, Enter and Space work; errors are plain language.
- Demo Mode (`/demo`): plays a full scenario by itself on the local chain with Anvil's built-in accounts, no wallet needed.
- Magenta is now used only on bars, dashes, outlines and the focus ring (error text became white with a magenta bar).

| Checklist item | Status |
|---|---|
| Background #020020, five core colors plus gradients | Met (art uses extra sheen colors; art only) |
| Magenta only on bars, dashes, focus | Met (logo mark and text-selection color are the only other uses) |
| Telegraf and Open Sauce One, Medium only | NOT MET: fallback fonts until licences are confirmed (assumption A-3) |
| Headline line-height 1.0 | Met |
| Chip: square corners, magenta bar, 60px (48px on phones) | Met |
| Hexagon 1px white outline | Met |
| Glass arcs never cover text | Met by placement; confirm by eye at 1440, 1024, 768, 390 |
| 81px margins scaled | Met (fluid 20px to 81px) |
| Every state has icon plus text | Mostly met; the wallet button states are text only |
| Reduced motion | Implemented; confirm by eye (DevTools, Rendering, emulate prefers-reduced-motion) |
| Responsive on 4 widths | Implemented by code; NOT yet verified in a browser by the author's tooling |
| Fonts and imagery licences | Fonts pending; glass arc is original SVG; no third-party imagery |

## Phase 10: running on Sepolia
- Set `NEXT_PUBLIC_DEFAULT_CHAIN=sepolia` and `NEXT_PUBLIC_SEPOLIA_RPC=<your RPC link>` in `web/.env.local` to use the public test network; leave both out for the local chain.
- Free RPC plans may refuse large event queries. The leaderboard no longer uses events, and the live feed falls back to rebuilding itself from the contracts' own state.
- On Sepolia the demo time-travel buttons and Demo Mode do not exist (they need Anvil), so deadlines are real: review, reveal and dispute windows are 10 minutes, jury commit and reveal windows 5 minutes.
- Transactions show a block explorer link in their message, and the footer lists the verified contracts.
