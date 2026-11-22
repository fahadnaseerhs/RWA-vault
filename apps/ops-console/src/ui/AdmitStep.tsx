import { assetIdOf, metadataHash, type OnboardingInput } from "@rwa-vault/types";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { ChainRevert, type OnboardingChain } from "../onboarding/chain.js";
import {
  AssetState,
  admitClauses,
  bindCalldata,
  bindingStatus,
  describeRevert,
  stateBranch,
} from "../onboarding/logic.js";
import type { Verified } from "./AttestationStep.js";
import { Check, Problem } from "./common.js";

/**
 * Step 3 — register, bind, attest, admit. The state branch is re-read from chain on every
 * render. Clauses 2-4 are shown before anything is sent; a revert is shown as the §3.4
 * sentence, never as a selector or hex (AC-13).
 */
export function AdmitStep({
  chain,
  input,
  verified,
  onNext,
}: {
  chain: OnboardingChain;
  input: OnboardingInput;
  verified: Verified;
  onNext: () => void;
}) {
  const assetId = assetIdOf(input.assetId);
  const intended = BigInt(input.intendedSupply);
  const snap = useQuery({
    queryKey: ["snapshot", chain.chainId, input.assetId],
    queryFn: () => chain.snapshot(assetId),
    refetchInterval: 4000,
  });
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function run(step: () => Promise<unknown>) {
    setBusy(true);
    setError(undefined);
    try {
      await step();
    } catch (e) {
      const now = snap.data?.now ?? BigInt(Math.floor(Date.now() / 1000));
      setError(
        e instanceof ChainRevert ? describeRevert(e.revert, now) : describeRevert(undefined, now),
      );
    } finally {
      setBusy(false);
      await snap.refetch();
    }
  }

  const s = snap.data;
  if (!s)
    return (
      <section>
        <h2>3. Admit</h2>
        <p>Reading the asset from chain…</p>
      </section>
    );
  const branch = stateBranch(s, intended);
  const binding = bindingStatus(s, assetId, chain.deployment.token);
  const clauses = admitClauses(verified.att, s, intended);

  return (
    <section>
      <h2>3. Admit</h2>
      {branch.kind === "refuse" && <Problem>{branch.sentence}</Problem>}
      {branch.kind === "register" && (
        <button
          type="button"
          disabled={busy}
          onClick={() => run(() => chain.register(assetId, metadataHash(input), input.assetId))}
        >
          Register asset
        </button>
      )}
      {branch.kind !== "register" &&
        branch.kind !== "refuse" &&
        binding !== "bound" &&
        (binding === "unbound" ? (
          <div className="multisig">
            <p>
              Waiting for the owner multisig to bind the token. Ask the signers to execute this
              call, then re-check.
            </p>
            <pre>
              to {chain.deployment.assetRegistry}
              {"\n"}data {bindCalldata(assetId, chain.deployment.token)}
            </pre>
            <button type="button" onClick={() => snap.refetch()}>
              Re-check
            </button>
          </div>
        ) : (
          <Problem>{binding}</Problem>
        ))}
      {branch.kind === "admit" && binding === "bound" && (
        <>
          <ul className="checks" aria-label="Admission clauses">
            <Check ok>Clause 1: the custodian signature is valid</Check>
            {clauses.map((c) => (
              <Check key={c.clause} ok={c.ok}>
                Clause {c.clause}: {c.ok ? c.label : c.sentence}
              </Check>
            ))}
          </ul>
          <button
            type="button"
            disabled={busy || clauses.some((c) => !c.ok)}
            onClick={() =>
              run(async () => {
                if (s.sourceSeq < BigInt(verified.att.seq)) {
                  await chain.submitAttestation(
                    {
                      assetId,
                      reserve: BigInt(verified.att.reserve),
                      seq: BigInt(verified.att.seq),
                      valuationTs: BigInt(verified.att.valuationTs),
                    },
                    verified.envelopeHash,
                  );
                }
                await chain.admit(assetId, intended);
              })
            }
          >
            Submit attestation and admit
          </button>
        </>
      )}
      {error && <Problem>{error}</Problem>}
      <p>State: {["UNREGISTERED", "PENDING", "LIVE", "FROZEN"][s.state]}</p>
      <button
        type="button"
        disabled={!(s.state === AssetState.LIVE && binding === "bound" && branch.kind !== "refuse")}
        onClick={onNext}
      >
        Next
      </button>
    </section>
  );
}
