"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { MotionConfig } from "framer-motion";
import { WagmiProvider } from "wagmi";
import { ToastProvider } from "@/components/ui/Toasts";
import { wagmiConfig } from "@/lib/wagmi";

export function Providers({ children }) {
  const [queryClient] = useState(
    () => new QueryClient({ defaultOptions: { queries: { networkMode: "always", retry: 1 }, mutations: { networkMode: "always" } } }),
  );
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <MotionConfig reducedMotion="user">{children}</MotionConfig>
        </ToastProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
