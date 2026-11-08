import "./globals.css";
import { DevTools } from "@/components/layout/DevTools";
import { Footer } from "@/components/layout/Footer";
import { LiveFeed } from "@/components/layout/LiveFeed";
import { Nav } from "@/components/layout/Nav";
import { Providers } from "./providers";

export const metadata = {
  title: "VaultHunt: trustless bug bounties",
  description:
    "A decentralized escrow system for bug bounty hunters. Locked rewards, encrypted reports, jury-based disputes.",
};

export const viewport = {
  themeColor: "#020020",
  colorScheme: "dark",
  viewportFit: "cover",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:bg-surface focus:px-4 focus:py-2"
        >
          Skip to content
        </a>
        <Providers>
          <Nav />
          <main id="main">{children}</main>
          <LiveFeed />
          <DevTools />
          <Footer />
        </Providers>
      </body>
    </html>
  );
}
