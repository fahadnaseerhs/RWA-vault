/**
 * S3-10 — Contract-equivalence test (AC-09).
 *
 * One Node test suite loads BOTH runtime adapters — the napi native addon and
 * the WASM build — and runs the same checks against each. Per decision Q02 the
 * suite runs in Node only; the WASM adapter is driven through its Node `init()`.
 *
 * Input vectors are the shared differential-oracle fixture
 * `native/tests/vectors/oracle-vectors.txt` (read in place, never copied). It
 * carries known-good signatures (falcon-padded-512, ml-dsa-44, ml-dsa-65) and
 * KEM known-answer tuples (ml-kem-768, ml-kem-1024). The oracle id
 * `falcon-padded-512` maps to the public union id `falcon-512`.
 *
 * For every algorithm in PQ_ALGORITHMS the suite checks: key lengths vs the
 * ADR 0006 metadata, cross-runtime verification, KEM shared-secret agreement,
 * and identical exact error codes for malformed input. Error assertions use
 * exact variants, never "did it throw" (repo rule 4.4).
 *
 * SLH-DSA is a DOCUMENTED SPLIT (decision Q03): the native addon rejects
 * `sign("slh-dsa-sha2-128s")` (S3-04 / ADR 0005) while the WASM build signs it.
 * This test pins that split — it does not make the two runtimes interoperable
 * for SLH-DSA signatures. See `Thread - T3 Runtime adapters.md`.
 */

import { describe, it, before } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  PQ_SIGNATURE_ALGORITHMS,
  PQ_KEM_ALGORITHMS,
  SIGNATURE_METADATA,
  KEM_METADATA,
  PqError,
  createNativeAdapter,
  createWasmAdapter,
} from "../index.js";
import type { PqCoreApi, PqErrorCode } from "../index.js";

// A fixed, non-trivial message for the live sign/verify checks.
const MESSAGE: Uint8Array = new TextEncoder().encode("rwa-vault pq-core S3-10 probe");

// Signature algorithms both adapters can sign. SLH-DSA is excluded: the native
// addon rejects it, so it takes the documented-split branch instead (Q03).
const SIGN_ON_BOTH: ReadonlySet<string> = new Set(["falcon-512", "ml-dsa-44", "ml-dsa-65"]);

// ---------------------------------------------------------------------------
// Oracle fixture (shared with the Rust tests — read in place, never copied).
// ---------------------------------------------------------------------------

const ORACLE_PATH = new URL("../../native/tests/vectors/oracle-vectors.txt", import.meta.url);

// Oracle vector id -> public union id, where they differ.
const ORACLE_ID_TO_UNION: Readonly<Record<string, string>> = { "falcon-padded-512": "falcon-512" };

function hexToBytes(hex: string): Uint8Array {
  return new Uint8Array(Buffer.from(hex, "hex"));
}

function loadOracle(): Map<string, Map<string, Uint8Array>> {
  const text = readFileSync(ORACLE_PATH, "utf8");
  const vectors = new Map<string, Map<string, Uint8Array>>();
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    const [rawId, ...segments] = line.split("|");
    const id = ORACLE_ID_TO_UNION[rawId] ?? rawId;
    const fields = new Map<string, Uint8Array>();
    for (const segment of segments) {
      const eq = segment.indexOf("=");
      if (eq === -1) continue;
      fields.set(segment.slice(0, eq), hexToBytes(segment.slice(eq + 1)));
    }
    vectors.set(id, fields);
  }
  return vectors;
}

const oracle = loadOracle();

