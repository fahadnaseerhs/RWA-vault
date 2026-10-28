/**
 * @module @rwa-vault/types/onboarding
 * @description Declarative input for provider onboarding (M3, task T6.0).
 *
 * One JSON file describes one asset lot. It is the contract between the two
 * onboarding front-ends, which must never drift on input:
 *
 *   contracts/script/OnboardAsset.s.sol   (T6.1a — reads it with vm.parseJson)
 *   apps/ops-console onboarding page      (T6.1b — validates it with this module)
 *
 * The machine-readable twin of this type is
 * `packages/types/schema/onboarding-input.schema.json`. Tests assert the two agree
 * on field names, required-ness and every shared regex pattern, and a parity
 * harness runs each test case through both this validator and an independent
 * JSON Schema implementation (Ajv, a devDependency only), so editing one without
 * the other fails CI. Three checks are TypeScript-only by design, because JSON
 * Schema cannot express them: a future `valuationTs` (needs a clock),
 * `providerWallet == token` (compares two fields), and the exact `uint256`
 * ceiling inside the 78-digit band (the schema only caps the length).
 *
 * SECURITY — NO KEY MATERIAL, BY CONSTRUCTION:
 *   Input files are committed to git. The type therefore has no field that could
 *   hold a private key, keystore, seed or mnemonic, and the validator rejects any
 *   property it does not know — so a stray `"privateKey": "..."` is an error, not
 *   silently ignored. Signing keys reach the script only through `--private-key`,
 *   `--keystore` or `$ONBOARD_AGENT_KEY` (ADR 0015).
 *
 * DUPLICATE KEYS ARE INVISIBLE: `JSON.parse` keeps the last of two identical
 * keys, so no validator — this one or any JSON Schema implementation — can see
 * that a file said two different things. Git review is the only defence.
 *
 * Research and acceptance criteria: Obsidian notes "T6 - Provider Onboarding
 * Console" §3.2 and §6 (AC-1…AC-3), "T6.0 - Researcher Answers" (B1, B6) and
 * "T6.0 - Researcher Answers (round 2)" (Q1–Q7, P1, P2).
 */

/** A 20-byte EVM address as `0x` + 40 hex digits. Checksum case is not enforced here (AC-20). */
export type HexAddress = `0x${string}`;

/**
 * An unsigned integer encoded as a base-10 string.
 *
 * Fixed-point amounts (18 decimals) exceed `Number.MAX_SAFE_INTEGER`, so they are
 * never JSON numbers — a number would silently lose precision in `JSON.parse`.
 */
export type UintString = string;

/** Who signed an attestation envelope. MS1 has only the custodian (ADR 0017). */
export type AttestorRole = "custodian";

/** How the lot is valued. */
export interface ValuationBasis {
  /** Human-readable price source, e.g. "LBMA PM auction". */
  readonly source: string;
  /** Three uppercase letters. Not checked against the ISO 4217 register; the provider confirms it at onboarding. */
  readonly currency: string;
  /** Price per FINE gram (ADR 0020), 18-decimal fixed point. 0 < value <= 2^256 - 1. */
  readonly unitValue: UintString;
  /**
   * When `unitValue` was quoted, Unix seconds. Must not be in the future.
   * Informational on-chain: the chain's freshness check (`ValuationStale`) uses
   * the timestamp inside the signed custodian envelope, so editing this field
   * never clears that revert.
   */
  readonly valuationTs: number;
}

/** A signed custodian envelope read from disk — the script's form. */
export interface AttestationFromPath {
  readonly attestor: AttestorRole;
  /** Path to the CBOR envelope, relative to the contracts/ directory; never absolute, never `..`. */
  readonly path: string;
  readonly bytesBase64?: never;
}

/** A signed custodian envelope carried inline — the console's form (a browser has no path). */
export interface AttestationInline {
  readonly attestor: AttestorRole;
  /** The CBOR envelope bytes, standard base64. */
  readonly bytesBase64: string;
  readonly path?: never;
}

/** One signed custodian envelope: exactly one of `path` or `bytesBase64`, never both. */
export type AttestationRef = AttestationFromPath | AttestationInline;

