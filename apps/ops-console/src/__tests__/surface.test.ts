/**
 * AC-14 (with T6.1b point 7): the page can only register, submit an attestation, admit and
 * mint. No transfer, forced transfer, burn, recovery, freeze or pause call exists in its
 * source, and the owner's setTokenFor is only ever encoded as calldata.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { expect, it } from "vitest";

// vitest runs from apps/ops-console.
const SRC = join(process.cwd(), "src");
const files = (dir: string): string[] =>
  readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) return f === "__tests__" ? [] : files(p);
    return /\.(ts|tsx)$/.test(f) ? [p] : [];
  });

it("exposes register / submitAttestation / admit / mint only", () => {
  const src = files(SRC)
    .map((f) => readFileSync(f, "utf8"))
    .join("\n");
  const writes = [...src.matchAll(/write\([^,]+,\s*\w+,\s*"(\w+)"/g)].map((m) => m[1]);
  expect(new Set(writes)).toEqual(new Set(["register", "submitAttestation", "admit", "mint"]));
  for (const forbidden of [
    "transfer",
    "transferFrom",
    "batchTransfer",
    "forcedTransfer",
    "burn",
    "recoveryAddress",
    "setAddressFrozen",
    "freezePartialTokens",
    "freeze",
    "unfreeze",
    "pause",
    "unpause",
  ]) {
    expect(src).not.toMatch(new RegExp(`["'.]${forbidden}["'(]`));
  }
  expect(src).not.toMatch(/writeContract\([^)]*setTokenFor/);
});
