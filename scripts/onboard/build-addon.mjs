#!/usr/bin/env node
/** Builds the pq-core napi addon and copies it to packages/pq-core/pq-core.node (`pnpm pq:addon`). */
import { execFileSync } from "node:child_process";
import { copyFileSync } from "node:fs";
import { resolve } from "node:path";
import { REPO_ROOT, DEFAULT_ADDON } from "./lib.mjs";

const manifest = resolve(REPO_ROOT, "packages/pq-core/native/napi/Cargo.toml");
execFileSync("cargo", ["build", "--release", "--manifest-path", manifest], { stdio: "inherit" });
const lib =
  { darwin: "librwa_vault_pq_napi.dylib", win32: "rwa_vault_pq_napi.dll" }[process.platform] ??
  "librwa_vault_pq_napi.so";
copyFileSync(resolve(REPO_ROOT, "packages/pq-core/native/napi/target/release", lib), DEFAULT_ADDON);
console.log(`pq-core addon -> ${DEFAULT_ADDON}`);
