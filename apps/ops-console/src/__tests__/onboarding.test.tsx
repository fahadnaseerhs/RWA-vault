/**
 * T6.1b component and logic tests: AC-11 (Next gated on isVerified), AC-12 (the ADR 0017
 * banner cannot be dismissed), AC-13 (a ReserveTooLow revert shows the §3.4 sentence and
 * no hex), the golden metadataHash (point 2), the state-branch table (point 5), clause 1
 * with pq-core's WASM build (point 3) and the signer rules (point 4).
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { ReactNode } from "react";
import { afterEach, describe, expect, it } from "vitest";
import {
  BAD_ATTESTATION_SIG_SENTENCE,
  MS1_RESERVE_BANNER,
  assetIdOf,
  attestationMessage,
  metadataHash,
  reserveTooLowSentence,
  type FixtureAttestation,
  type OnboardingInput,
} from "@rwa-vault/types";
import {
  GOLD_LOT_001,
  GOLD_LOT_001_METADATA_HASH,
} from "../../../../packages/types/src/__tests__/fixtures.js";
import { ChainRevert, signerProblem, type OnboardingChain } from "../onboarding/chain.js";
import { checkClause1 } from "../onboarding/clause1.js";
import type { Deployment } from "../onboarding/deployments.js";
import {
  AssetState,
  ZERO_ADDRESS,
  ZERO_HASH,
  mintPreflight,
  stateBranch,
  type AssetSnapshot,
} from "../onboarding/logic.js";
import { AdmitStep } from "../ui/AdmitStep.js";
import { AssetStep } from "../ui/AssetStep.js";
import { AttestationStep } from "../ui/AttestationStep.js";

afterEach(cleanup);

const NOW = 1_800_000_000n;
const TOKEN = "0x05Aa229Aec102f78CE0E852A812a388F076Aa555" as const;
const DEPLOYMENT: Deployment = {
  chainId: 31337,
  owner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  agent: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  identityRegistry: "0x712516e61C8B383dF4A63CFe83d7701Bce54B03e",
  assetRegistry: "0xbCF26943C0197d2eE0E5D05c716Be60cc2761508",
  attestationSource: "0x59F2f1fCfE2474fD5F0b9BA1E73ca90b143Eb8d0",
  token: TOKEN,
  valuationWindow: 86400,
};
const INPUT: OnboardingInput = { ...GOLD_LOT_001, assetId: "gold-lot-002", token: TOKEN };

function snapshot(over: Partial<AssetSnapshot> = {}): AssetSnapshot {
  return {
    state: AssetState.PENDING,
    tokenOf: TOKEN,
    assetOfToken: assetIdOf("gold-lot-002"),
    totalSupply: 0n,
    reserve: 0n,
    lastSeq: 0n,
    valuationTs: 0n,
    window: 86400n,
    sourceSeq: 0n,
    sourceEnvelopeHash: ZERO_HASH,
    metadataHash: ZERO_HASH,
    now: NOW,
    ...over,
  };
}

function fakeChain(over: Partial<OnboardingChain> = {}): OnboardingChain {
  const fail = () => Promise.reject(new Error("not expected in this test"));
  return {
    chainId: 31337,
    deployment: DEPLOYMENT,
    signer: DEPLOYMENT.agent,
    isVerified: async () => true,
    snapshot: async () => snapshot(),
    register: fail,
    submitAttestation: fail,
    admit: fail,
    mint: fail,
    ...over,
  };
}

function wrap(ui: ReactNode) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

const att = (over: Partial<FixtureAttestation> = {}): FixtureAttestation => ({
  format: "rwa-vault/ms1-fixture-attestation@0",
  algorithm: "ML-DSA-65",
  chainId: 31337,
  assetRef: "gold-lot-002",
  reserve: "999900000000000000000",
  seq: 1,
  valuationTs: Number(NOW) - 600,
  signature: "AAAA",
  ...over,
});

describe("AC-11: step 1 waits for isVerified", () => {
  it("keeps Next disabled while the provider wallet is not verified", async () => {
    let verified = false;
    wrap(<AssetStep chain={fakeChain({ isVerified: async () => verified })} onNext={() => {}} />);
    fireEvent.change(screen.getByLabelText("Onboarding input"), {
      target: { value: JSON.stringify(INPUT) },
    });
    await screen.findByText(/run VerifyWallet first/);
    expect((screen.getByRole("button", { name: "Next" }) as HTMLButtonElement).disabled).toBe(true);

    verified = true;
    cleanup();
    wrap(<AssetStep chain={fakeChain({ isVerified: async () => verified })} onNext={() => {}} />);
    fireEvent.change(screen.getByLabelText("Onboarding input"), {
      target: { value: JSON.stringify(INPUT) },
    });
    await waitFor(() =>
      expect((screen.getByRole("button", { name: "Next" }) as HTMLButtonElement).disabled).toBe(
        false,
      ),
    );
  });

  it("lists validator issues and keeps Next disabled", async () => {
    wrap(<AssetStep chain={fakeChain()} onNext={() => {}} />);
    fireEvent.change(screen.getByLabelText("Onboarding input"), {
      target: { value: JSON.stringify({ ...INPUT, fineness: 0 }) },
    });
    await screen.findByText(/\/fineness: must be an integer/);
    expect((screen.getByRole("button", { name: "Next" }) as HTMLButtonElement).disabled).toBe(true);
  });
});

describe("AC-12: the ADR 0017 banner", () => {
  it("is shown on the attestation step and has no way to close it", () => {
    wrap(
      <AttestationStep
        chain={fakeChain()}
        input={INPUT}
        loadKey={async () => new Uint8Array()}
        loadVerify={async () => async () => false}
        onNext={() => {}}
      />,
    );
    const banner = screen.getByTestId("ms1-banner");
    expect(banner.textContent).toBe(MS1_RESERVE_BANNER);
    expect(banner.querySelector("button")).toBeNull();
    expect(screen.queryByRole("button", { name: /dismiss|close|hide/i })).toBeNull();
  });
});

describe("AC-13: a revert is shown as the sentence, never as hex", () => {
  it("renders ReserveTooLow with R and S and no selector or hex anywhere", async () => {
    const R = 999_900_000_000_000_000_000n;
    const S = 1_000_000_000_000_000_000_000n;
    const chain = fakeChain({
      snapshot: async () => snapshot({ sourceSeq: 1n }),
      admit: async () => {
        throw new ChainRevert({ errorName: "ReserveTooLow", args: [R, S] });
      },
    });
    // The client-side pre-check passes (the envelope covers S); the chain refuses anyway.
    const v = { ok: true as const, att: att({ reserve: S.toString() }), envelopeHash: ZERO_HASH };
    const { container } = wrap(
      <AdmitStep chain={chain} input={INPUT} verified={v} onNext={() => {}} />,
    );
    fireEvent.click(await screen.findByRole("button", { name: "Submit attestation and admit" }));
    await screen.findByText(reserveTooLowSentence(R, S));
    expect(container.innerHTML).not.toMatch(/0x[0-9a-fA-F]/);
  });

  it("names a failing clause before anything is sent", async () => {
    const v = { ok: true as const, att: att({ reserve: "1" }), envelopeHash: ZERO_HASH };
    wrap(<AdmitStep chain={fakeChain()} input={INPUT} verified={v} onNext={() => {}} />);
    await screen.findByText(
      new RegExp(
        `Clause 3: ${reserveTooLowSentence(1n, BigInt(INPUT.intendedSupply)).replace(/[().]/g, "\\$&")}`,
      ),
    );
    expect(
      (screen.getByRole("button", { name: "Submit attestation and admit" }) as HTMLButtonElement)
        .disabled,
    ).toBe(true);
  });

  it("shows the multisig calldata when the token is not bound yet", async () => {
    const chain = fakeChain({
      snapshot: async () => snapshot({ tokenOf: ZERO_ADDRESS, assetOfToken: ZERO_HASH }),
    });
    const v = { ok: true as const, att: att(), envelopeHash: ZERO_HASH };
    wrap(<AdmitStep chain={chain} input={INPUT} verified={v} onNext={() => {}} />);
    await screen.findByText(/Waiting for the owner multisig/);
    expect(screen.getByRole("button", { name: "Re-check" })).toBeTruthy();
  });
});

describe("point 2: metadataHash", () => {
  it("reproduces GOLD_LOT_001_METADATA_HASH", () => {
    expect(metadataHash(GOLD_LOT_001)).toBe(GOLD_LOT_001_METADATA_HASH);
  });
});

describe("point 5: the T6.1a state-branch table", () => {
  const I = 999_900_000_000_000_000_000n;
  it.each([
    [AssetState.UNREGISTERED, 0n, "register"],
    [AssetState.PENDING, 0n, "admit"],
    [AssetState.LIVE, 0n, "mint"],
    [AssetState.LIVE, I, "already-live"],
    [AssetState.LIVE, 1n, "refuse"],
    [AssetState.FROZEN, 0n, "refuse"],
  ] as const)("state %i with supply %s → %s", (state, supply, kind) => {
    expect(stateBranch(snapshot({ state, totalSupply: supply }), I).kind).toBe(kind);
  });

  it("the mint pre-flight names the failing condition", () => {
    const live = snapshot({ state: AssetState.LIVE, reserve: I, valuationTs: NOW - 60n });
    expect(mintPreflight(live, I)).toBeUndefined();
    expect(mintPreflight({ ...live, valuationTs: NOW - 90000n }, I)).toMatch(/not fresh/);
    expect(mintPreflight(live, I + 1n)).toMatch(/exceeds the reserve/);
  });
});

describe("point 4: signer rules", () => {
  it("refuses the owner key, and the dev key off anvil", () => {
    expect(signerProblem("anvil-dev-key", 31337, DEPLOYMENT.agent, DEPLOYMENT)).toBeUndefined();
    expect(signerProblem("anvil-dev-key", 31337, DEPLOYMENT.owner, DEPLOYMENT)).toMatch(
      /owner key/,
    );
    expect(signerProblem("injected", 421614, DEPLOYMENT.agent, undefined)).toMatch(
      /No M3 deployment/,
    );
    expect(signerProblem("anvil-dev-key", 421614, DEPLOYMENT.agent, DEPLOYMENT)).toMatch(
      /only allowed on the local anvil/,
    );
  });
});

// vitest runs from apps/ops-console.
const PKG = resolve(process.cwd(), "../../packages/pq-core/pkg") + "/";
describe.skipIf(!existsSync(`${PKG}rwa_vault_pq_core_bg.wasm`))(
  "point 3: clause 1 with pq-core WASM (`pnpm pq:wasm`)",
  () => {
    it("accepts the custodian's signature and rejects a tampered envelope", async () => {
      const w = await import(/* @vite-ignore */ `${PKG}rwa_vault_pq_core.js`);
      w.initSync({ module: readFileSync(`${PKG}rwa_vault_pq_core_bg.wasm`) });
      w.init();
      const kp = w.keygen("ml-dsa-65");
      const body = att();
      const sig = w.sign("ml-dsa-65", kp.privateKey, attestationMessage(body));
      const env = { ...body, signature: Buffer.from(sig).toString("base64") };
      const verify = async (p: Uint8Array, m: Uint8Array, s: Uint8Array) =>
        w.verify("ml-dsa-65", p, m, s) as boolean;
      const enc = (o: unknown) => new TextEncoder().encode(JSON.stringify(o));
      const args = {
        publicKey: kp.publicKey as Uint8Array,
        chainId: 31337,
        assetRef: "gold-lot-002",
        verify,
      };

      const good = await checkClause1({ ...args, bytes: enc(env) });
      expect(good.ok).toBe(true);
      const bad = await checkClause1({ ...args, bytes: enc({ ...env, reserve: "1" }) });
      expect(bad).toEqual({ ok: false, reason: BAD_ATTESTATION_SIG_SENTENCE });
    });
  },
);
