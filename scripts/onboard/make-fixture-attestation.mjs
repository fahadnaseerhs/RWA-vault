#!/usr/bin/env node
/**
 * Devnet fixture custodian (T6.1a spec §2.4):
 *   node scripts/onboard/make-fixture-attestation.mjs --asset <slug> --reserve <wei> --seq <n> --ts <unix|now|stale>
 *
 * Refuses unless the RPC is anvil (31337). Everything goes under contracts/.onboard/
 * (gitignored), so a rehearsal never changes tracked files: the ML-DSA-65 keypair in keys/
 * (generated once, then reused), the devnet custodian key and its hash
 * (custodian.mldsa65.pub, custodian.json; on anvil run.mjs prefers these to the committed
 * key in contracts/script/input/), and the envelope <slug>.seq<n>.att.json.
 * `now` and `stale` are read from the chain's latest block, not the wall clock.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { keccak256 } from "viem";
import { ANVIL_CHAIN_ID, REPO_ROOT, loadAddon, rpc, signFixtureAttestation } from "./lib.mjs";

/** How far back `--ts stale` dates the valuation: past the 24 h ADR 0018 window. */
export const STALE_AGE_SECONDS = 2 * 24 * 3600;

export async function makeFixture({
  contractsDir,
  addon,
  chainId,
  chainNow,
  asset,
  reserve,
  seq,
  ts,
}) {
  const outDir = resolve(contractsDir, ".onboard");
  const keyDir = resolve(outDir, "keys");
  mkdirSync(keyDir, { recursive: true });

  const pubPath = resolve(keyDir, "custodian.mldsa65.pub");
  const keyPath = resolve(keyDir, "custodian.mldsa65.key");
  if (!existsSync(keyPath)) {
    const kp = await addon.keygen("ml-dsa-65");
    writeFileSync(keyPath, kp.privateKey, { mode: 0o600 });
    writeFileSync(pubPath, kp.publicKey);
  }
  const pub = readFileSync(pubPath);
  writeFileSync(resolve(outDir, "custodian.mldsa65.pub"), pub);
  writeFileSync(
    resolve(outDir, "custodian.json"),
    JSON.stringify(
      {
        algorithm: "ML-DSA-65",
        custodianKeyHash: keccak256(pub),
        note: "DEVNET FIXTURE custodian key",
      },
      null,
      2,
    ) + "\n",
  );

  const valuationTs =
    ts === "now" ? chainNow : ts === "stale" ? chainNow - STALE_AGE_SECONDS : Number(ts);
  const att = await signFixtureAttestation({
    addon,
    privateKey: readFileSync(keyPath),
    chainId,
    assetRef: asset,
    reserve,
    seq: Number(seq),
    valuationTs,
  });
  const rel = `.onboard/${asset}.seq${seq}.att.json`;
  writeFileSync(resolve(contractsDir, rel), JSON.stringify(att, null, 2) + "\n");
  return { path: rel, valuationTs };
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) out[argv[i].replace(/^--/, "")] = argv[i + 1];
  for (const k of ["asset", "reserve", "seq", "ts"]) {
    if (out[k] === undefined) throw new Error(`missing --${k}`);
  }
  return out;
}

async function cli() {
  const a = parseArgs(process.argv.slice(2));
  const rpcUrl = process.env.M3_RPC_URL ?? "http://127.0.0.1:8545";
  const chainId = Number(await rpc(rpcUrl, "eth_chainId"));
  if (chainId !== ANVIL_CHAIN_ID) {
    console.error(
      `FixtureAttestationDevnetOnly: chain ${chainId} is not anvil (${ANVIL_CHAIN_ID}).`,
    );
    return 1;
  }
  const block = await rpc(rpcUrl, "eth_getBlockByNumber", ["latest", false]);
  const { path, valuationTs } = await makeFixture({
    contractsDir: resolve(process.env.ONBOARD_CONTRACTS_DIR ?? resolve(REPO_ROOT, "contracts")),
    addon: loadAddon(),
    chainId,
    chainNow: Number(block.timestamp),
    ...a,
  });
  console.log(`wrote contracts/${path} (seq ${a.seq}, valuationTs ${valuationTs})`);
  console.log(
    `use it in the input file as: "attestations": [{ "path": "${path}", "attestor": "custodian" }]`,
  );
  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exitCode = await cli();
}