/**
 * The full onboarding input for one asset lot.
 *
 * Weight basis (ADR 0020): `intendedSupply` is in FINE grams and must equal
 * `grossWeight × fineness / 10000`. That relation is checked by the onboarding
 * script (T6.1a), not by this validator.
 *
 * `attestations` is an array even though MS1 uses exactly one element: if Q11
 * (insurer as required co-signer) lands, admission becomes a threshold check
 * over an attestor set, and widening a scalar later would touch the schema,
 * the script, the page and every fixture. Enforcing "exactly one for MS1" is
 * the script's job (T6.1a), with a named error — not this type's.
 */
export interface OnboardingInput {
  /** Off-chain asset identifier: lowercase alphanumeric words joined by single hyphens, at most 32 chars. */
  readonly assetId: string;
  readonly description: string;
  /** Gross bar weight in grams, 18-decimal fixed point. 0 < value <= 2^256 - 1. */
  readonly grossWeight: UintString;
  /** Fineness in parts per 10,000 (999.9 fine = 9999), integer 1..10000. */
  readonly fineness: number;
  readonly valuationBasis: ValuationBasis;
  readonly custodianId: string;
  /** Tokens to mint, in FINE grams, 18-decimal fixed point (ADR 0020). 0 < value <= 2^256 - 1. */
  readonly intendedSupply: UintString;
  /** At least one envelope. */
  readonly attestations: readonly AttestationRef[];
  /**
   * The provider who owns the metal; receives the initial mint and starts at 100%
   * fractional title, selling down from there (C2). Never the operator. Must already
   * be `isVerified` on-chain (checked by the script). Not the zero address, not `token`.
   */
  readonly providerWallet: HexAddress;
  /** The per-asset token this lot is assigned to (ADR 0016: one token per asset). Not the zero address. */
  readonly token: HexAddress;
}

/** One problem found while validating, located by a JSON-pointer-style path. */
export interface OnboardingInputIssue {
  /** e.g. "/valuationBasis/unitValue" or "/attestations/0/path"; "" for the root. */
  readonly path: string;
  readonly message: string;
}

export type OnboardingValidationResult =
  | { readonly ok: true; readonly value: OnboardingInput }
  | { readonly ok: false; readonly issues: readonly OnboardingInputIssue[] };

/** Options for {@link validateOnboardingInput}. */
export interface OnboardingValidationOptions {
  /** "Now" in Unix seconds, for the future-`valuationTs` check. Defaults to the real clock; tests pass a fixed value. */
  readonly now?: number;
}

/** Top-level fields, in schema order. The drift test compares this to the JSON Schema. */
export const ONBOARDING_INPUT_FIELDS = [
  "assetId",
  "description",
  "grossWeight",
  "fineness",
  "valuationBasis",
  "custodianId",
  "intendedSupply",
  "attestations",
  "providerWallet",
  "token",
] as const satisfies readonly (keyof OnboardingInput)[];

export const VALUATION_BASIS_FIELDS = [
  "source",
  "currency",
  "unitValue",
  "valuationTs",
] as const satisfies readonly (keyof ValuationBasis)[];

/** Every field an attestation may carry; only `attestor` is always required. */
export const ATTESTATION_REF_FIELDS = [
  "attestor",
  "path",
  "bytesBase64",
] as const satisfies readonly (keyof AttestationFromPath | keyof AttestationInline)[];

/** Where the envelope comes from: exactly one of these must be present. */
export const ATTESTATION_SOURCE_FIELDS = ["path", "bytesBase64"] as const;

export const ATTESTOR_ROLES = ["custodian"] as const satisfies readonly AttestorRole[];

/**
 * The input fields committed into `metadataHash`, as JSON pointers, in A2's
 * canonical `abi.encode` order (eight fields). A test asserts each resolves to a
 * schema property, so the hash recipe and the schema cannot drift.
 */
export const METADATA_HASH_FIELDS = [
  "/assetId",
  "/description",
  "/grossWeight",
  "/fineness",
  "/valuationBasis/source",
  "/valuationBasis/currency",
  "/valuationBasis/unitValue",
  "/custodianId",
] as const;

/**
 * Regex patterns shared verbatim with the JSON Schema (a test asserts the schema
 * uses these exact strings). Compiled here with the `u` flag, as Ajv compiles
 * them: without `u`, `\P{...}` silently degrades to a literal "P" and the
 * visible-character check would pass everything.
 */
