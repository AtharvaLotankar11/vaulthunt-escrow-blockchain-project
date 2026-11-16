"use client";

import { useWalletName } from "@/lib/useWalletName";
import { shortAddress } from "@/lib/format";

/**
 * Renders an address with its display name (ENS or locally-saved nickname).
 * Falls back to the shortened address if no name is found.
 * The full address is always available as a title tooltip.
 */
export function AddressName({ address, fallback }) {
  const { displayName } = useWalletName(address);
  const short = fallback || shortAddress(address);

  return (
    <span title={address}>
      {displayName || short}
    </span>
  );
}
