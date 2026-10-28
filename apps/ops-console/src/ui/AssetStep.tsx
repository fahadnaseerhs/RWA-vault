import { metadataHash, validateOnboardingInput, type OnboardingInput } from "@rwa-vault/types";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import type { OnboardingChain } from "../onboarding/chain.js";
import { Check, Problem } from "./common.js";

/**
 * Step 1 — the lot (T6 spec §4.2). The same validator as the script; Next stays disabled
 * until the provider wallet is `isVerified` on chain (AC-11).
 */
export function AssetStep({
  chain,
  onNext,
}: {
  chain: OnboardingChain;
  onNext: (input: OnboardingInput) => void;
}) {
  const [text, setText] = useState("");
  let issues: string[] = [];
  let input: OnboardingInput | undefined;
  if (text.trim()) {
    try {
      const r = validateOnboardingInput(JSON.parse(text));
      if (r.ok) input = r.value;
      else issues = r.issues.map((i) => `${i.path || "/"}: ${i.message}`);
    } catch {
      issues = ["The file is not valid JSON."];
    }
  }
  if (input) {
    if (input.attestations.length !== 1) issues.push("MS1 takes exactly one attestation.");
    if (
      BigInt(input.grossWeight) * BigInt(input.fineness) !==
      BigInt(input.intendedSupply) * 10000n
    ) {
      issues.push("intendedSupply must equal grossWeight × fineness / 10000 (fine grams).");
    }
    if (input.token.toLowerCase() !== chain.deployment.token.toLowerCase()) {
      issues.push("This input is for a different token than the connected deployment.");
    }
  }
  const wallet = input?.providerWallet;
  const verified = useQuery({
    queryKey: ["isVerified", chain.chainId, wallet],
    queryFn: () => chain.isVerified(wallet!),
    enabled: !!wallet,
    refetchInterval: 5000,
  });
  const ready = !!input && issues.length === 0 && verified.data === true;

  return (
    <section>
      <h2>1. Asset</h2>
      <label>
        Onboarding input (JSON)
        <textarea
          aria-label="Onboarding input"
          rows={14}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
      </label>
      <input
        type="file"
        accept="application/json"
        aria-label="Load input file"
        onChange={async (e) => {
          const f = e.target.files?.[0];
          if (f) setText(await f.text());
        }}
      />
      {issues.length > 0 && (
        <ul className="issues">
          {issues.map((i) => (
            <li key={i}>{i}</li>
          ))}
        </ul>
      )}
      {input && (
        <ul className="checks">
          <Check ok={verified.data === true}>
            Provider wallet {input.providerWallet} is KYC-verified
            {verified.data === false && " — run VerifyWallet first (How to Run §6)"}
          </Check>
          <li>metadataHash {metadataHash(input)}</li>
        </ul>
      )}
      {verified.isError && <Problem>Could not read the identity registry.</Problem>}
      <button type="button" disabled={!ready} onClick={() => input && onNext(input)}>
        Next
      </button>
    </section>
  );
}
