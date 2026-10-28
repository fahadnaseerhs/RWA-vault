/**
 * @module @rwa-vault/types/onboarding-hash
 * @description The two byte recipes of onboarding, in one place for the Node script
 * (`scripts/onboard`) and the ops-console page:
 *
 * - `metadataHash`: the canonical eight-field recipe (T6.1a spec §3), twin of
 *   `OnboardAsset.metadataHash`; all three are held to `GOLD_LOT_001_METADATA_HASH`.
 * - the interim MS1 fixture attestation (T6.1a spec §2.2): its signed message and its
 *   strict parser. The custodian key is never read from the envelope.
 */
import { encodeAbiParameters, hexToBytes, keccak256, toBytes, type Hex } from "viem";
import type { OnboardingInput } from "./onboarding.js";

export const ATTESTATION_FORMAT = "rwa-vault/ms1-fixture-attestation@0";
export const ATTESTATION_ALGORITHM = "ML-DSA-65";
export const ATTESTATION_FIELDS = [
  "format",
  "algorithm",
  "chainId",
  "assetRef",
  "reserve",
  "seq",
  "valuationTs",
  "signature",
] as const;

/** A parsed fixture envelope. `reserve` stays a base-10 string, as in the file. */
export interface FixtureAttestation {
  readonly format: typeof ATTESTATION_FORMAT;
  readonly algorithm: typeof ATTESTATION_ALGORITHM;
  readonly chainId: number;
  readonly assetRef: string;
  readonly reserve: string;
  readonly seq: number;
  readonly valuationTs: number;
  /** Standard base64. */
  readonly signature: string;
}

/** `keccak256(bytes(slug))`, the on-chain asset id. */
export function assetIdOf(slug: string): Hex {
  return keccak256(toBytes(slug));
}

export function metadataHash(input: OnboardingInput): Hex {
  const vb = input.valuationBasis;
  return keccak256(
    encodeAbiParameters(
      [
        { type: "string" },
        { type: "string" },
        { type: "uint256" },
        { type: "uint16" },
        { type: "string" },
        { type: "string" },
        { type: "uint256" },
        { type: "string" },
      ],
      [
        input.assetId,
        input.description,
        BigInt(input.grossWeight),
        input.fineness,
        vb.source,
        vb.currency,
        BigInt(vb.unitValue),
        input.custodianId,
      ],
    ),
  );
}

/** The signed message: `abi.encode(format, chainId, assetId, reserve, seq, valuationTs)`. */
export function attestationMessage(
  a: Pick<FixtureAttestation, "chainId" | "assetRef" | "reserve" | "seq" | "valuationTs">,
): Uint8Array {
  return hexToBytes(
    encodeAbiParameters(
      [
        { type: "string" },
        { type: "uint256" },
        { type: "bytes32" },
        { type: "uint256" },
        { type: "uint64" },
        { type: "uint64" },
      ],
      [
        ATTESTATION_FORMAT,
        BigInt(a.chainId),
        assetIdOf(a.assetRef),
        BigInt(a.reserve),
        BigInt(a.seq),
        BigInt(a.valuationTs),
      ],
    ),
  );
}

export class MalformedAttestationError extends Error {
  readonly code = "MalformedAttestation";
}

/** Strict parse of an envelope's bytes; unknown fields (a `publicKey`, say) are rejected. */
export function parseFixtureAttestation(bytes: Uint8Array): FixtureAttestation {
  const bad = (m: string): never => {
    throw new MalformedAttestationError(m);
  };
  let a: Record<string, unknown> = {};
  try {
    a = JSON.parse(new TextDecoder().decode(bytes)) as Record<string, unknown>;
  } catch {
    bad("the attestation file is not JSON");
  }
  if (typeof a !== "object" || a === null || Array.isArray(a)) bad("must be a JSON object");
  for (const k of Object.keys(a)) {
    if (!(ATTESTATION_FIELDS as readonly string[]).includes(k)) {
      bad(
        `unknown field "${k}"; the custodian key is never read from the envelope (custodian.json)`,
      );
    }
  }
  for (const k of ATTESTATION_FIELDS) if (!Object.hasOwn(a, k)) bad(`missing field "${k}"`);
  if (a.format !== ATTESTATION_FORMAT) bad(`format must be "${ATTESTATION_FORMAT}"`);
  if (a.algorithm !== ATTESTATION_ALGORITHM) bad(`algorithm must be "${ATTESTATION_ALGORITHM}"`);
  if (!Number.isSafeInteger(a.chainId) || (a.chainId as number) <= 0)
    bad("chainId must be a positive integer");
  if (typeof a.assetRef !== "string" || a.assetRef.length === 0) bad("assetRef must be a string");
  if (
    typeof a.reserve !== "string" ||
    !/^(0|[1-9][0-9]*)$/.test(a.reserve) ||
    BigInt(a.reserve) >= 2n ** 256n
  )
    bad("reserve must be a base-10 uint256 string");
  for (const k of ["seq", "valuationTs"] as const) {
    if (!Number.isSafeInteger(a[k]) || (a[k] as number) <= 0)
      bad(`${k} must be a positive integer`);
  }
  if (typeof a.signature !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(a.signature))
    bad("signature must be base64");
  return a as unknown as FixtureAttestation;
}
