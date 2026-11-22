#!/usr/bin/env node
/**
 * Builds pq-core's WASM package into packages/pq-core/pkg/ for the ops-console's in-browser
 * clause 1 (`pnpm pq:wasm`; needs wasm-pack 0.13.1, the wasm32-unknown-unknown target and
 * clang). When wasm-pack cannot fetch wasm-opt (binaryen) it stops after writing an
 * unoptimised package; that package is complete, so this script accepts it with a note.
 */
import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { REPO_ROOT } from "./lib.mjs";

const pq = resolve(REPO_ROOT, "packages/pq-core");
const wasm = resolve(pq, "pkg/rwa_vault_pq_core_bg.wasm");
const started = Date.now();
const r = spawnSync(
  "wasm-pack",
  ["build", "native", "--target", "web", "--out-dir", "../pkg", "--release", "--locked"],
  {
    cwd: pq,
    stdio: "inherit",
    env: {
      ...process.env,
      WASM32_UNKNOWN_UNKNOWN_CLANG: process.env.WASM32_UNKNOWN_UNKNOWN_CLANG ?? "clang",
      RUSTFLAGS: "-C link-arg=--error-unresolved-symbols",
    },
  },
);
if (r.status !== 0) {
  if (existsSync(wasm) && statSync(wasm).mtimeMs >= started) {
    console.warn(
      "wasm-opt was unavailable; using the unoptimised package in packages/pq-core/pkg/.",
    );
  } else {
    process.exit(r.status ?? 1);
  }
}
