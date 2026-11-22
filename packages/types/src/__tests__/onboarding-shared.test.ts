/**
 * T6.1b points 2 and 6: the shared metadataHash and envelope recipes, and the shared
 * sentence table, held to the vectors the forge suite also asserts.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  BAD_ATTESTATION_SIG_SENTENCE,
  MalformedAttestationError,
  durationText,
  metadataHash,
  parseFixtureAttestation,
  reserveTooLowSentence,
  staleSequenceSentence,
  valuationInFutureSentence,
  valuationStaleSentence,
} from "../index.js";
import { GOLD_LOT_001, GOLD_LOT_001_METADATA_HASH } from "./fixtures.js";

interface Vector {
  kind: string;
  a: string;
  b: string;
  now: string;
  sentence: string;
}

const vectors = JSON.parse(
  readFileSync(new URL("../../fixtures/onboarding-sentences.json", import.meta.url), "utf8"),
) as Vector[];

function sentenceFor(v: Vector): string {
  const a = BigInt(v.a);
  const b = BigInt(v.b);
  switch (v.kind) {
    case "StaleSequence":
      return staleSequenceSentence(a, b);
    case "ReserveTooLow":
      return reserveTooLowSentence(a, b);
    case "ValuationStale":
      return valuationStaleSentence(a, b, BigInt(v.now));
    case "ValuationInFuture":
      return valuationInFutureSentence(a, b);
    default:
      throw new Error(`unknown vector kind ${v.kind}`);
  }
}

test("every shared sentence vector matches the TS sentence table", () => {
  assert.ok(vectors.length >= 5);
  for (const v of vectors) assert.equal(sentenceFor(v), v.sentence, v.kind);
});

test("durationText", () => {
  assert.equal(durationText(86400), "24 hours");
  assert.equal(durationText(90), "90 seconds");
  assert.equal(durationText(0), "0 seconds");
});

test("the bad-signature sentence is the T6 §3.4 text", () => {
  assert.equal(
    BAD_ATTESTATION_SIG_SENTENCE,
    "The custodian's signature on this attestation is not valid for the registered custodian key.",
  );
});

test("metadataHash reproduces GOLD_LOT_001_METADATA_HASH", () => {
  assert.equal(metadataHash(GOLD_LOT_001), GOLD_LOT_001_METADATA_HASH);
});

test("parseFixtureAttestation rejects a key carried in the envelope", () => {
  const env = {
    format: "rwa-vault/ms1-fixture-attestation@0",
    algorithm: "ML-DSA-65",
    chainId: 31337,
    assetRef: "gold-lot-002",
    reserve: "1",
    seq: 1,
    valuationTs: 1,
    signature: "AAAA",
  };
  const enc = (o: unknown) => new TextEncoder().encode(JSON.stringify(o));
  assert.equal(parseFixtureAttestation(enc(env)).assetRef, "gold-lot-002");
  assert.throws(
    () => parseFixtureAttestation(enc({ ...env, publicKey: "AAAA" })),
    (e: unknown) => e instanceof MalformedAttestationError && /publicKey/.test(e.message),
  );
});
