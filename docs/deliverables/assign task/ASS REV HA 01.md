# ASS REV HA 01: Review of S3-10 and S3-13 for Hassan Attique

Reviewer: Claude, for the Researcher (Fahad Naseer)
Date: 26 November 2026
Branch reviewed: `feat/m1-s3-10-s3-13`
Deadline: Tuesday 24 November 2026, midnight (already passed). Please post the fixes as soon as possible.

## 1. Summary

The contract test covers the four checks in AC-09 and follows the repository rules. It cannot run yet, for three reasons. The build fails, the native adapter cannot load in Node, and the WASM adapter cannot load in Node. Fix these three items, then post the output of the build and the test in the thread.

## 2. Fixes Required

| # | Area | File and line | Problem | Required fix |
|---|---|---|---|---|
| 1 | Build | `packages/pq-core/package.json` | `pnpm build` fails with `Cannot find name 'Buffer'` in `src/native.ts`. `@types/node` is not a devDependency. | Add `@types/node` as a devDependency, then run `pnpm build` until it exits 0. (AC-12) |
| 2 | Native adapter | `packages/pq-core/src/native.ts` line 78 | `require("../pq-core.node")` is called in a package set to ES modules, where `require` does not exist. | Replace it with `createRequire(import.meta.url)` from `node:module`. Reopen S3-08. |
| 3 | WASM adapter | `packages/pq-core/src/wasm.ts`, the `init()` function | The web-target `init()` fetches the `.wasm` file by URL. Node's `fetch` cannot read a local file. | Read `pkg/rwa_vault_pq_core_bg.wasm` from disk and pass the bytes to the initialiser. Reopen S3-09. |

## 3. Steps

1. Continue on the existing branch `feat/m1-s3-10-s3-13`. Do not create a new branch. Open the pull request into `feat/finance-modules`.
2. Make fixes 1 to 3, one commit each. Use the message format `fix(m1): ...`.
3. Run `pnpm build`, then `pnpm test`. Paste the full output into the thread. The test must exit 0, with 0 skipped tests. (AC-10)
4. Only after step 3, tick S3-10 and S3-13 in the T3 note.
5. Post a HANDOFF entry in the thread, using the message format in `RWA Vault/Agents/Protocol.md`.

## 4. Rules

- Do not change the acceptance criteria. AC-04 and AC-09 will be updated by the Researcher to match Q03. Raise any doubt as an `ASK` entry.
- Do not edit earlier thread entries. Add a new entry at the bottom.
- Do not merge your own pull request. Fahad merges after two approvals.
- Reopen S3-08 and S3-09 in the task note, because they were marked done but do not run in Node.

## 5. Next Step

Post the HANDOFF with the output. The Researcher will then run AC-01 to AC-13 and record the result.
