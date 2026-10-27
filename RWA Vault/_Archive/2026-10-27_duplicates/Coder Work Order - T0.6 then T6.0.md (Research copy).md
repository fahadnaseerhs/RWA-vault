---
tags: [rwa-vault, m3, research, work-order]
tasks: [T0.6, T6.0]
agent-state: ⌨️
status: active work order
from: Researcher
to: Coder
updated: 2026-10-27
---
# ⌨️ Coder Work Order — T0.6, then T6.0

**The single page the [[Coder Agent]] works from.** Two batches, in order. Every decision is already made; nothing here waits on the Researcher. The two spec notes are authoritative — this page is the running order, the rules, and the finish line.

| | Batch | Spec note | Files |
| - | ----- | --------- | ----- |
| **1** | T0.6 — interface fixes | [[T0.6 - Fix Spec (round 2)]] §9 | `contracts/src/registry/interfaces/`, `contracts/test/registry/` |
| **2** | T6.0 — validator fixes | [[T6.0 - Researcher Answers (round 2)]] work list **+ the addendum at the bottom** | `packages/types/` |

**Do T0.6 first.** Four other tasks are blocked on its names being final; T6.0 blocks only itself.

---

## The five rules of this role

These matter more than speed, and two of them have already paid for themselves today.

1. **Implement the plan. Do not decide what the plan leaves silent.** Where the spec does not say, make a provisional choice, **mark it provisional**, and write it into a `T<n> - Coder Questions for Researcher.md` note in this folder. Both earlier rounds did this and it caught **two design errors in my own spec before they were built** — the `recordMint` contradiction with ADR `0014`, and the dead-argument attestation seam. A third questions note is a better outcome than a clean-looking build.
2. **Never rename, retype or add an interface member the spec does not name.** Those names are frozen because T2.2, T3.1, T6.1a and T6.1b are about to compile against them, and [[T6 - Provider Onboarding Console]] §3.4 translates the error names into sentences a provider reads. If a name looks wrong, ask.
3. **Never checkmark a task.** Only the Researcher verifies and checkmarks. Move the board marker to 🐞 and hand back.
4. **Do not commit.** The user wants to see the diff first.
5. **Leave the tree green.** The Debugger is alive and re-runs both briefs plus the parity harness against whatever you hand back.

---

## Batch 1 — T0.6

Read [[T0.6 - Fix Spec (round 2)]] §9 for the list and §§2–8 for why each item exists. §9 supersedes §18.5 of [[T0.6 - IAssetRegistry Interface]].

**Still interface-only:** no implementation, no state variables, no modifiers, no function bodies, no constructors.

**The headline fix, so you know what you are actually repairing.** `IModule.moduleCheck` hands a compliance module a compliance address and nothing else. `IAssetRegistry` mapped `assetId → token` with nothing in reverse — so `AssetLiveModule` could find the token but **never learn which asset it was looking at**, and the `attestedSupply ≤ reserve` invariant that ADR `0014` moved into the compliance module had **nowhere to be computed**. Everything else in the batch is smaller work being done while the file is open.

**The list:**
- Views: `assetOfToken(address token) returns (bytes32)`, `isAgent(address account) returns (bool)`
- Owner functions: `addAgent(address)`, `removeAgent(address)`
- Events: rename `TokenBound` → `AssetTokenBound(bytes32 indexed assetId, address token)`; add `AgentAdded(address indexed)`, `AgentRemoved(address indexed)`
- Errors: `TokenAlreadyBound(address token, bytes32 assetId)`, `AssetAlreadyHasToken(bytes32 assetId, address token)`, `InvalidTokenBinding(address token)`, `ValuationInFuture(uint64 valuationTs, uint64 blockTime)`
- NatSpec per §9.2 — including the Debugger's **C1** defect: add **"Anyone may call."** to the `@notice` of **every** view. The `// ---- Views ----` divider is a plain comment, not NatSpec, so it never reaches `devdoc`, and T5.2 assigns real on-chain roles from compiled NatSpec.
- Tests: extend `AssetRegistryMock` with the five new functions; selector-distinctness now covers **19**; add a regression test asserting `AssetTokenBound` differs from `IModularCompliance.TokenBound` by **both name and topic hash** — the rename exists because *name*-based event filtering was the hazard, so the guard must test the thing that was wrong.

