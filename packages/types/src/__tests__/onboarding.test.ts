/**
 * T6.0 acceptance tests (AC-1…AC-3) for the onboarding input schema.
 *
 * AC-2 is checked twice: at the type level (a two-element fixture annotated as
 * OnboardingInput must compile) and at runtime (the validator accepts it).
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  ATTESTATION_REF_FIELDS,
  ATTESTATION_SOURCE_FIELDS,
  MAX_ASSET_ID_LENGTH,
  MAX_FINENESS,
  MAX_UINT256_DIGITS,
  METADATA_HASH_FIELDS,
  ONBOARDING_INPUT_FIELDS,
  PATTERNS,
  VALUATION_BASIS_FIELDS,
  validateOnboardingInput,
  type OnboardingInput,
} from "../onboarding.js";
import { GOLD_LOT_001, NOW } from "./fixtures.js";

const SCHEMA = JSON.parse(
  readFileSync(new URL("../../schema/onboarding-input.schema.json", import.meta.url), "utf8"),
);

// AC-2: two attestations type-check. The script (T6.1a) rejects >1 for MS1 with a named error.
const TWO_ATTESTATIONS: OnboardingInput = {
  ...GOLD_LOT_001,
  attestations: [
    { path: "script/input/att.gold-lot-001.seq1.cbor", attestor: "custodian" },
    { path: "script/input/att.gold-lot-001.seq2.cbor", attestor: "custodian" },
  ],
};

// AC-2, the other direction: a scalar attestation must not type-check.
const SCALAR_ATTESTATION: OnboardingInput = {
  ...GOLD_LOT_001,
  // @ts-expect-error attestations is an array, not a single AttestationRef
  attestations: GOLD_LOT_001.attestations[0],
};
void SCALAR_ATTESTATION;

// B6 at the type level: both sources at once must not type-check.
const BOTH_SOURCES: OnboardingInput = {
  ...GOLD_LOT_001,
  // @ts-expect-error an attestation has exactly one of path or bytesBase64
  attestations: [{ attestor: "custodian", path: "a.cbor", bytesBase64: "AA==" }],
};
void BOTH_SOURCES;

function issuesOf(input: unknown): string[] {
  const r = validateOnboardingInput(input, { now: NOW });
  assert.equal(r.ok, false, "expected validation to fail");
  return r.ok ? [] : r.issues.map((i) => i.path);
}

test("AC-1: the §3.2 gold-lot fixture validates", () => {
  const r = validateOnboardingInput(JSON.parse(JSON.stringify(GOLD_LOT_001)), { now: NOW });
  assert.deepEqual(r, { ok: true, value: GOLD_LOT_001 });
});

test("AC-2: attestations is an array; a two-element fixture validates", () => {
  assert.equal(validateOnboardingInput(TWO_ATTESTATIONS).ok, true);
});

test("AC-2: an empty or scalar attestations field is rejected", () => {
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, attestations: [] }), ["/attestations"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, attestations: GOLD_LOT_001.attestations[0] }), [
    "/attestations",
  ]);
});

test("AC-3: no field name could hold key material", () => {
  const all = [...ONBOARDING_INPUT_FIELDS, ...VALUATION_BASIS_FIELDS, ...ATTESTATION_REF_FIELDS];
  for (const f of all) {
    assert.doesNotMatch(f, /key|secret|mnemonic|seed|phrase|password|keystore|signer/i, f);
  }
});

test("AC-3: a smuggled private key is rejected, not ignored", () => {
  for (const field of ["privateKey", "mnemonic", "agentKey"]) {
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, [field]: "0x" + "ab".repeat(32) }), [`/${field}`]);
  }
  const nested = {
    ...GOLD_LOT_001,
    attestations: [{ ...GOLD_LOT_001.attestations[0], signerKey: "x" }],
  };
  assert.deepEqual(issuesOf(nested), ["/attestations/0/signerKey"]);
});

test("amounts must be strings, never JSON numbers, and > 0", () => {
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, intendedSupply: 1e21 }), ["/intendedSupply"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, intendedSupply: "0" }), ["/intendedSupply"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, intendedSupply: "01" }), ["/intendedSupply"]);
  const vb = { ...GOLD_LOT_001.valuationBasis, unitValue: "1.5" };
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, valuationBasis: vb }), [
    "/valuationBasis/unitValue",
  ]);
});

test("formats: addresses, assetId, currency, timestamp", () => {
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, providerWallet: "0x123" }), ["/providerWallet"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, token: "not-an-address" }), ["/token"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, assetId: "Gold Lot 1" }), ["/assetId"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, assetId: "a".repeat(33) }), ["/assetId"]);
  const vb = { ...GOLD_LOT_001.valuationBasis, currency: "usd", valuationTs: 1.5 };
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, valuationBasis: vb }), [
    "/valuationBasis/currency",
    "/valuationBasis/valuationTs",
  ]);
});

test("a missing field is reported once, and all issues are collected", () => {
  const { description: _d, token: _t, ...rest } = GOLD_LOT_001;
  const r = validateOnboardingInput(rest);
  assert.equal(r.ok, false);
  if (!r.ok) {
    assert.deepEqual(
      r.issues.map((i) => i.message),
      ['missing required field "description"', 'missing required field "token"'],
    );
  }
  assert.deepEqual(issuesOf(null), [""]);
  assert.deepEqual(issuesOf([]), [""]);
});

test("the JSON Schema and the TS validator agree on field names and required-ness", () => {
  const schema = SCHEMA;
  const vb = schema.properties.valuationBasis;
  const att = schema.properties.attestations.items;
  for (const [node, fields] of [
    [schema, ONBOARDING_INPUT_FIELDS],
    [vb, VALUATION_BASIS_FIELDS],
  ] as const) {
    assert.deepEqual(Object.keys(node.properties), [...fields]);
    assert.deepEqual(node.required, [...fields]);
    assert.equal(node.additionalProperties, false);
  }
  assert.equal(schema.properties.attestations.type, "array");
  // Attestations: only `attestor` is always required; exactly one source field (B6).
  assert.deepEqual(Object.keys(att.properties), [...ATTESTATION_REF_FIELDS]);
  assert.deepEqual(att.required, ["attestor"]);
  assert.equal(att.additionalProperties, false);
  assert.deepEqual(
    att.oneOf.map((b: { required: string[] }) => b.required),
    ATTESTATION_SOURCE_FIELDS.map((f) => [f]),
  );
});

test("B6: an attestation may be inline base64 instead of a path", () => {
  const inline: OnboardingInput = {
    ...GOLD_LOT_001,
    attestations: [{ attestor: "custodian", bytesBase64: "omFhAWFiAg==" }],
  };
  assert.equal(validateOnboardingInput(inline).ok, true);
});

test("B6: an attestation with both path and bytesBase64 is rejected", () => {
  const both = [{ ...GOLD_LOT_001.attestations[0], bytesBase64: "omFhAWFiAg==" }];
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, attestations: both }), ["/attestations/0"]);
});

test("B6: an attestation with neither path nor bytesBase64 is rejected", () => {
  const neither = [{ attestor: "custodian" }];
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, attestations: neither }), ["/attestations/0"]);
});

test("B6: bytesBase64 must be standard base64", () => {
  const bad = [{ attestor: "custodian", bytesBase64: "not base64!" }];
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, attestations: bad }), [
    "/attestations/0/bytesBase64",
  ]);
});

// ---------------------------------------------------------------------------
// Debugger (T6.0 Debugger Brief). Regression guards first, then defects that
// are expected to FAIL until the Coder applies the fix spec in §12 of
// "T6 - Provider Onboarding Console".
// ---------------------------------------------------------------------------

test("A6: __proto__/constructor/prototype keys are rejected and pollute nothing", () => {
  const text = JSON.stringify(GOLD_LOT_001);
  for (const key of ["__proto__", "constructor", "prototype"]) {
    const input = JSON.parse(
      text.slice(0, -1) + `,"${key}":{"polluted":1,"prototype":{"polluted":1}}}`,
    );
    assert.deepEqual(issuesOf(input), [`/${key}`]);
  }
  const nested = JSON.parse(
    text.replace('"valuationBasis":{', '"valuationBasis":{"__proto__":{"polluted":1},'),
  );
  assert.deepEqual(issuesOf(nested), ["/valuationBasis/__proto__"]);
  assert.equal(({} as Record<string, unknown>).polluted, undefined);
});

test("E4: a rejected key-shaped field never has its value echoed", () => {
  const secret = "0x" + "ab".repeat(32);
  for (const field of ["privateKey", "mnemonic", "agentKey"]) {
    const r = validateOnboardingInput({ ...GOLD_LOT_001, [field]: secret });
    assert.equal(r.ok, false);
    if (!r.ok)
      assert.ok(r.issues.every((i) => !i.message.includes(secret) && !i.path.includes(secret)));
  }
});

test("B10 (defect): amounts above uint256 max are rejected", () => {
  const max = (2n ** 256n - 1n).toString();
  assert.equal(validateOnboardingInput({ ...GOLD_LOT_001, intendedSupply: max }).ok, true);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, intendedSupply: (2n ** 256n).toString() }), [
    "/intendedSupply",
  ]);
  const vb = { ...GOLD_LOT_001.valuationBasis, unitValue: "9".repeat(100) };
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, valuationBasis: vb }), [
    "/valuationBasis/unitValue",
  ]);
});

test("B13 (defect): a valuationTs far in the future is rejected", () => {
  const vb = { ...GOLD_LOT_001.valuationBasis, valuationTs: 4102444800 }; // 2100-01-01
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, valuationBasis: vb }), [
    "/valuationBasis/valuationTs",
  ]);
});

test("B15 (defect): the zero address is rejected as providerWallet and token", () => {
  const zero = "0x" + "0".repeat(40);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, providerWallet: zero }), ["/providerWallet"]);
  assert.deepEqual(issuesOf({ ...GOLD_LOT_001, token: zero }), ["/token"]);
});

test("C4 (defect): an attestation path must be relative and stay inside contracts/", () => {
  for (const path of [
    "../../../etc/passwd",
    "script/../../x",
    "/etc/passwd",
    "C:\\keys",
    "\\\\srv\\share\\x",
  ]) {
    const atts = [{ attestor: "custodian" as const, path }];
    assert.deepEqual(
      issuesOf({ ...GOLD_LOT_001, attestations: atts }),
      ["/attestations/0/path"],
      path,
    );
  }
});

// ---------------------------------------------------------------------------
// Round 2 ("T6.0 - Researcher Answers (round 2)"): Q1-Q7, fineness, hash fields.
// ---------------------------------------------------------------------------

test("Q1: valuationTs after `now` is rejected; exactly `now` is accepted", () => {
  const at = (valuationTs: number) => ({
    ...GOLD_LOT_001,
    valuationBasis: { ...GOLD_LOT_001.valuationBasis, valuationTs },
  });
  assert.equal(validateOnboardingInput(at(NOW), { now: NOW }).ok, true);
  assert.deepEqual(issuesOf(at(NOW + 1)), ["/valuationBasis/valuationTs"]);
});

test("Q2: the uint256 ceiling is exact for every amount field", () => {
  const max = (2n ** 256n - 1n).toString();
  const over = (2n ** 256n).toString();
  assert.equal(max.length, MAX_UINT256_DIGITS);
  for (const field of ["intendedSupply", "grossWeight"] as const) {
    assert.equal(validateOnboardingInput({ ...GOLD_LOT_001, [field]: max }, { now: NOW }).ok, true);
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, [field]: over }), [`/${field}`]);
  }
});

test("Q3: providerWallet equal to token (any case) is rejected", () => {
  const same = {
    ...GOLD_LOT_001,
    providerWallet: GOLD_LOT_001.token.toLowerCase() as `0x${string}`,
  };
  assert.deepEqual(issuesOf(same), ["/providerWallet"]);
});

test("Q4: assetId hyphens are single and inner; length is its own message", () => {
  for (const id of ["-gold", "gold-", "go--ld", "gоld"]) {
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, assetId: id }), ["/assetId"], id);
  }
  const long = validateOnboardingInput({ ...GOLD_LOT_001, assetId: "a".repeat(33) }, { now: NOW });
  assert.equal(long.ok, false);
  if (!long.ok) assert.match(long.issues[0].message, /at most 32/);
  assert.equal(
    validateOnboardingInput({ ...GOLD_LOT_001, assetId: "a".repeat(32) }, { now: NOW }).ok,
    true,
  );
});

test("Q6: invisible-only free text is rejected (ZWSP, NEL, NBSP, BOM)", () => {
  for (const ch of ["\u200B", "\u0085", "\u00A0", "\uFEFF"]) {
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, description: ch }), ["/description"], ch);
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, custodianId: ch }), ["/custodianId"], ch);
    const vb = { ...GOLD_LOT_001.valuationBasis, source: ch };
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, valuationBasis: vb }), ["/valuationBasis/source"]);
  }
});

test("Q6 trap 2: the visible-character pattern only works with the u flag", () => {
  const withU = new RegExp(PATTERNS.visible, "u");
  assert.equal(withU.test("\u200B"), false);
  assert.equal(withU.test("a"), true);
});

test("Q7: a missing field's path points at the field itself", () => {
  const { description: _d, ...noDescription } = GOLD_LOT_001;
  assert.deepEqual(issuesOf(noDescription), ["/description"]);
  const noAttestor = { ...GOLD_LOT_001, attestations: [{ path: "script/a.cbor" }] };
  assert.deepEqual(issuesOf(noAttestor), ["/attestations/0/attestor"]);
});

test("fineness is an integer in parts per 10,000", () => {
  for (const fineness of [0, MAX_FINENESS + 1, 999.9, "9999"]) {
    assert.deepEqual(issuesOf({ ...GOLD_LOT_001, fineness }), ["/fineness"], String(fineness));
  }
});

test("fixture: intendedSupply == grossWeight x fineness / 10000 (ADR 0020, fine grams)", () => {
  const derived = (BigInt(GOLD_LOT_001.grossWeight) * BigInt(GOLD_LOT_001.fineness)) / 10000n;
  assert.equal(derived.toString(), GOLD_LOT_001.intendedSupply);
  assert.equal((BigInt(GOLD_LOT_001.grossWeight) * BigInt(GOLD_LOT_001.fineness)) % 10000n, 0n);
});

test("metadataHash fields: eight, in A2 order, each a schema property", () => {
  assert.equal(METADATA_HASH_FIELDS.length, 8);
  for (const pointer of METADATA_HASH_FIELDS) {
    let node = SCHEMA;
    for (const part of pointer.slice(1).split("/")) node = node.properties?.[part];
    assert.ok(node, `${pointer} is not a schema property`);
  }
});

test("the schema uses exactly the TS patterns and length caps", () => {
  const props = SCHEMA.properties;
  const vb = props.valuationBasis.properties;
  const att = props.attestations.items.properties;
  assert.equal(props.assetId.pattern, PATTERNS.assetId);
  assert.equal(props.assetId.maxLength, MAX_ASSET_ID_LENGTH);
  for (const node of [props.description, props.custodianId, vb.source]) {
    assert.equal(node.pattern, PATTERNS.visible);
  }
  assert.equal(vb.currency.pattern, PATTERNS.currency);
  assert.equal(props.fineness.maximum, MAX_FINENESS);
  assert.equal(att.path.pattern, PATTERNS.relativePath);
  assert.equal(att.bytesBase64.pattern, PATTERNS.base64);
  assert.equal(SCHEMA.$defs.address.pattern, PATTERNS.address);
  assert.equal(SCHEMA.$defs.address.not.pattern, PATTERNS.zeroAddress);
  assert.equal(SCHEMA.$defs.positiveUint256String.pattern, PATTERNS.positiveUint);
  assert.equal(SCHEMA.$defs.positiveUint256String.maxLength, MAX_UINT256_DIGITS);
});
