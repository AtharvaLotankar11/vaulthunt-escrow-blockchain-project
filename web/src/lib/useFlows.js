"use client";

import { useCallback } from "react";
import { useAccount } from "wagmi";
import { abis } from "@/lib/contracts";
import { encryptReport } from "@/lib/crypto";
import { getJson, putJson } from "@/lib/ipfs";
import { useBook } from "@/lib/hooks";
import { fetchProgram } from "@/lib/queries";
import { useTx } from "@/lib/useTx";

/**
 * Hunter, second half of the report flow: encrypt the report for the company, upload it,
 * then reveal it on-chain (which locks the reward). onStep gets "encrypt", "upload", "reveal".
 */
export function useReveal() {
  const tx = useTx();
  const { publicClient, book } = useBook();
  const { address } = useAccount();

  return useCallback(
    async ({ reportId, programId, secret, onStep }) => {
      onStep?.("encrypt");
      const program = await fetchProgram({ publicClient, book }, programId);
      if (!program?.profileURI) throw new Error("This program has not published an encryption key yet.");
      const profile = await getJson(program.profileURI);
      const encrypted = await encryptReport(secret.plaintext, profile.publicKey);

      onStep?.("upload");
      const cid = await putJson({
        v: 1,
        programId: Number(programId),
        reportId: Number(reportId),
        hunter: address,
        contentHash: secret.contentHash,
        summary: secret.summary ?? "",
        package: encrypted,
      });

      onStep?.("reveal");
      return tx({
        label: "Reveal report",
        address: book.ReportRegistry,
        abi: abis.ReportRegistry,
        functionName: "revealReport",
        args: [BigInt(reportId), cid, secret.contentHash, secret.salt, secret.severity],
      });
    },
    [tx, publicClient, book, address],
  );
}

/** Hunter: dispute a rejection. Approve the fee if needed, pay it, then escalate. */
export function useEscalate() {
  const tx = useTx();
  const { publicClient, book } = useBook();
  const { address } = useAccount();

  return useCallback(
    async ({ reportId, fee }) => {
      const allowance = await publicClient.readContract({
        address: book.BountyToken,
        abi: abis.BountyToken,
        functionName: "allowance",
        args: [address, book.DisputeCourt],
      });
      if (allowance < fee) {
        await tx({ label: "Allow the dispute fee", address: book.BountyToken, abi: abis.BountyToken, functionName: "approve", args: [book.DisputeCourt, fee] });
      }
      const prepaid = await publicClient.readContract({
        address: book.DisputeCourt,
        abi: abis.DisputeCourt,
        functionName: "prepaid",
        args: [BigInt(reportId)],
      });
      if (prepaid[1] === 0n) {
        await tx({ label: "Pay the dispute fee", address: book.DisputeCourt, abi: abis.DisputeCourt, functionName: "payDisputeFee", args: [BigInt(reportId)] });
      }
      return tx({ label: "Send to the jury", address: book.ReportRegistry, abi: abis.ReportRegistry, functionName: "escalate", args: [BigInt(reportId)] });
    },
    [tx, publicClient, book, address],
  );
}