**Counts to confirm before handing back:** 12 views · 3 agent · 7 owner · 11 events · 18 errors.

**Green when:** `forge build`, `forge fmt --check`, `forge test --match-contract AssetRegistryInterface`.

---

## Batch 2 — T6.0

Read [[T6.0 - Researcher Answers (round 2)]] — the work list near the end **and the addendum at the very bottom**, which carries two traps that are already decided. [[T6.0 - Debugger Questions]] holds the questions those rulings answer, if you want the context.

**Four of these defects already have failing tests committed by the Debugger.** Make them pass; do not write replacements.

**Seven items:** reject a future `valuationTs` · `maxLength: 78` plus an exact `BigInt` bound on `intendedSupply` and `unitValue` · reject the zero address and `treasuryWallet == token` · reject absolute paths and any `..` segment in `attestations[].path` · tighten `assetId` to `^[a-z0-9]+(-[a-z0-9]+)*$` with `maxLength: 32` split out, reject invisible-only free-text fields, move missing-field paths onto the field · commit the Ajv parity harness · one sentence in the module doc that duplicate JSON keys are invisible to every validator, so git review is the only defence.

**Trap 1 — the clock.** Rejecting a future timestamp makes the validator impure and makes boundary fixtures flake. Add an optional second parameter `validateOnboardingInput(input, { now?: number })` in Unix seconds, defaulting to `Math.floor(Date.now() / 1000)`. Tests and the harness pass a fixed `now`; the script and console omit it.

**Trap 2 — the `u` flag.** The invisible-character rule uses Unicode property escapes. The TypeScript regex **must** carry `u`: without it `\P` becomes a literal `P`, which still compiles and still *looks* like it is validating. That silent-pass failure mode is the dangerous one. Document the dialect dependency in the schema `description`.

**The parity harness.** Ajv 8 as a **`devDependency` only** — "dependency-free" is a rule about *runtime* dependencies that reach consumers importing the package; a devDependency used only by its own test suite reaches nobody. Put the three deliberate TypeScript-only checks in **one explicitly named allow-list constant**, each with a comment citing its question number, and scope the future-timestamp entry to **every case where `valuationTs > now`** — not to the single year-2100 fixture, or a genuine divergence slips through the next time someone adds a case.

**Green when:** `pnpm --filter @rwa-vault/types typecheck`, `lint`, `test`; `pnpm -r` green; Prettier clean; the Debugger's four failing tests pass.

---

## Finishing

1. Append a **"Coder handoff"** section to each task's spec note: files changed, run results, how each acceptance criterion is met, and a numbered list of anywhere the spec was silent with your provisional choice **marked as provisional**.
2. Move both markers to 🐞 in [[M3 Task Board and Todo]].
3. Add a line to [[Changelog]].
4. **Do not checkmark. Do not commit.**
5. Message the Researcher session (`researcer`) with a summary and any questions.

---

## Not in either batch

Recorded so they are not picked up by accident: **T4.1** (the registry implementation — the agent mapping, the pre-subtraction timestamp check, the binding guards) · **T2.2** (`moduleCheck` returns `false` and never reverts; the supply cap applies only when `from == address(0)`) · **T3.1** (`Token.mint` must call `canTransfer` **before** `_mint`) · **T0.9** (ABI bindings for `packages/types`) · anything needing Fahad's Q11–Q16.

Up: [[M3 Task Board and Todo]] · Related: [[T0.6 - Fix Spec (round 2)]], [[T6.0 - Researcher Answers (round 2)]], [[Coder Agent]], [[Agents - Workflow]]
