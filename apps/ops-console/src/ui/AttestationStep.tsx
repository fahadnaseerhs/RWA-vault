import type { OnboardingInput } from "@rwa-vault/types";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import type { OnboardingChain } from "../onboarding/chain.js";
import { checkClause1, type Clause1Result, type VerifyFn } from "../onboarding/clause1.js";
import { assetIdOf } from "@rwa-vault/types";
import { freshnessLeft } from "../onboarding/logic.js";
import { Problem, ReserveBanner, grams } from "./common.js";

export type Verified = Extract<Clause1Result, { ok: true }>;

/** Step 2 — the custodian envelope, clause 1 checked in the browser (T6.1b point 3). */
export function AttestationStep({
  chain,
  input,
  loadKey,
  loadVerify,
  onNext,
}: {
  chain: OnboardingChain;
  input: OnboardingInput;
  loadKey: (chainId: number) => Promise<Uint8Array>;
  loadVerify: () => Promise<VerifyFn>;
  onNext: (v: Verified) => void;
}) {
  const [result, setResult] = useState<Clause1Result>();
  const [busy, setBusy] = useState(false);
  const snap = useQuery({
    queryKey: ["snapshot", chain.chainId, input.assetId],
    queryFn: () => chain.snapshot(assetIdOf(input.assetId)),
    refetchInterval: 5000,
  });

  async function onFile(bytes: Uint8Array) {
    setBusy(true);
    try {
      setResult(
        await checkClause1({
          bytes,
          publicKey: await loadKey(chain.chainId),
          chainId: chain.chainId,
          assetRef: input.assetId,
          verify: await loadVerify(),
        }),
      );
    } catch (e) {
      setResult({ ok: false, reason: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  const left = result?.ok && snap.data ? freshnessLeft(result.att, snap.data) : undefined;
  return (
    <section>
      <h2>2. Attestation</h2>
      <ReserveBanner />
      <input
        type="file"
        accept="application/json"
        aria-label="Custodian attestation"
        onChange={async (e) => {
          const f = e.target.files?.[0];
          if (f) await onFile(new Uint8Array(await f.arrayBuffer()));
        }}
      />
      {busy && <p>Checking the custodian signature…</p>}
      {result && !result.ok && <Problem>{result.reason}</Problem>}
      {result?.ok && (
        <dl>
          <dt>Custodian signature</dt>
          <dd>valid for the registered custodian key</dd>
          <dt>Reserve</dt>
          <dd>
            {grams(BigInt(result.att.reserve))} ({result.att.reserve})
          </dd>
          <dt>Sequence</dt>
          <dd>{result.att.seq}</dd>
          <dt>Valuation time</dt>
          <dd>{new Date(result.att.valuationTs * 1000).toISOString()}</dd>
          <dt>Fresh for</dt>
          <dd>
            {left === undefined ? "…" : left > 0n ? `${left} seconds more` : "no longer fresh"}
          </dd>
        </dl>
      )}
      <button type="button" disabled={!result?.ok} onClick={() => result?.ok && onNext(result)}>
        Next
      </button>
    </section>
  );
}
