# Fonts

The app falls back to Inter / Segoe UI until the licensed fonts are installed (assumption A-3).

To use the real fonts (Telegraf for headings, Open Sauce One for body, Medium weight only):
1. Check each font's licence, then get the `.woff2` files from the official distributor.
2. Put them here as `Telegraf-Medium.woff2` and `OpenSauceOne-Medium.woff2`.
3. Add this to the top of `src/app/globals.css`:

```css
@font-face {
  font-family: "Telegraf";
  src: url("/fonts/Telegraf-Medium.woff2") format("woff2");
  font-weight: 500;
  font-display: swap;
}
@font-face {
  font-family: "Open Sauce One";
  src: url("/fonts/OpenSauceOne-Medium.woff2") format("woff2");
  font-weight: 500;
  font-display: swap;
}
```