export const PATTERNS = {
  assetId: "^[a-z0-9]+(-[a-z0-9]+)*$",
  /** At least one character outside Unicode Cc, Cf, Zs, Zl and Zp (Q6). */
  visible: "[^\\p{Cc}\\p{Cf}\\p{Zs}\\p{Zl}\\p{Zp}]",
  positiveUint: "^[1-9][0-9]*$",
  currency: "^[A-Z]{3}$",
  address: "^0x[0-9a-fA-F]{40}$",
  zeroAddress: "^0x0{40}$",
  /** Relative, not drive- or UNC-rooted, no `..` segment, at least one non-space character (C4). */
  relativePath: "^(?![\\\\/])(?![A-Za-z]:)(?!(?:.*[\\\\/])?\\.\\.(?:[\\\\/]|$))(?=.*\\S)",
  base64: "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$",
} as const;

/** Length caps shared with the schema. 78 digits is the length of 2^256 - 1. */
export const MAX_ASSET_ID_LENGTH = 32;
export const MAX_UINT256_DIGITS = 78;
export const MAX_FINENESS = 10000;

const UINT256_MAX = 2n ** 256n - 1n;
const RE = Object.fromEntries(
  Object.entries(PATTERNS).map(([k, v]) => [k, new RegExp(v, "u")]),
) as Record<keyof typeof PATTERNS, RegExp>;

type Json = Record<string, unknown>;
type Issues = OnboardingInputIssue[];

