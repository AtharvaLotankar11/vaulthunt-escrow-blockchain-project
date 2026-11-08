"use client";

import { useAccount } from "wagmi";
import { Chip } from "@/components/ui/Chip";
import { abis } from "@/lib/contracts";
import { bbt } from "@/lib/format";
import { useBook, useJuror } from "@/lib/hooks";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";

/** BBT balance and the testnet faucet (100 BBT per day). BBT pays dispute fees and is staked by jurors. */
export function TokenBar() {
  const { address } = useAccount();
  const { book } = useBook();
  const tx = useTx();
  const { data: juror } = useJuror(address);
  const faucet = useAction();
  return (
    <div className="mb-8 flex flex-wrap items-center gap-3">
      <Chip size="sm">BBT balance {bbt(juror?.balance)}</Chip>
      <button type="button" className="btn btn--ghost btn--sm" disabled={faucet.busy} onClick={() => faucet.run(() => tx({ label: "Get test BBT", address: book.BountyToken, abi: abis.BountyToken, functionName: "faucet" }))}>
        Get 100 test BBT
      </button>
      {faucet.error && <span role="alert" className="text-sm note-alert">{faucet.error}</span>}
    </div>
  );
}
