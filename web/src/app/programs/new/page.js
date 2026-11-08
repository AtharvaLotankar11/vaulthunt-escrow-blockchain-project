"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { parseEther, parseEventLogs } from "viem";
import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { TextAreaField, TextField } from "@/components/ui/Field";
import { PageHeader } from "@/components/ui/PageHeader";
import { Stepper } from "@/components/ui/Stepper";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { abis } from "@/lib/contracts";
import { useBook } from "@/lib/hooks";
import { uploadProfile } from "@/lib/profiles";
import { useAction } from "@/lib/useAction";
import { useTx } from "@/lib/useTx";
import { SEVERITY } from "@/lib/chain";

const STEPS = ["Key and profile", "Create vault", "Publish profile"];

export default function NewProgramPage() {
  const router = useRouter();
  const { address } = useAccount();
  const { chainId, book } = useBook();
  const tx = useTx();
  const { busy, error, run } = useAction();
  const [step, setStep] = useState(-1);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [deposit, setDeposit] = useState("10");
  const [tiers, setTiers] = useState(["5", "15", "30", "50"]);

  const bps = tiers.map((t) => Math.round(Number(t) * 100));
  const tiersValid = bps.every((b, i) => Number.isFinite(b) && b > 0 && b <= 10000 && (i === 0 || b >= bps[i - 1]));
  const valid = name.trim().length >= 3 && Number(deposit) >= 0 && tiersValid;

  function create() {
    return run(async () => {
      setStep(0);
      const cid = await uploadProfile(chainId, address, { name, description }); // creates the key if needed
      setStep(1);
      const receipt = await tx({
        label: "Create bounty vault",
        address: book.BountyFactory,
        abi: abis.BountyFactory,
        functionName: "createProgram",
        args: [address, bps],
        value: parseEther(deposit || "0"),
      });
      const [created] = parseEventLogs({ abi: abis.BountyFactory, eventName: "ProgramCreated", logs: receipt.logs });
      const programId = created.args.programId;
      setStep(2);
      await tx({
        label: "Publish program profile",
        address: book.ProgramDirectory,
        abi: abis.ProgramDirectory,
        functionName: "setProfile",
        args: [programId, cid],
      });
      setStep(3);
      router.push(`/programs/${programId}`);
    });
  }

  const stepState = (i) => (step < 0 ? "todo" : i < step ? "done" : i === step ? "active" : "todo");

  return (
    <section className="page-x py-12">
      <PageHeader chip="New program" title="Open a bounty vault" />
      <NeedWallet what="create a program">
        <div className="grid max-w-4xl gap-6">
          <Card className="grid gap-6">
            <TextField label="Program name" value={name} onChange={(e) => setName(e.target.value)} placeholder="Acme Payments API" maxLength={80} />
            <TextAreaField
              label="What hunters may test (scope)"
              hint="Public. Say which systems are in scope and what is out of scope."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={2000}
            />
          </Card>

          <Card className="grid gap-6">
            <div>
              <p className="field-label">Reward tiers (% of the vault, paid per finding)</p>
              <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
                {SEVERITY.map((label, i) => (
                  <TextField
                    key={label}
                    label={label}
                    type="number"
                    min="0.01"
                    max="100"
                    step="0.01"
                    value={tiers[i]}
                    onChange={(e) => setTiers((t) => t.map((v, j) => (j === i ? e.target.value : v)))}
                  />
                ))}
              </div>
              {!tiersValid && <p role="alert" className="field-hint note-alert">Each tier must be above 0, at most 100, and not lower than the tier before it.</p>}
            </div>
            <TextField
              label="Deposit now (ETH)"
              hint="This money is locked in your own vault. You can add more later and withdraw only what is not reserved for a report."
              type="number"
              min="0"
              step="0.1"
              value={deposit}
              onChange={(e) => setDeposit(e.target.value)}
            />
          </Card>

          <Card plain className="grid gap-4 !bg-transparent !p-0">
            <Stepper steps={STEPS.map((label, i) => ({ label, state: stepState(i) }))} />
            <p className="field-hint">
              Creating a program makes an encryption key in this browser. Hunters encrypt reports with its public half; only this
              browser can open them. Back up the key from the Company page.
            </p>
            <div>
              <button type="button" className="btn" disabled={!valid || busy} onClick={create}>
                {busy ? "Working…" : "Create program"}
              </button>
            </div>
            {error && <p role="alert" className="note-alert">{error}</p>}
          </Card>
        </div>
      </NeedWallet>
    </section>
  );
}
