/**
 * JSON Schema parity harness (T6.0 round 2, P2).
 *
 * Every case runs through BOTH the TypeScript validator and an independent JSON
 * Schema 2020-12 implementation (Ajv 8, a devDependency only — it never reaches
 * consumers of the package). They must agree on accept/reject, except for the
 * checks listed in {@link TS_ONLY_DIVERGENCES}, which JSON Schema cannot express.
 * A new divergence therefore fails CI. Subsumes the Debugger's D1/D2: loosening
 * a pattern in one file alone is caught here.
 *
 * Paths are not compared yet. Ajv reports a missing field as `instancePath` +
 * `params.missingProperty` where ours points at the field itself (Q7), so a path
 * comparison must normalise that first (addendum A3).
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Ajv2020 } from "ajv/dist/2020.js";

import { validateOnboardingInput, type OnboardingInput } from "../onboarding.js";
import { GOLD_LOT_001, NOW } from "./fixtures.js";

const schema = JSON.parse(
  readFileSync(new URL("../../schema/onboarding-input.schema.json", import.meta.url), "utf8"),
);
// Strict mode stays on, except `strictRequired`, which flags B6's exactly-one rule
// (`oneOf: [{required:[path]}, {required:[bytesBase64]}]`): those properties are
// declared one level up, which is valid 2020-12 but trips that lint.
const ajvValidate = new Ajv2020({ allErrors: true, strict: true, strictRequired: false }).compile(
  schema,
);

const UINT256_MAX = 2n ** 256n - 1n;
type Case = { readonly name: string; readonly input: unknown };
type Json = Record<string, unknown>;

function exceedsUint256(v: unknown): boolean {
  return (
    typeof v === "string" && /^[1-9][0-9]*$/.test(v) && v.length === 78 && BigInt(v) > UINT256_MAX
  );
}

/**
 * The ONLY places the TypeScript validator may reject what the schema accepts.
 * Each entry matches every case it covers, not a single fixture, so a genuine
 * divergence of the same kind elsewhere is still caught.
 */
const TS_ONLY_DIVERGENCES: readonly {
  readonly id: string;
  readonly applies: (input: Json) => boolean;
}[] = [
  // Q1: JSON Schema has no clock. Every case where valuationTs > now.
  {
    id: "Q1-future-valuationTs",
    applies: (i) => {
      const ts = (i.valuationBasis as Json | undefined)?.valuationTs;
      return typeof ts === "number" && ts > NOW;
    },
  },
  // Q3: JSON Schema cannot compare two fields.
  {
    id: "Q3-providerWallet-equals-token",
    applies: (i) =>
      typeof i.providerWallet === "string" &&
      typeof i.token === "string" &&
      i.providerWallet.toLowerCase() === i.token.toLowerCase(),
  },
  // Q2: the schema caps length at 78 digits; the exact 2^256 - 1 ceiling is TS-only.
  {
    id: "Q2-uint256-78-digit-band",
    applies: (i) =>
      exceedsUint256(i.intendedSupply) ||
      exceedsUint256(i.grossWeight) ||
      exceedsUint256((i.valuationBasis as Json | undefined)?.unitValue),
  },
];

const L = GOLD_LOT_001;
const vb = (patch: Json) => ({ ...L, valuationBasis: { ...L.valuationBasis, ...patch } });
const att = (a: unknown) => ({ ...L, attestations: [a] });
const without = (key: keyof OnboardingInput) => {
  const copy: Json = { ...L };
  delete copy[key];
  return copy;
};

