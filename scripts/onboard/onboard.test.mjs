/**
 * T6.1a spec §4, Node side: clause 1 and the envelope checks, the shared metadataHash
 * golden vector, and the dry run. Run with `pnpm test:onboard` (needs `pnpm pq:addon`).
 */
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { chmodSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import {
  GOLD_LOT_001,
  GOLD_LOT_001_METADATA_HASH,
} from "../../packages/types/dist/__tests__/fixtures.js";
import {
  BAD_SIGNATURE_SENTENCE,
  REPO_ROOT,
  loadAddon,
  metadataHash,
  signFixtureAttestation,
} from "./lib.mjs";
import { makeFixture } from "./make-fixture-attestation.mjs";

const RUN = resolve(REPO_ROOT, "scripts/onboard/run.mjs");
const NOW = Math.floor(Date.now() / 1000);
const addon = loadAddon();

let server;
let rpcUrl;
let rpcMethods = [];
let chainIdHex = "0x7a69"; // 31337

before(async () => {
  server = createServer((req, res) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      const { id, method } = JSON.parse(body);
      rpcMethods.push(method);
      res.setHeader("content-type", "application/json");
      res.end(
        JSON.stringify({
          jsonrpc: "2.0",
          id,
          result: method === "eth_chainId" ? chainIdHex : null,
        }),
      );
    });
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  rpcUrl = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

/** A temp contracts/ dir with a fixture custodian key and a valid seq-1 envelope. */
async function workspace(slug = "gold-lot-002") {
  const dir = mkdtempSync(resolve(tmpdir(), "onboard-"));
  const { path } = await makeFixture({
    contractsDir: dir,
    addon,
    chainId: 31337,
    chainNow: NOW,
    asset: slug,
    reserve: "999900000000000000000",
    seq: 1,
    ts: "now",
  });
  // A forge stand-in that records how it was called.
  const forge = resolve(dir, "fake-forge.mjs");
  writeFileSync(
    forge,
    `#!/usr/bin/env node\nimport { writeFileSync } from "node:fs";\n` +
      `writeFileSync(${JSON.stringify(resolve(dir, "forge-call.json"))}, JSON.stringify({ argv: process.argv.slice(2), input: process.env.ONBOARD_INPUT, verified: process.env.ONBOARD_VERIFIED }));\n` +
      `if (process.env.FAKE_FORGE_STATUS) console.log("ONBOARD_STATUS=" + process.env.FAKE_FORGE_STATUS);\n` +
      `else console.error("Error: script failed: ProviderNotVerified(0x00)");\n`,
  );
  chmodSync(forge, 0o755);
  const input = {
    ...GOLD_LOT_001,
    assetId: slug,
    valuationBasis: { ...GOLD_LOT_001.valuationBasis, valuationTs: NOW - 60 },
    attestations: [{ path, attestor: "custodian" }],
  };
  const inputPath = resolve(dir, "input.json");
  writeFileSync(inputPath, JSON.stringify(input));
  return { dir, attPath: resolve(dir, path), inputPath, forge };
}

/** @param forgeStatus the ONBOARD_STATUS the stand-in forge prints; null = the script reverted */
function onboard(ws, extraArgs = [], forgeStatus = "MINTED") {
  return new Promise((r) => {
    execFile(
      process.execPath,
      [RUN, ws.inputPath, ...extraArgs],
      {
        env: {
          ...process.env,
          ONBOARD_CONTRACTS_DIR: ws.dir,
          M3_RPC_URL: rpcUrl,
          ONBOARD_FORGE_BIN: ws.forge,
          FAKE_FORGE_STATUS: forgeStatus ?? "",
        },
      },
      (err, stdout, stderr) => r({ code: err ? err.code : 0, stdout, stderr }),
    );
  });
}

function editEnvelope(ws, edit) {
  const att = JSON.parse(readFileSync(ws.attPath, "utf8"));
  writeFileSync(ws.attPath, JSON.stringify(edit(att)));
}

test("test_OnboardRejectsBadAttestationSig", async () => {
  const ws = await workspace();
  editEnvelope(ws, (a) => ({ ...a, reserve: "999999000000000000000000" })); // tampered after signing
  const r = await onboard(ws);
  assert.equal(r.code, 3);
  assert.match(r.stderr, /BadAttestationSig/);
  assert.ok(r.stderr.includes(BAD_SIGNATURE_SENTENCE), r.stderr);
  rmSync(ws.dir, { recursive: true });
});

test("test_RejectsEnvelopeWithForeignKey", async () => {
  const ws = await workspace();
  const attacker = await addon.keygen("ml-dsa-65");
  const forged = await signFixtureAttestation({
    addon,
    privateKey: attacker.privateKey,
    chainId: 31337,
    assetRef: "gold-lot-002",
    reserve: "999900000000000000000",
    seq: 2,
    valuationTs: NOW,
  });

  // Signed by a key that is not the registered custodian's.
  writeFileSync(ws.attPath, JSON.stringify(forged));
  let r = await onboard(ws);
  assert.equal(r.code, 3);
  assert.ok(r.stderr.includes(BAD_SIGNATURE_SENTENCE), r.stderr);

  // Carrying its own key does not help: the key is never read from the envelope.
  writeFileSync(
    ws.attPath,
    JSON.stringify({ ...forged, publicKey: Buffer.from(attacker.publicKey).toString("base64") }),
  );
  r = await onboard(ws);
  assert.equal(r.code, 3);
  assert.match(r.stderr, /MalformedAttestation: unknown field "publicKey"/);
  rmSync(ws.dir, { recursive: true });
});

test("test_RejectsEnvelopeForOtherChain", async () => {
  const ws = await workspace();
  chainIdHex = "0x66eee"; // 421614
  try {
    const r = await onboard(ws);
    assert.equal(r.code, 3);
    assert.match(r.stderr, /AttestationForOtherChain\(421614, 31337\)/);
  } finally {
    chainIdHex = "0x7a69";
    rmSync(ws.dir, { recursive: true });
  }
});

test("test_RejectsEnvelopeForOtherAsset", async () => {
  const ws = await workspace();
  const input = JSON.parse(readFileSync(ws.inputPath, "utf8"));
  writeFileSync(ws.inputPath, JSON.stringify({ ...input, assetId: "gold-lot-777" }));
  const r = await onboard(ws);
  assert.equal(r.code, 3);
  assert.match(r.stderr, /AttestationForOtherAsset\(gold-lot-777, gold-lot-002\)/);
  rmSync(ws.dir, { recursive: true });
});

test("test_RejectsCustodianKeyNotMatchingItsHash", async () => {
  const ws = await workspace();
  const other = await addon.keygen("ml-dsa-65");
  writeFileSync(resolve(ws.dir, ".onboard/custodian.mldsa65.pub"), other.publicKey);
  const r = await onboard(ws);
  assert.equal(r.code, 3);
  assert.match(r.stderr, /CustodianKeyMismatch/);
  rmSync(ws.dir, { recursive: true });
});

test("test_InvalidInputListsEveryIssue", async () => {
  const ws = await workspace();
  const input = JSON.parse(readFileSync(ws.inputPath, "utf8"));
  writeFileSync(ws.inputPath, JSON.stringify({ ...input, fineness: 0, privateKey: "0xabc" }));
  const r = await onboard(ws);
  assert.equal(r.code, 1);
  assert.match(r.stderr, /\/fineness: must be an integer/);
  assert.match(r.stderr, /\/privateKey: unknown field/);
  rmSync(ws.dir, { recursive: true });
});

test("test_MetadataHashGoldenVectorTs", () => {
  assert.equal(metadataHash(GOLD_LOT_001), GOLD_LOT_001_METADATA_HASH);
});

test("test_DryRunSendsNothing", async () => {
  const ws = await workspace();
  rpcMethods = [];
  const r = await onboard(ws);
  assert.equal(r.code, 0, r.stderr);
  assert.match(r.stdout, /DRY RUN: nothing is sent/);
  const call = JSON.parse(readFileSync(resolve(ws.dir, "forge-call.json"), "utf8"));
  assert.ok(!call.argv.includes("--broadcast"), "forge must not get --broadcast");
  assert.ok(!call.argv.includes("--ffi"), "forge must never get --ffi");
  assert.deepEqual(rpcMethods, ["eth_chainId"]);

  const v = JSON.parse(readFileSync(call.verified, "utf8"));
  assert.equal(v.seq, 1);
  assert.equal(v.reserve, "999900000000000000000");
  assert.match(v.envelopeHash, /^0x[0-9a-f]{64}$/);
  assert.match(v.verifier, /^pq-core ml-dsa-65 /);
  rmSync(ws.dir, { recursive: true });
});

test("test_BroadcastIsPassedThrough", async () => {
  const ws = await workspace();
  const r = await onboard(ws, ["--broadcast"]);
  assert.equal(r.code, 0, r.stderr);
  const call = JSON.parse(readFileSync(resolve(ws.dir, "forge-call.json"), "utf8"));
  assert.ok(call.argv.includes("--broadcast"));
  rmSync(ws.dir, { recursive: true });
});

test("test_RunExitsNonZeroOnScriptRevert", async () => {
  // forge exits 0 when a script reverts; the missing ONBOARD_STATUS line is what counts.
  const ws = await workspace();
  const r = await onboard(ws, ["--broadcast"], null);
  assert.equal(r.code, 4);
  assert.match(r.stderr, /Onboarding stopped/);
  rmSync(ws.dir, { recursive: true });
});

test("test_WaitingForOwnerExitsTwo", async () => {
  const ws = await workspace();
  const r = await onboard(ws, ["--broadcast"], "WAITING_FOR_OWNER");
  assert.equal(r.code, 2);
  rmSync(ws.dir, { recursive: true });
});

test("test_NoKeyMaterialCommitted", () => {
  // AC-T5-4, widened to contracts/.onboard/ (T6.1a ruling 9): nothing there is tracked, and
  // no tracked file under contracts/script holds a key. A 32-byte value is allowed only as
  // custodian.json's custodianKeyHash, which is a hash of the public key.
  const tracked = (dir) =>
    new Promise((r, j) =>
      execFile("git", ["ls-files", dir], { cwd: REPO_ROOT }, (e, out) =>
        e ? j(e) : r(out.split("\n").filter(Boolean)),
      ),
    );
  return Promise.all([tracked("contracts/.onboard"), tracked("contracts/script")]).then(
    ([onboard, script]) => {
      assert.deepEqual(onboard, []);
      for (const f of script) {
        const text = readFileSync(resolve(REPO_ROOT, f), "latin1");
        for (const line of text.split("\n")) {
          if (/"custodianKeyHash": "0x[0-9a-f]{64}"/.test(line)) continue;
          assert.ok(!/PRIVATE_KEY|0x[0-9a-f]{64}/.test(line), `${f}: ${line.slice(0, 80)}`);
        }
      }
    },
  );
});

test("test_FixtureKeyIsDevnetOnly", async () => {
  // Off anvil the devnet key in .onboard/ is ignored; only the committed key counts.
  const ws = await workspace();
  editEnvelope(ws, (a) => ({ ...a, chainId: 421614 }));
  chainIdHex = "0x66eee";
  try {
    const r = await onboard(ws);
    assert.equal(r.code, 3);
    assert.match(r.stderr, /CustodianKeyMissing: no custodian key at .*script\/input/);
  } finally {
    chainIdHex = "0x7a69";
    rmSync(ws.dir, { recursive: true });
  }
});

test("test_FixtureGeneratorLeavesTrackedFilesAlone", async () => {
  const ws = await workspace();
  assert.ok(!existsSync(resolve(ws.dir, "script/input")), "nothing written outside .onboard/");
  assert.match(ws.attPath, /\/\.onboard\/gold-lot-002\.seq1\.att\.json$/);
  rmSync(ws.dir, { recursive: true });
});