function oracleField(id: string, key: string): Uint8Array {
  const entry = oracle.get(id);
  assert.ok(entry, `oracle-vectors.txt has no entry for ${id}`);
  const value = entry.get(key);
  assert.ok(value, `oracle entry ${id} is missing field "${key}"`);
  return value;
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/** Invoke a failing operation and return the exact PqError code it raised. */
async function errorCode(call: () => Promise<unknown>): Promise<PqErrorCode> {
  try {
    await call();
  } catch (err: unknown) {
    assert.ok(err instanceof PqError, `expected a PqError, received: ${String(err)}`);
    return err.code;
  }
  assert.fail("expected the operation to throw a PqError, but it resolved");
}

/** Both adapters must reject the same malformed input with the same exact code. */
async function expectSameCode(
  expected: PqErrorCode,
  nativeCall: () => Promise<unknown>,
  wasmCall: () => Promise<unknown>,
): Promise<void> {
  const nativeCode = await errorCode(nativeCall);
  const wasmCode = await errorCode(wasmCall);
  assert.equal(
    nativeCode,
    wasmCode,
    `adapters disagree on error code: native=${nativeCode}, wasm=${wasmCode}`,
  );
  assert.equal(nativeCode, expected, `expected ${expected}, got ${nativeCode}`);
}

describe("S3-10 contract equivalence (native vs wasm)", () => {
  let native: PqCoreApi;
  let wasm: PqCoreApi;

  before(async () => {
    native = createNativeAdapter();
    wasm = createWasmAdapter();
    await native.init();
    await wasm.init();
  });

  describe("signature algorithms", () => {
    for (const algorithm of PQ_SIGNATURE_ALGORITHMS) {
      it(`${algorithm}: metadata, key lengths, cross-verify, malformed codes`, async () => {
        const meta = SIGNATURE_METADATA[algorithm];

        // Both adapters expose the identical canonical metadata.
        assert.deepStrictEqual(native.metadata(algorithm), meta);
        assert.deepStrictEqual(wasm.metadata(algorithm), meta);

        // keygen on each adapter yields keys of the metadata lengths.
        for (const kp of [await native.keygen(algorithm), await wasm.keygen(algorithm)]) {
          assert.equal(kp.publicKey.length, meta.publicKeyBytes);
          assert.equal(kp.privateKey.length, meta.privateKeyBytes);
        }

        if (SIGN_ON_BOTH.has(algorithm)) {
          // The oracle's known-good signature verifies in BOTH runtimes.
          const pk = oracleField(algorithm, "pk");
          const msg = oracleField(algorithm, "msg");
          const sig = oracleField(algorithm, "sig");
          assert.equal(await native.verify(algorithm, pk, msg, sig), true);
          assert.equal(await wasm.verify(algorithm, pk, msg, sig), true);

          // Live cross-sign / cross-verify in both directions over one keypair.
          const kp = await native.keygen(algorithm);
          const sigNative = await native.sign(algorithm, kp.privateKey, MESSAGE);
          const sigWasm = await wasm.sign(algorithm, kp.privateKey, MESSAGE);
          assert.equal(sigNative.length, meta.signatureBytes);
          assert.equal(sigWasm.length, meta.signatureBytes);
          assert.equal(await wasm.verify(algorithm, kp.publicKey, MESSAGE, sigNative), true);
          assert.equal(await native.verify(algorithm, kp.publicKey, MESSAGE, sigWasm), true);

          const tampered = Uint8Array.from(MESSAGE);
          tampered[0] ^= 0xff;
          assert.equal(await native.verify(algorithm, kp.publicKey, tampered, sigNative), false);
          assert.equal(await wasm.verify(algorithm, kp.publicKey, tampered, sigWasm), false);

          // Malformed input → identical exact error code from both adapters.
          const shortPrivateKey = kp.privateKey.slice(0, -1);
          await expectSameCode(
            "MALFORMED_KEY",
            () => native.sign(algorithm, shortPrivateKey, MESSAGE),
            () => wasm.sign(algorithm, shortPrivateKey, MESSAGE),
          );
          const shortPublicKey = kp.publicKey.slice(0, -1);
          await expectSameCode(
            "MALFORMED_KEY",
            () => native.verify(algorithm, shortPublicKey, MESSAGE, sigNative),
            () => wasm.verify(algorithm, shortPublicKey, MESSAGE, sigNative),
          );
          const shortSignature = sigNative.slice(0, -1);
          await expectSameCode(
            "MALFORMED_SIGNATURE",
            () => native.verify(algorithm, kp.publicKey, MESSAGE, shortSignature),
            () => wasm.verify(algorithm, kp.publicKey, MESSAGE, shortSignature),
          );
        } else {
          // SLH-DSA documented split (Q03): native rejects sign, wasm signs.
          const kp = await wasm.keygen(algorithm);

          // Native rejects signing. As-built, the addon raises a raw napi error
          // that bypasses the `[CODE]` envelope, so the TS adapter surfaces
          // INTERNAL_ERROR (not UNSUPPORTED_ALGORITHM). This pins current behaviour.
          const nativeSignCode = await errorCode(() =>
            native.sign(algorithm, kp.privateKey, MESSAGE),
          );
          assert.equal(nativeSignCode, "INTERNAL_ERROR");

          // WASM signs; that signature verifies in both runtimes (wasm→native only —
          // native cannot produce an SLH-DSA signature for the reverse direction).
          const sigWasm = await wasm.sign(algorithm, kp.privateKey, MESSAGE);
          assert.equal(sigWasm.length, meta.signatureBytes);
          assert.equal(await wasm.verify(algorithm, kp.publicKey, MESSAGE, sigWasm), true);
          assert.equal(await native.verify(algorithm, kp.publicKey, MESSAGE, sigWasm), true);

          const tampered = Uint8Array.from(MESSAGE);
          tampered[0] ^= 0xff;
          assert.equal(await wasm.verify(algorithm, kp.publicKey, tampered, sigWasm), false);
          assert.equal(await native.verify(algorithm, kp.publicKey, tampered, sigWasm), false);

          // Malformed verify input → identical exact error code from both adapters.
          const shortPublicKey = kp.publicKey.slice(0, -1);
          await expectSameCode(
            "MALFORMED_KEY",
            () => native.verify(algorithm, shortPublicKey, MESSAGE, sigWasm),
            () => wasm.verify(algorithm, shortPublicKey, MESSAGE, sigWasm),
          );
          const shortSignature = sigWasm.slice(0, -1);
          await expectSameCode(
            "MALFORMED_SIGNATURE",
            () => native.verify(algorithm, kp.publicKey, MESSAGE, shortSignature),
            () => wasm.verify(algorithm, kp.publicKey, MESSAGE, shortSignature),
          );
        }
      });
    }
  });

  describe("KEM algorithms", () => {
    for (const algorithm of PQ_KEM_ALGORITHMS) {
      it(`${algorithm}: metadata, key lengths, shared secret, malformed codes`, async () => {
        const meta = KEM_METADATA[algorithm];

        assert.deepStrictEqual(native.kemMetadata(algorithm), meta);
        assert.deepStrictEqual(wasm.kemMetadata(algorithm), meta);

        for (const kp of [await native.kemKeygen(algorithm), await wasm.kemKeygen(algorithm)]) {
          assert.equal(kp.publicKey.length, meta.publicKeyBytes);
          assert.equal(kp.privateKey.length, meta.privateKeyBytes);
        }

        // Oracle known-answer decapsulation agrees in BOTH runtimes.
        const oracleSk = oracleField(algorithm, "sk");
        const oracleCt = oracleField(algorithm, "ct");
        const oracleSs = oracleField(algorithm, "ss");
        assert.deepStrictEqual(Uint8Array.from(await native.decapsulate(algorithm, oracleSk, oracleCt)), oracleSs);
        assert.deepStrictEqual(Uint8Array.from(await wasm.decapsulate(algorithm, oracleSk, oracleCt)), oracleSs);

        // Live cross encaps/decaps both directions share the same secret.
        const kp = await native.kemKeygen(algorithm);

        const encNative = await native.encapsulate(algorithm, kp.publicKey);
        assert.equal(encNative.ciphertext.length, meta.ciphertextBytes);
        assert.equal(encNative.sharedSecret.length, meta.sharedSecretBytes);
        const ssFromWasm = await wasm.decapsulate(algorithm, kp.privateKey, encNative.ciphertext);
        assert.deepStrictEqual(Uint8Array.from(ssFromWasm), Uint8Array.from(encNative.sharedSecret));

        const encWasm = await wasm.encapsulate(algorithm, kp.publicKey);
        assert.equal(encWasm.ciphertext.length, meta.ciphertextBytes);
        assert.equal(encWasm.sharedSecret.length, meta.sharedSecretBytes);
        const ssFromNative = await native.decapsulate(algorithm, kp.privateKey, encWasm.ciphertext);
        assert.deepStrictEqual(Uint8Array.from(ssFromNative), Uint8Array.from(encWasm.sharedSecret));

        // Malformed input → identical exact error code from both adapters.
        const shortPublicKey = kp.publicKey.slice(0, -1);
        await expectSameCode(
          "MALFORMED_KEY",
          () => native.encapsulate(algorithm, shortPublicKey),
          () => wasm.encapsulate(algorithm, shortPublicKey),
        );
        const shortCiphertext = encNative.ciphertext.slice(0, -1);
        await expectSameCode(
          "MALFORMED_CIPHERTEXT",
          () => native.decapsulate(algorithm, kp.privateKey, shortCiphertext),
          () => wasm.decapsulate(algorithm, kp.privateKey, shortCiphertext),
        );
        const shortPrivateKey = kp.privateKey.slice(0, -1);
        await expectSameCode(
          "MALFORMED_KEY",
          () => native.decapsulate(algorithm, shortPrivateKey, encNative.ciphertext),
          () => wasm.decapsulate(algorithm, shortPrivateKey, encNative.ciphertext),
        );
      });
    }
  });
});
