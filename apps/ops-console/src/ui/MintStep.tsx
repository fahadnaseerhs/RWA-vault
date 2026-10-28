import { FIXTURE_RECEIPT_LINE, assetIdOf, type OnboardingInput } from "@rwa-vault/types";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { ChainRevert, type OnboardingChain } from "../onboarding/chain.js";
import { describeRevert, mintPreflight, stateBranch } from "../onboarding/logic.js";
import { Check, Problem, grams } from "./common.js";

/** Step 4 — mint to the provider, then the receipt with the invariant (T6 spec §4.2). */
export function MintStep({ chain, input }: { chain: OnboardingChain; input: OnboardingInput }) {
  const assetId = assetIdOf(input.assetId);
  const intended = BigInt(input.intendedSupply);
  const snap = useQuery({
    queryKey: ["snapshot", chain.chainId, input.assetId],
    queryFn: () => chain.snapshot(assetId),
    refetchInterval: 4000,
  });
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const s = snap.data;
  if (!s)
    return (
      <section>
        <h2>4. Mint</h2>
        <p>Reading the asset from chain…</p>
      </section>
    );

  const branch = stateBranch(s, intended);
  const blocked = branch.kind === "mint" ? mintPreflight(s, intended) : undefined;
  return (
    <section>
      <h2>4. Mint</h2>
      {branch.kind === "refuse" && <Problem>{branch.sentence}</Problem>}
      {branch.kind === "mint" && (
        <>
          {blocked && <Problem>Cannot mint yet: {blocked}.</Problem>}
          <button
            type="button"
            disabled={busy || !!blocked}
            onClick={async () => {
              setBusy(true);
              setError(undefined);
              try {
                await chain.mint(input.providerWallet, intended);
              } catch (e) {
                setError(describeRevert(e instanceof ChainRevert ? e.revert : undefined, s.now));
              } finally {
                setBusy(false);
                await snap.refetch();
              }
            }}
          >
            Mint {grams(intended)} to the provider
          </button>
        </>
      )}
      {error && <Problem>{error}</Problem>}
      {branch.kind === "already-live" && (
        <div className="receipt" aria-label="Receipt">
          <h3>Receipt</h3>
          <ul className="checks">
            <Check ok>State LIVE</Check>
            <li>
              Reserve {grams(s.reserve)} ({s.reserve.toString()})
            </li>
            <li>
              Supply {grams(s.totalSupply)} ({s.totalSupply.toString()})
            </li>
            <Check ok={s.totalSupply <= s.reserve}>Invariant: supply ≤ reserve</Check>
            <li>Sequence {s.lastSeq.toString()}</li>
          </ul>
          <p>Units: fine grams × 1e18; unitValue per fine gram (ADR 0020).</p>
          {input.valuationBasis.source.startsWith("FIXTURE") && (
            <p className="banner">{FIXTURE_RECEIPT_LINE}</p>
          )}
        </div>
      )}
    </section>
  );
}
