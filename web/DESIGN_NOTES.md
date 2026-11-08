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
