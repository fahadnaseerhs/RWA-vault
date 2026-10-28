#!/usr/bin/env node
/**
 * `pnpm m3:onboard <input.json> [--broadcast]` (T6.1a spec §1).
 *
 * Stage 1 (here): validate the input with the T6.0 validator, verify the custodian's
 * ML-DSA-65 signature (clause 1, ADR 0027) and write `.onboard/<slug>.verified.json`.
 * Stage 2: `forge script script/OnboardAsset.s.sol`, with no --ffi. Without --broadcast
 * the whole run is a dry run. Keys come only from M3_AGENT_PK / M3_OWNER_PK.
 *
 * Exit codes: 0 done, 1 bad input, 2 waiting for the owner multisig, 3 attestation
 * rejected, 4 stage 2 stopped (forge's named error is printed above it). forge itself
 * exits 0 when a script reverts, so success is read from the ONBOARD_STATUS line.
 */
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { validateOnboardingInput } from "@rwa-vault/types";
import {
  EXIT,
  OnboardError,
  REPO_ROOT,
  loadAddon,
  readCustodianKey,
  rpc,
  verifyAttestation,
} from "./lib.mjs";

export async function main(argv, env = process.env) {
  const args = argv.filter((a) => !a.startsWith("--"));
  const broadcast = argv.includes("--broadcast");
  if (args.length !== 1) {
    console.error("usage: pnpm m3:onboard <input.json> [--broadcast]");
    return EXIT.INPUT;
  }
  const contractsDir = resolve(env.ONBOARD_CONTRACTS_DIR ?? resolve(REPO_ROOT, "contracts"));
  const rpcUrl = env.M3_RPC_URL ?? "http://127.0.0.1:8545";

  try {
    // 2.1 validate
    const raw = readFileSync(resolve(env.INIT_CWD ?? process.cwd(), args[0]), "utf8");
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      throw new OnboardError(
        "InvalidJson",
        EXIT.INPUT,
        `${args[0]} is not valid JSON (${e.message})`,
      );
    }
    const result = validateOnboardingInput(parsed);
    if (!result.ok) {
      for (const i of result.issues) console.error(`${i.path || "/"}: ${i.message}`);
      return EXIT.INPUT;
    }
    const input = result.value;

    // 2.3 clause 1, against the chain the RPC serves
    const chainId = Number(await rpc(rpcUrl, "eth_chainId"));
    const att = input.attestations[0];
    const attBytes = att.path
      ? readFileSync(resolve(contractsDir, att.path))
      : Buffer.from(att.bytesBase64, "base64");
    const verified = await verifyAttestation({
      attBytes,
      publicKey: readCustodianKey(resolve(contractsDir, "script/input")),
      chainId,
      inputAssetRef: input.assetId,
      addon: loadAddon(env.PQ_CORE_ADDON),
    });
    console.log(`clause 1: custodian signature valid (${verified.verifier}), seq ${verified.seq}`);

    const outDir = resolve(contractsDir, ".onboard");
    mkdirSync(outDir, { recursive: true });
    const verifiedPath = resolve(outDir, `${input.assetId}.verified.json`);
    const inputPath = resolve(outDir, `${input.assetId}.input.json`);
    writeFileSync(verifiedPath, JSON.stringify(verified, null, 2) + "\n");
    writeFileSync(inputPath, raw); // forge reads exactly the bytes that were validated

    // Stage 2
    const forgeArgs = ["script", "script/OnboardAsset.s.sol", "--rpc-url", rpcUrl];
    if (broadcast) forgeArgs.push("--broadcast");
    else console.log("DRY RUN: nothing is sent. Add --broadcast to send.");
    const startedAt = Date.now();
    const { code, stdout } = await runForge(env.ONBOARD_FORGE_BIN ?? "forge", forgeArgs, {
      cwd: contractsDir,
      env: { ...env, ONBOARD_INPUT: inputPath, ONBOARD_VERIFIED: verifiedPath },
    });
    const status = /ONBOARD_STATUS=(\w+)/.exec(stdout)?.[1];
    if (code !== 0 || !status) {
      console.error("Onboarding stopped; the named error above says why. Nothing was sent.");
      return EXIT.SCRIPT_FAILED;
    }
    if (broadcast) printTxHashes(contractsDir, chainId, startedAt);
    if (status === "WAITING_FOR_OWNER") return EXIT.WAITING_FOR_OWNER;
    return 0;
  } catch (e) {
    if (e instanceof OnboardError) {
      console.error(e.message);
      return e.exitCode;
    }
    throw e;
  }
}

function runForge(bin, args, opts) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(bin, args, { ...opts, stdio: ["ignore", "pipe", "inherit"] });
    let stdout = "";
    child.stdout.on("data", (b) => {
      stdout += b;
      process.stdout.write(b);
    });
    child.on("error", reject);
    child.on("close", (code) => resolveRun({ code: code ?? 1, stdout }));
  });
}

/** Prints this run's transaction hashes; forge leaves the previous file in place when nothing is sent. */
function printTxHashes(contractsDir, chainId, startedAt) {
  const p = resolve(
    contractsDir,
    "broadcast/OnboardAsset.s.sol",
    String(chainId),
    "run-latest.json",
  );
  const run =
    existsSync(p) && statSync(p).mtimeMs >= startedAt ? JSON.parse(readFileSync(p, "utf8")) : {};
  if (!run.transactions?.length) {
    console.log("transactions: none sent by this run");
    return;
  }
  console.log("transactions:");
  for (const tx of run.transactions ?? [])
    console.log(`  ${tx.hash}  ${tx.function ?? tx.transactionType}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exitCode = await main(process.argv.slice(2));
}
