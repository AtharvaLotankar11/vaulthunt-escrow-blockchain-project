export default function manifest() {
  return {
    name: "VaultHunt",
    short_name: "VaultHunt",
    description: "A decentralized escrow for bug bounty hunters. Lock it, prove it, get paid.",
    start_url: "/",
    display: "standalone",
    background_color: "#020020",
    theme_color: "#020020",
    icons: [
      { src: "/brand/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/brand/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/brand/icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
