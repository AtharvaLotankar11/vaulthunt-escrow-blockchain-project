"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import { encodeAbiParameters, keccak256, parseAbiParameters, parseEventLogs, toBytes } from "viem";
import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { SelectField, TextAreaField, TextField } from "@/components/ui/Field";
import { PageHeader } from "@/components/ui/PageHeader";
import { StateMessage } from "@/components/ui/StateMessage";
import { Stepper } from "@/components/ui/Stepper";
import { NeedWallet } from "@/components/wallet/NeedWallet";
import { SEVERITY } from "@/lib/chain";
import { abis } from "@/lib/contracts";
import { randomBytes32 } from "@/lib/crypto";
import { eth } from "@/lib/format";
import { useBook, useProfile, useProgram } from "@/lib/hooks";
import { reportSecrets } from "@/lib/secrets";
import { useAction } from "@/lib/useAction";
import { useReveal } from "@/lib/useFlows";
import { useTx } from "@/lib/useTx";

const PHASES = ["commit", "encrypt", "upload", "reveal", "done"];
const LABELS = ["Commit proof", "Encrypt", "Upload", "Reveal and lock reward"];

export default function SubmitPage() {
  const { id } = useParams();
  const router = useRouter();
  const { address } = useAccount();
  const { chainId, book } = useBook();
  const { data: program } = useProgram(id);
  const { data: profile } = useProfile(program?.profileURI);
  const tx = useTx();
  const reveal = useReveal();
  const { busy, error, run } = useAction();

  const [phase, setPhase] = useState("idle");
  const [title, setTitle] = useState("");
  const [summary, setSummary] = useState("");
  const [body, setBody] = useState("");
  const [severity, setSeverity] = useState("2");

  const cannotCover = program && program.unlocked < program.rewards[Number(severity)];
  const valid = title.trim().length >= 3 && body.trim().length >= 10;

  function submit() {
    return run(async () => {
      const plaintext = JSON.stringify({ title: title.trim(), body: body.trim(), programId: Number(id), hunter: address, createdAt: new Date().toISOString() });
      const contentHash = keccak256(toBytes(plaintext));
      const salt = randomBytes32();
      const commitHash = keccak256(encodeAbiParameters(parseAbiParameters("bytes32, bytes32, address"), [contentHash, salt, address]));

      // Saved BEFORE the transaction: without the salt and text the report could never be revealed.
      const secret = { plaintext, contentHash, salt, severity: Number(severity), summary: summary.trim(), programId: Number(id) };
      reportSecrets.save(chainId, commitHash, secret);

      setPhase("commit");
      const receipt = await tx({ label: "Commit report", address: book.ReportRegistry, abi: abis.ReportRegistry, functionName: "commitReport", args: [BigInt(id), commitHash] });
      const [committed] = parseEventLogs({ abi: abis.ReportRegistry, eventName: "ReportCommitted", logs: receipt.logs });

      await reveal({ reportId: committed.args.reportId, programId: id, secret, onStep: setPhase });
      setPhase("done");
      router.push("/hunter");
    });
  }

  const index = PHASES.indexOf(phase);
  const state = (i) => (phase === "idle" ? "todo" : i < index ? "done" : i === index ? "active" : "todo");

  return (
    <section className="page-x py-12">
      <PageHeader chip={`Program #${id}`} title="Submit a report" />
      {program && !program.profileURI ? (
        <StateMessage tone="alert" title="Not ready">
          The owner has not published an encryption key yet, so reports cannot be encrypted for them. <Link className="underline" href={`/programs/${id}`}>Back to the program</Link>
        </StateMessage>
      ) : (
        <NeedWallet what="submit a report">
          <div className="grid max-w-4xl gap-6">
            <Card>
              <p className="field-label">{profile?.name ?? `Program #${id}`}</p>
              <p className="text-muted">
                Your report is encrypted in this browser. Only the company can read it. First you publish a hash that proves you found it first; then the
                encrypted report is uploaded and the reward is locked for you.
              </p>
            </Card>

            <Card className="grid gap-6">
              <TextField label="Title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} placeholder="SQL injection in the login form" />
              <TextAreaField label="Full report (private, encrypted)" hint="Steps to reproduce, impact, proof of concept. Only the company can read this." value={body} onChange={(e) => setBody(e.target.value)} />
              <TextAreaField
                label="Short public summary (optional)"
                hint="If the company rejects you and you go to the jury, jurors see ONLY this. Do not put exploit details here."
                value={summary}
                onChange={(e) => setSummary(e.target.value)}
                maxLength={500}
                className="!min-h-24"
              />
              <SelectField
                label="Severity you claim"
                value={severity}
                onChange={(e) => setSeverity(e.target.value)}
                options={SEVERITY.map((label, i) => ({ value: String(i), label: `${label}${program ? ` (${eth(program.rewards[i])} ETH)` : ""}` }))}
                hint="This is the reward that gets locked for you. The company decides the final severity."
              />
              {cannotCover && <p role="alert" className="note-alert">This vault has {eth(program.unlocked)} ETH free, not enough to lock that reward right now. Choose a lower severity or ask the company to add funds.</p>}
            </Card>

            <Stepper steps={LABELS.map((label, i) => ({ label, state: state(i === 1 || i === 2 ? i : i) }))} />
            <div>
              <button type="button" className="btn" disabled={!valid || busy || cannotCover} onClick={submit}>
                {busy ? "Working…" : "Commit and submit"}
              </button>
            </div>
            {error && <p role="alert" className="note-alert">{error} You can continue later from My reports.</p>}
          </div>
        </NeedWallet>
      )}
    </section>
  );
}
