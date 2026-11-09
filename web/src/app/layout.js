import "./globals.css";
import { DevTools } from "@/components/layout/DevTools";
import { Footer } from "@/components/layout/Footer";
import { LiveFeed } from "@/components/layout/LiveFeed";
import { Nav } from "@/components/layout/Nav";
import { Providers } from "./providers";

const DESCRIPTION =
  "A decentralized escrow system for bug bounty hunters. Locked rewards, encrypted reports and jury-based disputes: lock it, prove it, get paid.";

export const metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"),
  // The browser tab shows "<page> | VaultHunt"; the home page shows the full tagline.
  title: { default: "VaultHunt: fair bounties for bug hunters", template: "%s | VaultHunt" },
  description: DESCRIPTION,
  applicationName: "VaultHunt",
  authors: [{ name: "Atharva Lotankar" }, { name: "Vaishnavi Avhad" }, { name: "Bhoomi Naik" }],
  creator: "Atharva Lotankar, Vaishnavi Avhad and Bhoomi Naik",
  keywords: ["VaultHunt", "bug bounty", "escrow", "blockchain", "Ethereum", "smart contracts", "Sepolia"],
  openGraph: { title: "VaultHunt: fair bounties for bug hunters", description: DESCRIPTION, siteName: "VaultHunt", type: "website" },
  twitter: { card: "summary_large_image", title: "VaultHunt: fair bounties for bug hunters", description: DESCRIPTION },
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
