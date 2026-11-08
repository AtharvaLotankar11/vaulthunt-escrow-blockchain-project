import { defineChain } from "viem";
import { createConfig, http, injected } from "wagmi";
import { sepolia } from "wagmi/chains";

/** The local Anvil chain used for development (chain id 31337). */
export const anvil = defineChain({
  id: 31337,
  name: "Anvil Local",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["http://127.0.0.1:8545"] } },
  testnet: true,
});

/**
 * Browser wallets only: MetaMask and any other injected wallet. wagmi's own `injected`
 * connector is used (no wallet-picker library), which keeps the install small and the build
 * free of optional wallet SDKs. Because Anvil is listed in `chains`, a click on "Switch
 * network" makes MetaMask offer to ADD Anvil automatically.
 */
/** Which network the app uses by default: "anvil" (local) or "sepolia" (public test network). */
export const defaultChain = (process.env.NEXT_PUBLIC_DEFAULT_CHAIN || "anvil").toLowerCase() === "sepolia" ? sepolia : anvil;

export const wagmiConfig = createConfig({
  // the FIRST chain is the one the app reads from when no wallet is connected
  chains: defaultChain.id === sepolia.id ? [sepolia, anvil] : [anvil, sepolia],
  connectors: [injected()],
  transports: {
    [anvil.id]: http("http://127.0.0.1:8545"),
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC || undefined),
  },
  ssr: true,
});
