# design.md: UI / UX Design System

**Project:** VaultHunt (working title): Decentralized Escrow System for Bug Bounty Hunters
**Companion to:** PRD.md, TechStack.md (Next.js + JavaScript, Tailwind, shadcn/ui, Framer Motion)
**Design source:** the uploaded 10-slide template ("design_i_want.pdf")

---

## 0. How to read this document (no guesswork rule)

Every value below is tagged by how it was obtained:

| Tag | Meaning |
|---|---|
| **[MEASURED]** | Read directly from the template file (colors sampled from pixels, fonts and sizes read from the PDF's text data, geometry measured on a 1440 x 810 render). Treat as exact. |
| **[ESTIMATED]** | Judged by eye from the render (e.g. corner radius). Close, but verify by overlaying your build on the template. |
| **[EXTENSION]** | Needed for a real web app but **not present in the template** (error states, forms, tables, toasts). Derived strictly from the measured palette so nothing clashes. |

If a value is not tagged, it is a rule or instruction, not a measurement.

---

## 1. Design personality (in one paragraph)

Deep midnight-navy canvas. **Huge, confident, light-feeling headlines** in white. **One electric-blue** that glows as gradients, and **one hot magenta** used sparingly as a signal (a bar, a dash, a star). Flat dark-slate label chips. Thin white hairline hexagons and connector lines. Photos cropped into **notched, rounded shapes**. Floating **iridescent glass arcs** as the signature 3D object. Calm, spacious, premium, "futuristic finance", not noisy, not neon-everything.

**The three rules that keep it looking like the template:**
1. Backgrounds are always the midnight navy. Never white, never grey.
2. Blue is for **depth and glow** (gradients). Magenta is for **tiny sharp accents** (never large fills).
3. Lots of empty space. If a screen feels busy, remove something.

---

## 2. Color system

### 2.1 Core palette **[MEASURED]**

| Token | Hex | Where the template uses it |
|---|---|---|
| `--bg` Midnight | `#020020` | Every slide background; also the end-point of every gradient |
| `--surface` Slate chip | `#22213d` | Label chips (e.g. "THE DIGITAL REVOLUTION OF MONEY") and flow-step boxes ("Barter", "Metal coins"...) |
| `--accent` Magenta | `#ff01dc` | Logo star, chip edge bars, short underline dash |
| `--blue-peak` Electric blue | `#0f00d0` | Brightest point of gradient panels, hexagon glow, large rings (sampled peaks: `#0f00c9`, `#0f00d2`, `#0f00d0`) |
| `--text` White | `#ffffff` | All text (headlines, labels, body) and hairlines |

### 2.2 Gradient ramps **[MEASURED]**

Every blue gradient runs from `--blue-peak` into `--bg`. Sampled midpoints confirm the ramp is smooth and linear:

| Stop | Hex (sampled) |
|---|---|
| 0% | `#0f00cc` |
| 20% | `#0d00b1` / `#0c00aa` |
| 40% | `#0b0099` |
| 60% | `#090078` |
| 80% | `#050046` |
| 100% | `#020020` |

Three gradient uses seen in the template:

| Name | Direction | Used on |
|---|---|---|
| **Panel gradient** | Left (blue) to right (midnight), horizontal | Rectangular callout panels (e.g. "Think of it as the Internet of Money...") |
| **Panel gradient (mirrored)** | Left to right, same as above; some panels start at left edge, text sits over the bright side | Stat callouts ("Over 100 million people...") |
| **Hexagon glow** | Top (transparent / midnight) to bottom (blue), vertical | Bottom half of outlined hexagon holding a short statement |
| **Ring gradient** | Blue arc fading into midnight along its length | Large partly cropped rings in corners |

### 2.3 Glass-arc object colors **[MEASURED]**
The 3D glass arc is a **raster image with transparency** (not CSS). Its dominant tones: cobalt blue (`#0100ce`, `#0000d3`), with iridescent magenta and cyan reflections (e.g. `#cc00a6`). It must stay inside the same blue + magenta family.

### 2.4 Semantic colors for the app **[EXTENSION]**

The template has no success/error colors. To avoid introducing off-palette green/red, status is encoded with the **existing palette + icon + text label** (never color alone):

| State | Visual treatment | Label example |
|---|---|---|
| Neutral / pending | `--surface` chip, white text | `UNDER REVIEW` |
| Active / in progress | Blue-peak gradient chip, white text | `VOTING OPEN` |
| Success / paid | White chip with `--bg` text, check icon | `PAID` |
| Attention / dispute / reject | Magenta left bar + magenta icon, white text | `DISPUTED` |
| Error (tx failed) | Magenta outline 1px, magenta icon, plain-language message | `Transaction failed` |
| Disabled | White text at 40% opacity, no glow | n/a |

Secondary / muted text: `rgba(255,255,255,0.72)` **[EXTENSION]** (template only uses full white; use muted sparingly, mostly in tables and helper text).

### 2.5 Contrast check (calculated, approximate)
- White on `#020020`: about 19:1 (excellent)
- White on `#22213d`: about 15:1
- White on `#0f00d0`: about 11:1
- Magenta `#ff01dc` on `#020020`: about 6:1 (fine for icons, bars, large text; avoid for small body text)

---

## 3. Typography

### 3.1 Typefaces **[MEASURED]** (read from the PDF's embedded font names)

| Role | Font | Weight in template |
|---|---|---|
| Headlines / display | **Telegraf** | Medium only |
| Labels, body, logo text | **Open Sauce One** | Medium only |

Only **one weight (Medium)** is used for both families. Do not add bold or light anywhere; hierarchy comes from **size and uppercase**, not weight.

> Font files are not bundled in this repo. Obtain both from their official distributors and **check each licence** before using in a submission or public deploy. Load locally with `next/font/local`. Fallback stack: `system-ui, -apple-system, "Segoe UI", sans-serif`.

### 3.2 Type scale **[MEASURED]** (on the 1440 x 810 template canvas)

| Token | Size | Font | Case | Seen on |
|---|---|---|---|---|
| `display-xl` | 164.5 px | Telegraf | Title case | Hero word "Cryptocurrency" |
| `display-l` | 127 px | Telegraf | Title case | "Beyond Money", "How It Works" (125 px) |
| `display-m` | 90.9 px | Telegraf | Title case | "What Exactly Is Cryptocurrency?" |
| `label` | 20 px | Open Sauce One | **UPPERCASE** | Chips, key names (BLOCKS, CHAIN), logo text |
| `body` | 15 px | Open Sauce One | Sentence case | Paragraphs, bullets, callouts |

- **Headline line-height: 1.0** **[MEASURED]** (91 px lines on 90.9 px type; 126 px on 127 px type). Very tight, intentional.
- **Body line-height: about 1.4** **[MEASURED]** (21 px line step on 15 px type).
- **Paragraph spacing in bullet lists:** one extra line of space between items **[MEASURED]** (42 px between item starts for 2-line items).
- **Headline tracking:** visibly tight **[ESTIMATED]**. Start at `letter-spacing: -0.03em` and compare against the template; adjust by eye.
- Headlines **break into 2 lines** by design (e.g. "What Exactly Is / Cryptocurrency?"). Keep the left-aligned stack; the hero is the only centered one.

### 3.3 Web adaptation **[EXTENSION]**
A 15 px body is too small for a web app. Keep the **proportions** but raise the floor:

```css
--fs-display-xl: clamp(3.5rem, 11.4vw, 10.3rem);  /* 164.5px at 1440 */
--fs-display-l:  clamp(3rem,   8.8vw,  7.9rem);   /* 127px */
--fs-display-m:  clamp(2.25rem,6.3vw,  5.7rem);   /* 91px */
--fs-label:      1.25rem;                         /* 20px, uppercase */
--fs-body:       1rem;                            /* 16px (template 15px) */
```
Dashboard/table text may go down to `0.875rem` only for dense data, never for headlines or primary actions.

---

## 4. Layout and spacing

### 4.1 Canvas and margins **[MEASURED]**
- Template canvas: **1440 x 810 (16:9)**.
- **Safe margin: 81 px on left, right, and top** (about 5.6 % of width). Logo star starts at x = 81, y = 83. Image cards start at y = 81 and end at x = 1358.
- Web rule: `padding-inline: clamp(1.25rem, 5.6vw, 5.06rem)`; max content width 1440 px, centered.

### 4.2 Composition patterns seen in the template
1. **Left-heavy:** huge headline top-left, details below, visual on the right.
2. **Centered hero:** one giant word, a chip beneath, a hexagon below that.
3. **Mirrored pairs:** two glass arcs or two notched photos flanking centered text.
4. **Overlap with intent:** glass arc overlaps the corner of a hexagon or panel; rings are cropped off-canvas. Overlap is part of the style, but **never over text**.

### 4.3 Spacing scale **[EXTENSION]**
`4, 8, 12, 16, 24, 32, 48, 64, 96` px. Section vertical gap: 96 px desktop, 64 px mobile.

### 4.4 Breakpoints **[EXTENSION]**
`sm 640`, `md 768`, `lg 1024`, `xl 1280`, `2xl 1440` (design reference width).

---

## 5. Signature components

### 5.1 Logo lockup **[MEASURED]**
- Magenta 8-arm asterisk star, **20 x 20 px** (at x=81, y=83) + product name in white, Open Sauce One Medium, 20 px, placed top-left (or top-center on hero).
- Use the project name here (the template's placeholder brand text must not be carried over).

### 5.2 Label chip **[MEASURED]**
- Fill `#22213d`, **square corners (no radius)**, height **60 px**.
- **6 px magenta bar** on the left edge (hero chip has bars on **both** left and right).
- Text: 20 px, UPPERCASE, white; left padding about 36 px after the bar.
- Use for: section tags, status badges, role tags.

### 5.3 Flow chips with connectors **[MEASURED]**
Chips like "Barter, Metal coins, Paper money, Digital currency, Credit cards": same slate chip with the left magenta bar, joined by **1 px white hairlines**; when the row ends, the line **turns with a rounded elbow** and continues on the next row (reverse direction, arrowhead at the end).
- Use for: **report journey tracker** (Committed, Revealed, Under review, Accepted, Paid).

### 5.4 Hexagon panel **[MEASURED shape, ESTIMATED proportion]**
- Elongated hexagon: flat top and bottom, **pointed left and right middle**, outlined with a **1 px white hairline**.
- Proportion on slide 2: width 636, height 290; top edge starts about **13 %** in from each side.
- Variants: (a) empty outline holding bullet text; (b) outline with **bottom-half blue glow** gradient holding a short statement; (c) outline extended by thin lines that run off-canvas.
- A **short magenta dash (61 x 6 px)** sits centered on the bottom (or top) edge of some hexagons as an accent **[MEASURED]**.

```css
.hex { clip-path: polygon(13% 0, 87% 0, 100% 50%, 87% 100%, 13% 100%, 0 50%); }
```
Because `clip-path` cuts off a CSS border, draw the hairline with an **inline SVG polygon** (`stroke: #fff; stroke-width: 1; fill: none`) behind or over the content.

### 5.5 Gradient callout panel **[MEASURED]**
- Sharp-cornered rectangle (no radius), horizontal blue-to-midnight gradient, white 15 px text left-padded about 100 px.
- Use for: **big stats** and one-line takeaways (e.g. "Total value locked", "Reports paid today").

### 5.6 Notched image card **[ESTIMATED]**
- Rounded rectangle (radius about 40 to 48 px) with **one corner removed by a diagonal, stepped cut**; the cut corner changes per card (bottom-left, top-right...). Size on slide 2: **490 x 357 px**.
- Content: photo or illustration, never plain boxes.
- Build with `clip-path: polygon(...)` for the cut plus `border-radius` on the element; tune the polygon by eye against the template.

### 5.7 Glass arc (hero 3D object)
- Pre-rendered **transparent PNG/WebP** of the iridescent glass arc (see section 8). Sizes seen: small accent (about 180 px) to large corner piece (about 300 px). Used in pairs (mirrored, one flipped) or single, always partly overlapping a hexagon, panel, or card corner.

### 5.8 Large rings **[MEASURED colors]**
- Thick quarter or half rings in the **ring gradient**, partly cropped by the viewport edge, placed at corners behind content (top-right, bottom-left, bottom-center). Purely decorative: `aria-hidden`, `pointer-events: none`, low z-index.

### 5.9 Hairlines **[MEASURED]**
- 1 px, white. Used for hexagon outlines, long diagonal and horizontal guide lines that exit the canvas, and flow connectors. Keep them thin; never thicken for emphasis.

---

## 6. Template slide patterns mapped to this project

| Template slide | Pattern | VaultHunt use |
|---|---|---|
| 1. Title | Giant centered word, hero chip, hexagon with one-line pitch, two mirrored glass arcs | **Landing hero:** "VaultHunt" display-xl, chip `TRUSTLESS BUG BOUNTIES`, hexagon line: "Lock the reward. Prove the find. Get paid by code." |
| 2. What exactly is | Left headline, notched image, hexagon bullets, gradient callout | **"What is it?"** section: 3 bullets (lock, commit, pay), callout with live "Total locked" |
| 3. Journey | Flow chips with elbow connector + hexagon statement | **Report journey tracker** |
| 4. How it works | Chip + hexagon with KEY / value rows ("BLOCKS / CHAIN") | **Contract map:** KEY = contract name (ESCROW, REGISTRY, COURT, SBT), value = one-line job |
| 5. Power of... | Centered headline, two notched photos, center hexagon with three short lines | **Why trustless:** 3 promises (No ghosting, Proof of priority, Fair jury) |
| 6. Beyond money | Left photo, right bullets, gradient stat callout | **Live stats** (paid out, active programs, hunters) |
| 7. Opportunities and risks | Two chips each with a short list | **For Hunters / For Companies** |
| 8. Global impact | Hexagon bullets + notched photo + magenta dash | **Reputation and levels** teaser |
| 9. Future landscape | Chip + bullets + gradient callout + visual | **Roadmap** (VRF jury, zk badge, L2) |
| 10. Final thoughts | Centered title, chip, two photos, hexagon | **CTA footer:** "Launch app" and "Browse programs" |

---

## 7. App screens (interactive layer) **[EXTENSION, built only from tokens above]**

All screens keep the midnight background, 81 px-style margins, one giant heading per screen, and glow only where something is important.

### 7.1 Top navigation
- Transparent over `--bg`, logo lockup left, links in label style (20 px uppercase is too large here: use 14 px uppercase, same font), **RainbowKit connect button** restyled: slate chip, magenta left bar, white text. Connected state shows short address and a small blue-glow dot.

### 7.2 Programs page (`/programs`)
- Grid of **Vault cards**: notched card shape, slate surface, program name (display-m scaled down to 28 to 32 px), reward range, and an **animated fill bar** (blue gradient rising) showing locked funds. Hover: glass arc nudges, hairline outline appears.
- Filter row of label chips.

### 7.3 Program detail
- Left: headline, scope bullets inside a hexagon outline. Right: gradient callout with **locked amount** and severity payout table (4 rows: Low, Medium, High, Critical) as flow chips.
- Primary action `SUBMIT REPORT`: blue-peak solid button, white text, magenta focus ring.

### 7.4 Submit report (2-step)
- Step indicator = flow chips. Step 1 "Commit" (hash only), step 2 "Reveal" (encrypted upload).
- Form inputs: slate fill `#22213d`, 1 px white-20% border, white text, magenta caret and focus outline.
- Transaction feedback panel (pending / confirmed / failed) as a gradient callout with plain-language text.

### 7.5 Company review dashboard
- Table on `--bg` with hairline row dividers (white at 12% **[EXTENSION]**), status chips from section 2.4, row actions `ACCEPT`, `REJECT` (reject has magenta bar).

### 7.6 Dispute / Jury room
- Centered layout like template slide 5: huge case title, juror avatars as glass-ring badges, countdown in display-l, vote reveal animation (chips flip from slate to white or magenta-bar).

### 7.7 Profile and leaderboard
- Level badge shown with a **glass arc** whose tint steps up with level (kept within blue + magenta). XP bar = thin blue gradient on slate track. Leaderboard rows with rank in display-m numerals.

### 7.8 Toasts and live feed
- Toast: slate surface, magenta left bar, 15 to 16 px text, bottom-right, auto-dismiss 5 s.
- Live activity ticker: single line along the bottom or top, 14 px uppercase label style, hairline top border, scrolling slowly (pausable on hover).

### 7.9 Buttons **[EXTENSION]**
| Type | Style |
|---|---|
| Primary | Fill `--blue-peak`, white text 16 px Medium, square corners to match chips, hover: brighten gradient |
| Secondary | Transparent, 1 px white hairline, white text, hover: slate fill |
| Danger-ish | Secondary with magenta left bar |
| Focus (all) | 2 px magenta outline offset 2 px |

---

## 8. Imagery and assets

- **Glass arcs:** export from the template or recreate; deliver as transparent WebP at 2x. Provide 2 to 3 rotations so pairs look mirrored.
- **Photos:** the template uses stock photos (coins, hands, keyboards) cropped into notched cards. For the project prefer abstract blockchain, vault, code or circuit imagery; avoid recognizable people or brand logos.
- **Rings:** pure CSS (radial/conic gradient with mask) or SVG, no image needed.
- **Licence note:** template and stock assets from the design tool carry usage terms. Confirm they permit your academic submission and public demo; otherwise recreate or replace.
- **Icons:** one set only, outline style, 1.5 px stroke, white (lucide-react recommended; matches the thin hairline language).

---

## 9. Motion **[EXTENSION]** (Framer Motion)

| Element | Motion | Timing |
|---|---|---|
| Glass arcs | Slow float and slight rotate | 6 to 8 s loop, ease-in-out |
| Hexagon outlines | Draw-in (stroke-dashoffset) when scrolled into view | 0.9 s |
| Gradient panels | Subtle horizontal shimmer on hover | 0.6 s |
| Flow chips | Sequential reveal left to right, 80 ms stagger | 0.4 s each |
| Vault fill | Height animates to value | 1.0 s ease-out |
| Payout success | Lock-open, glass arc pulse, XP bar fill | 1.2 s total |
| Page transitions | Fade + 12 px rise | 0.35 s |

Rules: respect `prefers-reduced-motion` (disable float and shimmer, keep fades). Never animate text colors on loop. No more than one looping animation in view at once.

---

## 10. Responsive behavior **[EXTENSION]**

- **Desktop (1280+):** exact template compositions.
- **Tablet (768 to 1279):** split layouts stack; glass arcs shrink to 60 %; rings stay but smaller.
- **Mobile (below 768):** single column; hexagons become wider (inset 6 %) so text fits; chip rows wrap and connectors become vertical; display-xl never below 3.5 rem; hide the second glass arc of any pair; keep one ring only.
- Touch targets at least 44 px high.

---

## 11. Accessibility **[EXTENSION]**

- Never rely on color alone (always icon plus text for state).
- All decorative arcs, rings and hairlines: `aria-hidden="true"`.
- Visible focus ring on every interactive element (magenta).
- Keyboard-operable vote and review actions; countdowns announced via `aria-live="polite"`.
- Transaction errors written in plain language ("You rejected the request in your wallet"), not raw error codes.

---

## 12. Implementation tokens (copy-paste)

### 12.1 CSS variables (`globals.css`)
```css
:root {
  --bg: #020020;
  --surface: #22213d;
  --accent: #ff01dc;
  --blue-peak: #0f00d0;
  --text: #ffffff;
  --text-muted: rgba(255,255,255,0.72);
  --hairline: #ffffff;
  --gradient-panel: linear-gradient(90deg, #0f00cc 0%, #0b0099 40%, #050046 80%, #020020 100%);
  --gradient-hex-glow: linear-gradient(180deg, rgba(2,0,32,0) 0%, #0f00d0 100%);
  --margin-x: clamp(1.25rem, 5.6vw, 5.06rem);
}
html { background: var(--bg); color: var(--text); color-scheme: dark; }
```

### 12.2 Tailwind (`tailwind.config.js`)
```js
module.exports = {
  theme: {
    extend: {
      colors: {
        bg: "#020020", surface: "#22213d",
        accent: "#ff01dc", blue: { peak: "#0f00d0" },
      },
      fontFamily: {
        display: ["Telegraf", "system-ui", "sans-serif"],
        body: ["'Open Sauce One'", "system-ui", "sans-serif"],
      },
      lineHeight: { display: "1" },
      letterSpacing: { display: "-0.03em" },
    },
  },
};
```

### 12.3 Chip (reference markup)
```html
<span class="chip">ESCROW ENGINE</span>
<style>
.chip { background: var(--surface); height: 60px; display: inline-flex; align-items: center;
  padding: 0 36px; border-left: 6px solid var(--accent); font: 500 1.25rem/1 var(--font-body);
  text-transform: uppercase; }
</style>
```

---

## 13. Quality checklist (what "no flaws" means)

Before any screen is called done:

- [ ] Background is exactly `#020020`; no stray greys or pure black.
- [ ] Only the 5 core colors plus their gradients appear (no green, red, yellow, orange).
- [ ] Magenta used only on bars, dashes, star, focus, and small alerts, never large areas.
- [ ] All text is Telegraf (headlines) or Open Sauce One (everything else), **weight Medium only**.
- [ ] Headline line-height is 1.0 and tracking is tight; labels are UPPERCASE.
- [ ] Chips have square corners, a 6 px magenta bar, 60 px height.
- [ ] Hexagon outlines are 1 px white and not clipped by `clip-path`.
- [ ] Glass arcs never cover text; rings never intercept clicks.
- [ ] Margins match 81 px (scaled); no content touching the edge.
- [ ] Every state has icon + text, not color alone.
- [ ] Reduced-motion mode tested.
- [ ] Verified on 1440, 1024, 768, and 390 px widths.
- [ ] Fonts and imagery licences confirmed.

---

## 14. Honest limits of this document

- Colors, fonts, sizes, line-height, margins, chip height, bar width, dash size, and image-card size are **measured from the file**. Corner radii, the exact notch geometry, headline tracking, hexagon inset, and glass-arc dimensions are **estimated by eye**; confirm them by overlaying a screenshot of your build on the template.
- Everything for app screens, states, forms, tables, motion, and responsiveness is **an extension** of the template language, designed to stay inside its palette and shapes. The template itself only contains presentation slides.
