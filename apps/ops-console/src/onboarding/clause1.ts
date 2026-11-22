/**
 * Clause 1 in the browser (T6.1b point 3): the §2.2 fixture attestation checked with
 * pq-core's WASM ML-DSA-65 verify, over the shared message recipe from @rwa-vault/types.
 */
import {
  BAD_ATTESTATION_SIG_SENTENCE,
  MalformedAttestationError,
  attestationMessage,
  parseFixtureAttestation,
  type FixtureAttestation,
} from "@rwa-vault/types";
import { keccak256, toHex, type Hex } from "viem";

export type VerifyFn = (
  publicKey: Uint8Array,
  message: Uint8Array,
  signature: Uint8Array,
) => Promise<boolean>;

export type Clause1Result =
  | { readonly ok: true; readonly att: FixtureAttestation; readonly envelopeHash: Hex }
  | { readonly ok: false; readonly reason: string };

/** pq-core's WASM adapter, loaded on first use. */
export async function wasmVerify(): Promise<VerifyFn> {
  const { createWasmAdapter } = await import("@rwa-vault/pq-core/wasm");
  const adapter = createWasmAdapter();
  await adapter.init();
  return (pub, msg, sig) => adapter.verify("ml-dsa-65", pub, msg, sig);
}

function fromBase64(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

export async function checkClause1(args: {
  bytes: Uint8Array;
  publicKey: Uint8Array;
  chainId: number;
  assetRef: string;
  verify: VerifyFn;
}): Promise<Clause1Result> {
  let att: FixtureAttestation;
  try {
    att = parseFixtureAttestation(args.bytes);
  } catch (e) {
    if (e instanceof MalformedAttestationError)
      return { ok: false, reason: `This file is not a valid attestation: ${e.message}.` };
    throw e;
  }
  if (att.chainId !== args.chainId) {
    return {
      ok: false,
      reason: `This attestation was signed for chain ${att.chainId}, not the connected chain ${args.chainId}.`,
    };
  }
  if (att.assetRef !== args.assetRef) {
    return {
      ok: false,
      reason: `This attestation is for "${att.assetRef}", not "${args.assetRef}".`,
    };
  }
  let ok = false;
  try {
    ok = await args.verify(args.publicKey, attestationMessage(att), fromBase64(att.signature));
  } catch {
    ok = false;
  }
  if (!ok) return { ok: false, reason: BAD_ATTESTATION_SIG_SENTENCE };
  return { ok: true, att, envelopeHash: keccak256(toHex(args.bytes)) };
}