const CASES: readonly Case[] = [
  { name: "fixture", input: L },
  // A: whole-input shape
  { name: "A1 null", input: null },
  { name: "A2 array", input: [] },
  { name: "A3 string", input: "x" },
  { name: "A3 number", input: 1 },
  { name: "A3 true", input: true },
  {
    name: "A6 __proto__ key",
    input: JSON.parse(JSON.stringify(L).slice(0, -1) + ',"__proto__":{}}'),
  },
  // B: assetId
  { name: "B1 assetId empty", input: { ...L, assetId: "" } },
  { name: "B2 assetId 33", input: { ...L, assetId: "a".repeat(33) } },
  { name: "assetId 32", input: { ...L, assetId: "a".repeat(32) } },
  { name: "B3 assetId uppercase", input: { ...L, assetId: "Gold-Lot-001" } },
  { name: "B4 assetId leading hyphen", input: { ...L, assetId: "-gold" } },
  { name: "B4 assetId trailing hyphen", input: { ...L, assetId: "gold-" } },
  { name: "B4 assetId double hyphen", input: { ...L, assetId: "go--ld" } },
  { name: "B5 assetId Cyrillic", input: { ...L, assetId: "gоld" } },
  // B: free text
  { name: "B6 description empty", input: { ...L, description: "" } },
  { name: "Q6 description ZWSP", input: { ...L, description: "\u200B" } },
  { name: "Q6 description NEL", input: { ...L, description: "\u0085" } },
  { name: "Q6 description NBSP", input: { ...L, description: "\u00A0" } },
  { name: "Q6 description BOM", input: { ...L, description: "\uFEFF" } },
  { name: "Q6 source ZWSP", input: vb({ source: "\u200B" }) },
  { name: "Q6 custodianId NBSP", input: { ...L, custodianId: "\u00A0" } },
  { name: "B18 custodianId empty", input: { ...L, custodianId: "" } },
  { name: "description with leading space", input: { ...L, description: " kilobar" } },
  // B: amounts
  { name: "B7 intendedSupply 0", input: { ...L, intendedSupply: "0" } },
  { name: "B8 intendedSupply 007", input: { ...L, intendedSupply: "007" } },
  ...["-5", "1e18", "0x10", " 1", "1 ", "1_000"].map((v) => ({
    name: `B9 intendedSupply ${JSON.stringify(v)}`,
    input: { ...L, intendedSupply: v },
  })),
  { name: "intendedSupply JSON number", input: { ...L, intendedSupply: 1e21 } },
  {
    name: "B10 intendedSupply uint256 max",
    input: { ...L, intendedSupply: UINT256_MAX.toString() },
  },
  {
    name: "B10 intendedSupply 2^256",
    input: { ...L, intendedSupply: (UINT256_MAX + 1n).toString() },
  },
  { name: "B10 intendedSupply 10^78-1", input: { ...L, intendedSupply: "9".repeat(78) } },
  { name: "B10 intendedSupply 79 digits", input: { ...L, intendedSupply: "1" + "0".repeat(78) } },
  { name: "B10 unitValue 100 digits", input: vb({ unitValue: "9".repeat(100) }) },
  { name: "B11 unitValue 0", input: vb({ unitValue: "0" }) },
  { name: "grossWeight 2^256", input: { ...L, grossWeight: (UINT256_MAX + 1n).toString() } },
  { name: "grossWeight 0", input: { ...L, grossWeight: "0" } },
  // fineness
  { name: "fineness 0", input: { ...L, fineness: 0 } },
  { name: "fineness 10000", input: { ...L, fineness: 10000 } },
  { name: "fineness 10001", input: { ...L, fineness: 10001 } },
  { name: "fineness 999.9", input: { ...L, fineness: 999.9 } },
  { name: "fineness string", input: { ...L, fineness: "9999" } },
  // B: valuationTs
  ...[0, -1, 1.5, 1e20].map((v) => ({
    name: `B12 valuationTs ${v}`,
    input: vb({ valuationTs: v }),
  })),
  { name: "B12 valuationTs string", input: vb({ valuationTs: "1761523200" }) },
  { name: "B13 valuationTs 2100", input: vb({ valuationTs: 4102444800 }) },
  { name: "Q1 valuationTs now", input: vb({ valuationTs: NOW }) },
  { name: "Q1 valuationTs now+1", input: vb({ valuationTs: NOW + 1 }) },
  // B: currency
  ...["usd", "US", "USDT", "EUR"].map((v) => ({
    name: `B14 currency ${v}`,
    input: vb({ currency: v }),
  })),
  // B: addresses
  { name: "B15 providerWallet zero", input: { ...L, providerWallet: "0x" + "0".repeat(40) } },
  { name: "B15 token zero", input: { ...L, token: "0x" + "0".repeat(40) } },
  { name: "B16 providerWallet == token", input: { ...L, providerWallet: L.token } },
  {
    name: "B16 providerWallet == token, other case",
    input: { ...L, providerWallet: L.token.toLowerCase() },
  },
  { name: "B17 address 39 hex", input: { ...L, token: "0x" + "a".repeat(39) } },
  { name: "B17 address 41 hex", input: { ...L, token: "0x" + "a".repeat(41) } },
  { name: "B17 address 0X prefix", input: { ...L, token: "0X" + "a".repeat(40) } },
  { name: "B17 address no prefix", input: { ...L, token: "a".repeat(40) } },
  {
    name: "B17 address bad checksum (format-only here)",
    input: { ...L, token: L.token.replace("F", "f") },
  },
  // C: attestations
  {
    name: "C1 both members",
    input: att({ attestor: "custodian", path: "a.cbor", bytesBase64: "AA==" }),
  },
  { name: "C2 neither member", input: att({ attestor: "custodian" }) },
  { name: "C3 path empty", input: att({ attestor: "custodian", path: "" }) },
  ...[
    "../../../etc/passwd",
    "script/../../x",
    "/etc/passwd",
    "C:\\keys",
    "\\\\srv\\share\\x",
    "..",
    "a/..",
  ].map((path) => ({ name: `C4 path ${path}`, input: att({ attestor: "custodian", path }) })),
  {
    name: "C4 path a..b is not a segment",
    input: att({ attestor: "custodian", path: "script/a..b.cbor" }),
  },
  { name: "C4 path whitespace only", input: att({ attestor: "custodian", path: "   " }) },
  {
    name: "C5 bytesBase64 invalid",
    input: att({ attestor: "custodian", bytesBase64: "not base64!" }),
  },
  { name: "C6 bytesBase64 empty", input: att({ attestor: "custodian", bytesBase64: "" }) },
  { name: "bytesBase64 valid", input: att({ attestor: "custodian", bytesBase64: "omFhAWFiAg==" }) },
  {
    name: "C7 1000 entries",
    input: { ...L, attestations: Array.from({ length: 1000 }, () => L.attestations[0]) },
  },
  {
    name: "C8 two custodians",
    input: { ...L, attestations: [L.attestations[0], L.attestations[0]] },
  },
  { name: "C9 attestor insurer", input: att({ attestor: "insurer", path: "a.cbor" }) },
  { name: "C10 attestor CUSTODIAN", input: att({ attestor: "CUSTODIAN", path: "a.cbor" }) },
  { name: "Q7 attestor missing", input: att({ path: "a.cbor" }) },
  { name: "attestations empty", input: { ...L, attestations: [] } },
  // missing / unknown fields
  ...(["description", "grossWeight", "fineness", "providerWallet", "token"] as const).map((k) => ({
    name: `missing ${k}`,
    input: without(k),
  })),
  { name: "unknown privateKey", input: { ...L, privateKey: "0x" + "ab".repeat(32) } },
  {
    name: "legacy treasuryWallet field",
    input: { ...without("providerWallet"), treasuryWallet: L.providerWallet },
  },
];

test("every case is accepted or rejected identically by TS and the JSON Schema", () => {
  const unexpected: string[] = [];
  for (const { name, input } of CASES) {
    const ts = validateOnboardingInput(input, { now: NOW }).ok;
    const schemaOk = ajvValidate(input);
    if (ts === schemaOk) continue;
    const allowed =
      !ts &&
      schemaOk &&
      typeof input === "object" &&
      input !== null &&
      TS_ONLY_DIVERGENCES.some((d) => d.applies(input as Json));
    if (!allowed) unexpected.push(`${name}: ts=${ts} schema=${schemaOk}`);
  }
  assert.deepEqual(unexpected, []);
});

test("each allow-listed divergence is actually exercised", () => {
  for (const d of TS_ONLY_DIVERGENCES) {
    const hits = CASES.filter(
      (c) =>
        typeof c.input === "object" &&
        c.input !== null &&
        d.applies(c.input as Json) &&
        !validateOnboardingInput(c.input, { now: NOW }).ok &&
        ajvValidate(c.input),
    );
    assert.ok(hits.length > 0, `${d.id} has no case where TS rejects and the schema accepts`);
  }
});