function isObject(v: unknown): v is Json {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function checkFields(
  obj: Json,
  path: string,
  known: readonly string[],
  issues: Issues,
  required: readonly string[] = known,
): void {
  for (const k of required) {
    if (!Object.hasOwn(obj, k))
      issues.push({ path: `${path}/${k}`, message: `missing required field "${k}"` });
  }
  for (const k of Object.keys(obj)) {
    if (!known.includes(k))
      issues.push({ path: `${path}/${k}`, message: `unknown field "${k}" is not allowed` });
  }
}

// Absent fields are already reported by checkFields, so format checks skip `undefined`.

/** A string matching `pattern`; mirrors the schema's `type` + `minLength: 1` + `pattern`. */
function checkPattern(
  v: unknown,
  path: string,
  pattern: RegExp,
  message: string,
  issues: Issues,
): v is string {
  if (v === undefined) return false;
  if (typeof v !== "string" || v.length === 0) {
    issues.push({ path, message: "must be a non-empty string" });
    return false;
  }
  if (!pattern.test(v)) {
    issues.push({ path, message });
    return false;
  }
  return true;
}

function checkVisible(v: unknown, path: string, issues: Issues): void {
  checkPattern(v, path, RE.visible, "must contain at least one visible character", issues);
}

function checkUint256(v: unknown, path: string, issues: Issues): void {
  if (v === undefined) return;
  if (v === "0") {
    issues.push({ path, message: "must be greater than zero" });
  } else if (typeof v !== "string" || !RE.positiveUint.test(v)) {
    issues.push({
      path,
      message: 'must be a base-10 integer string (not a JSON number), e.g. "1000000000000000000"',
    });
  } else if (v.length > MAX_UINT256_DIGITS || BigInt(v) > UINT256_MAX) {
    issues.push({ path, message: "must not exceed the uint256 maximum (2^256 - 1)" });
  }
}

function checkAddress(v: unknown, path: string, issues: Issues): boolean {
  if (!checkPattern(v, path, RE.address, "must be a 0x-prefixed 20-byte hex address", issues))
    return false;
  if (RE.zeroAddress.test(v)) {
    issues.push({ path, message: "must not be the zero address" });
    return false;
  }
  return true;
}

/**
 * Validate an untrusted value (typically `JSON.parse` output) as an
 * {@link OnboardingInput}. Collects every issue rather than stopping at the
 * first, so an operator can fix the whole file in one pass. Errors only — no
 * warnings (P1); anything a human should merely be told belongs to the script's
 * pre-flight output.
 *
 * Checks shape and formats only. On-chain preconditions — provider wallet
 * verified, asset state, attestation signature and freshness — belong to the
 * script and the contracts.
 *
 * @param options.now "Now" in Unix seconds; defaults to the real clock. Pass a
 *   fixed value in tests so the future-timestamp check cannot flake.
 */
export function validateOnboardingInput(
  input: unknown,
  options: OnboardingValidationOptions = {},
): OnboardingValidationResult {
  const now = options.now ?? Math.floor(Date.now() / 1000);
  const issues: Issues = [];
  if (!isObject(input)) {
    return { ok: false, issues: [{ path: "", message: "must be a JSON object" }] };
  }
  checkFields(input, "", ONBOARDING_INPUT_FIELDS, issues);

  const id = input.assetId;
  if (typeof id === "string" && id.length > MAX_ASSET_ID_LENGTH) {
    issues.push({ path: "/assetId", message: `must be at most ${MAX_ASSET_ID_LENGTH} characters` });
  } else {
    checkPattern(
      id,
      "/assetId",
      RE.assetId,
      "must be lowercase letters and digits, in words joined by single hyphens (e.g. gold-lot-001)",
      issues,
    );
  }
  checkVisible(input.description, "/description", issues);
  checkUint256(input.grossWeight, "/grossWeight", issues);
  const f = input.fineness;
  if (
    f !== undefined &&
    (!Number.isInteger(f) || (f as number) < 1 || (f as number) > MAX_FINENESS)
  ) {
    issues.push({
      path: "/fineness",
      message: `must be an integer from 1 to ${MAX_FINENESS} (parts per 10,000; 999.9 fine = 9999)`,
    });
  }
  checkVisible(input.custodianId, "/custodianId", issues);
  checkUint256(input.intendedSupply, "/intendedSupply", issues);
  const providerOk = checkAddress(input.providerWallet, "/providerWallet", issues);
  const tokenOk = checkAddress(input.token, "/token", issues);
  if (
    providerOk &&
    tokenOk &&
    (input.providerWallet as string).toLowerCase() === (input.token as string).toLowerCase()
  ) {
    issues.push({
      path: "/providerWallet",
      message: "must not be the token contract itself; minting there would lock the whole supply",
    });
  }

  const vb = input.valuationBasis;
  if (!isObject(vb)) {
    if (vb !== undefined) issues.push({ path: "/valuationBasis", message: "must be an object" });
  } else {
    checkFields(vb, "/valuationBasis", VALUATION_BASIS_FIELDS, issues);
    checkVisible(vb.source, "/valuationBasis/source", issues);
    checkPattern(
      vb.currency,
      "/valuationBasis/currency",
      RE.currency,
      "must be a 3-letter uppercase currency code, e.g. USD",
      issues,
    );
    checkUint256(vb.unitValue, "/valuationBasis/unitValue", issues);
    const ts = vb.valuationTs;
    if (ts !== undefined) {
      if (typeof ts !== "number" || !Number.isSafeInteger(ts) || ts <= 0) {
        issues.push({
          path: "/valuationBasis/valuationTs",
          message: "must be a positive integer of Unix seconds",
        });
      } else if (ts > now) {
        issues.push({
          path: "/valuationBasis/valuationTs",
          message: "must not be in the future; a valuation cannot be dated after today",
        });
      }
    }
  }

  const atts = input.attestations;
  if (!Array.isArray(atts)) {
    if (atts !== undefined) issues.push({ path: "/attestations", message: "must be an array" });
  } else if (atts.length === 0) {
    issues.push({ path: "/attestations", message: "must contain at least one attestation" });
  } else {
    atts.forEach((a: unknown, i) => {
      const p = `/attestations/${i}`;
      if (!isObject(a)) {
        issues.push({ path: p, message: "must be an object" });
        return;
      }
      checkFields(a, p, ATTESTATION_REF_FIELDS, issues, ["attestor"]);
      const sources = ATTESTATION_SOURCE_FIELDS.filter((k) => Object.hasOwn(a, k));
      if (sources.length !== 1) {
        issues.push({ path: p, message: 'must have exactly one of "path" or "bytesBase64"' });
      }
      checkPattern(
        a.path,
        `${p}/path`,
        RE.relativePath,
        "must be a relative path inside contracts/ (not absolute, no '..')",
        issues,
      );
      checkPattern(a.bytesBase64, `${p}/bytesBase64`, RE.base64, "must be standard base64", issues);
      if (
        a.attestor !== undefined &&
        !(ATTESTOR_ROLES as readonly unknown[]).includes(a.attestor)
      ) {
        issues.push({
          path: `${p}/attestor`,
          message: `must be one of: ${ATTESTOR_ROLES.join(", ")}`,
        });
      }
    });
  }

  return issues.length === 0
    ? { ok: true, value: input as unknown as OnboardingInput }
    : { ok: false, issues };
}
