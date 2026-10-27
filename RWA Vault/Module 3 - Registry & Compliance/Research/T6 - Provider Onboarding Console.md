---
tags: [rwa-vault, m3, research, t6]
task: T6
agent-state: 🧭 → ⌨️ → 🧭 (T6.0 questions)
status: research-complete
researcher: Claude (Researcher role)
updated: 2026-10-27
---
# 🧭 T6 Research — Provider Onboarding Console

**Researcher output for [[M3 Task Board and Todo|T6]].** This note is the `{plan, acceptance criteria}` handoff defined in [[Agents - Workflow]]: the **[[Coder Agent]]** builds exactly what is below, the **[[Debugger Agent]]** uses §7 as the intended behaviour when something is ambiguous, and **only the Researcher checkmarks T6**, against §6.

> **Nothing here is implemented.** This is research only. No code was written for this note.

---

## 0. The task, in plain words

A provider walks in with a gold lot. By the end of T6, that provider — **not** the person who wrote the code — can sit down and turn that lot into a live, tokenised, reserve-backed asset without anyone helping them, and we can prove on-chain that nobody can sneak around the rules by talking to the contracts directly instead of through our screen.

Four pieces:

| Sub-task | In plain words | In code words |
| -------- | -------------- | ------------- |
| **T6.1a** | A script that does the whole onboarding in one command | A Foundry `forge script` driven by a declarative JSON input, executing flow A of [[Decision Algorithms - for Fahad]] |
| **T6.1b** | The same thing as a web page | A React page in `apps/ops-console` calling the same contracts over `viem`, reading the same input schema |
| **T6.2** | Someone who didn't build it runs it, alone | A recorded rehearsal with zero author intervention; every question asked is logged as a documentation defect |
| **T6.3** | Prove the rules live in the contract, not in our app | A Foundry test that calls the token **directly** and reverts with the exact named error |

**Why this exists at all:** M3's done-condition in [[Module 3 - Registry & Compliance]] is literally *"a provider onboards a gold lot unaided, and a direct-contract transfer that bypasses the API is refused on-chain."* T6 **is** that sentence. T7.4 (the MS1 dry-run) just runs it for the examiners.

---

## 1. Decisions this task inherits (do not re-litigate)

From [[Decisions Log]] — all settled 2026-10-27:

- **Q9 = B** — the console is a real UI in `apps/ops-console`, **with the script built first** as both the deploy/smoke path and the fallback if the UI slips. So T6.1a is not a throwaway: it is the thing T5.3 and T7.4 actually run.
- **Q5 = A** (ADR `0017`) — reserve data arrives through `IReserveAttestationSource`, fed by a signed custodian envelope for MS1. **The MS1 reserve figure is asserted, not independently verified, and the console must say so on screen.** This is a wording requirement, not a nice-to-have.
- **Q4 = A** (ADR `0014`) — asset liveness is enforced by `AssetLiveModule` inside compliance, so the onboarding script never passes an `assetId` to the token. The script's step 5/6 talk only to `Token`; the asset binding happens at wiring time (T5.1).
- **Q7 / Q10** (ADR `0015`) — the console drives the **`agent`** role (Tier 1 service key). It must **never** hold or require the `owner` 2-of-3 multisig, and must not expose `forcedTransfer`.
- **Q8 = A** (ADR `0016`) — one token per asset, so onboarding **assigns** an already-deployed token rather than calling a factory. No `TokenFactory` in this task.

---

## 2. Dependency reality check ⚠ (read before assigning the Coder)

T6 sits **last** in the board's suggested order for a reason: it is the only task that needs the whole stack standing up.

| T6 needs | Provided by | Exists today? |
| -------- | ----------- | ------------- |
| `AssetRegistry.register` / `.admit` | T4.1–T4.3 | ❌ |
| The four named admission errors | T4.2 | ❌ |
| `Token.mint` behind `isVerified` + `canTransfer` | T3.1, T2.1, T2.2 | ❌ |
| A wired deployment to point at | T5.1, T5.3 | ❌ |
| `IAssetRegistry` / `IReserveAttestationSource` to type against | T0.6, T0.7 | ❌ (next job) |
| A custodian envelope to submit | T4.4 + M2 verifier | ❌ |

**Researcher's call:** T6 **does not start as a whole**. Split it:

- **Start now (interface-only, no running stack required):**
  - **T6.0 (new) — the input schema.** `packages/types/src/onboarding.ts` + a JSON Schema. Both T6.1a and T6.1b consume it, so it must exist before either. It can be written against T0.6's `IAssetRegistry` shape the moment T0.6 lands.
  - **T6.2's checklist document** — the rehearsal protocol (§5) is pure process; writing it now means the docs are ready when the code is, instead of being written in a panic the night before MS1.
- **Start when T5.1 lands:** T6.1a, then T6.3, then T6.1b.
- **Hard-blocked until M2's verifier is callable:** the *real* envelope path in T6.1a step 3. Until then the script accepts a **fixture envelope** and the console shows an explicit `MS1 FIXTURE ATTESTATION — NOT INDEPENDENTLY VERIFIED` banner (ADR `0017`'s wording requirement).

Handing the Coder all of T6 today would produce a script that cannot be run and therefore cannot be verified — which would break the done-rule. So: **T6.0 is the only piece that goes to the Coder in this handoff.** The rest is specified here so it is ready the moment T5.1 is green.

---

## 3. T6.1a — the onboarding script

### 3.1 Where it lives, and why there

```
contracts/script/
├── DeployM3.s.sol            ← T5.1 (wiring)
├── OnboardAsset.s.sol        ← T6.1a  THIS TASK
└── input/
    └── asset.gold-lot-001.json   ← the declarative input
```

**Why Foundry and not TypeScript**, even though the console is TS: the board says T6.1a is "also the deploy/smoke path", and that path is already `forge script` (T5.1, `pnpm contracts:deploy:local`). A `forge script` gets broadcast, `--rpc-url`, nonce handling and **custom-error decoding** for free, and runs in CI with no Node toolchain. A TS re-implementation would be a second thing to keep in sync for no gain. The TS side (T6.1b) talks to the **same contracts** and reads the **same JSON**, so the two never drift on *input*, only on *transport*.

### 3.2 The input file is the contract between 6.1a and 6.1b

```jsonc
{
  "assetId": "gold-lot-001",
  "description": "1kg kilobar, 999.9 fine, serial XAU-88213",
  "valuationBasis": {
    "source": "FIXTURE - synthetic, not a quote; per FINE gram",
    "currency": "USD",
    "unitValue": "130000000000000000000",
    "valuationTs": 1761523200
  },
  "custodianId": "custodian-brinks-dxb",
  "intendedSupply": "999900000000000000000",
  "attestations": [
    { "path": "script/input/att.gold-lot-001.seq1.cbor", "attestor": "custodian" }
  ],
  "providerWallet": "0x...",
  "token": "0x..."
}
```

- `unitValue` / `intendedSupply` are 18-decimal fixed-point strings, never JSON numbers (precision loss).
- **One token is one gram of fine gold (ADR `0020`).** So a 1 kg lot is `intendedSupply = 1000e18`, and `unitValue`
  is the price of **one gram**. Tola and milligram are **display-only**, formatted in M10; neither may appear in a
  contract signature or in this schema.
- **`unitValue` in this fixture is a deliberately synthetic placeholder, and the `source` string says so.** It is not
  a quote and must never be read as one. See §9.1 — this field has now been wrong twice, and the rule below is the
  actual fix.
- `providerWallet` must already be `isVerified`.
- `token` is the per-asset token (Q8=A).

**`attestations` is an array even though MS1 has exactly one element.** [[Decisions Log|Q11]] (insurer as required co-signer) is still open, and if it lands as Option B the predicate's clause 1 becomes a threshold check over an attestor set. Making the field an array now costs nothing; making it an array later means touching the schema, the script, the page and every fixture. This is the cheap half of "cheaper to build once than to widen later".

### 3.3 The steps the script executes

Flow A of [[Decision Algorithms - for Fahad]], unchanged, with on-chain state read **before** each step so the script is **idempotent and resumable**:

```
OnboardAsset.run():
  0. cfg ← vm.parseJson(vm.readFile(INPUT_PATH))          // no hardcoded values
  1. require(registry.isVerified(cfg.providerWallet))     // fail FAST, before any tx
  2. s ← assetRegistry.stateOf(cfg.assetId)
       UNREGISTERED → register(assetId, metadataHash)  → PENDING
       PENDING      → fall through to 3
       LIVE         → log "already live", skip to 5
       FROZEN       → abort with a human sentence (needs an operator, not a script)
  3. env ← readEnvelope(cfg.attestations[0].path)
  4. assetRegistry.admit(env, cfg.intendedSupply)         // the 4-clause predicate
  5. assert(token.compliance() is bound && assetLiveModule covers cfg.assetId)
  6. token.mint(cfg.providerWallet, cfg.intendedSupply)
  7. print the receipt: state, reserve, attestedSupply, seq, token address, tx hashes
```

Two things in that sketch are deliberate and must survive into the implementation:

- **Step 1 runs before any transaction.** The single most likely provider mistake is onboarding against a provider wallet that was never KYC'd. Discovering that at step 6, after two broadcast transactions and a PENDING asset on chain, is a terrible first experience and makes T6.2 fail on usability. Check it first, off-chain, free.
- **Step 2 reads state and branches.** A rehearsal participant *will* ctrl-C halfway. Re-running must continue, not explode with "asset already registered".

### 3.4 Error surfacing — the part that actually decides T6.2

The admission predicate's four clauses revert with named custom errors (T4.2, per the M1 style rule in [[Mathematics - Admission Predicate and Invariants]]). A raw `forge script` failure prints a selector. A provider cannot read a selector. The script must catch and translate:

| Custom error | What the operator is told | What they should do |
| ------------ | ------------------------- | ------------------- |
| `BadAttestationSig` | "The custodian's signature on this attestation is not valid for the registered custodian key." | Re-request the envelope; check the custodian key in the registry |
| `StaleSequence` | "This attestation (seq N) is older than or equal to the last one accepted (seq M)." | Ask the custodian for a fresh envelope with a higher sequence |
| `ReserveTooLow` | "The attested reserve (R) is less than the supply you asked to mint (S)." | Lower `intendedSupply` to ≤ R, or get a higher attestation |
| `ValuationStale` | "This valuation is H hours old; the limit is τ." | Re-request with a current valuation timestamp |

Implement with `try … catch (bytes memory err)` and a selector switch. **This table is the acceptance bar, not documentation** — see AC-5.

### 3.5 What the script must NOT do

- Must not deploy anything (that is T5.1). It onboards against an existing deployment read from env/broadcast artefacts.
- Must not hold or request the `owner` multisig key (ADR `0015`).
- Must not write a private key into the input JSON. Keys come from `--private-key` / `--keystore` / `$ONBOARD_AGENT_KEY` only, and the input file is committed to git — so the schema has **no key field at all**, by construction.

---

## 4. T6.1b — the page in `apps/ops-console`

### 4.1 The uncomfortable truth about the current package

`apps/ops-console` today is **not a UI**. It is a bare TypeScript library: one `src/index.ts` exporting `CONSOLE_NAME`, a `tsc --build`, no React, no bundler, no dev server. Its only dependency is `@rwa-vault/types`.

So "wrap it as a page" is really **two** jobs, and the Coder should be told so:

1. **Scaffold the app.** React 18 + Vite + `viem` + TanStack Query — matching the stack `apps/client` already declares in its own `package.json`, so the repo keeps one front-end story rather than two. Add `dev`/`build` scripts; keep `lint` and `typecheck` as they are so the existing root `pnpm -r` targets keep working.
2. **Build the onboarding page** on top of it.

Scaffolding a second front-end stack inside the monorepo is a non-obvious call → **it needs an ADR** (**`0025`** — renumbered three times as parallel sessions claimed numbers: `0018` is reserved for Q13, and `0020`–`0024` are the custody set. The custody session has reserved **0025+** for us. Confirm against [[ADR Index]] before writing it.), per the repo rule. The Researcher writes it; the Coder does not improvise it.

### 4.2 The page

A four-step wizard, one step per phase of flow A, with the on-chain state as the source of truth on every render (TanStack Query against `stateOf(assetId)`), never local component state:

1. **Asset** — metadata, valuation basis, custodian, intended supply, provider wallet. Inline validation: provider wallet must come back `isVerified` **before** the Next button enables. Same fail-fast rule as the script, same reason.
2. **Attestation** — upload or select the custodian envelope; show the decoded `(reserve, seq, valuationTs)` and a live "is this fresh?" countdown against τ. Banner, non-dismissible: **`MS1: reserve is asserted by the custodian, not independently verified`** (ADR `0017`).
3. **Admit** — show the four clauses as four checkmarks evaluated client-side *before* submitting, then submit. On revert, render the §3.4 sentence, not the selector.
4. **Mint** — mint to the provider wallet, then show the receipt: state LIVE, reserve, attestedSupply, invariant `attestedSupply ≤ reserve` ✅.

### 4.3 ABI typing

Generate typed ABIs from the Foundry artefacts into `packages/types/src/abis/` (a small codegen step over `contracts/out/*.json`) rather than hand-writing them. Hand-written ABIs in a TS app that talks to contracts under active development is a guaranteed source of silent mis-encoding.

### 4.4 The non-negotiable property

From `apps/ops-console/src/index.ts`'s own header: *"Neither console can move funds — no off-chain component in this system can."* The page therefore exposes **`register` / `admit` / `mint` only**. No transfer, no `forcedTransfer`, no freeze of an investor wallet from this page. That is an operator incident flow (flow D), not an onboarding flow.

---

## 5. T6.2 — the unaided rehearsal (a protocol, not a vibe)

This is the one sub-task with no code. It needs a procedure, or it will be "yeah Hassan ran it, seemed fine", which proves nothing.

**Participant:** a teammate who wrote **none** of T6 — Hassan or Fawaz, whichever did not implement it. The author may be in the room but **may not speak**.

**Setup:** a fresh `git clone`, a clean `anvil`, and **only** [[How to Run Module 3]] as documentation. No Slack, no sitting next to the author.

**The rule that makes it meaningful:** every single time the participant asks a question, gets stuck for more than 60 seconds, or guesses, it is written down as a **documentation defect** — against the *doc*, never the person. Fix the doc, then re-run with a *different* participant if any P0 defect was found.

**Artefact:** `docs/reports/M3-onboarding-rehearsal.md` — participant, date, commit SHA, wall-clock time per step, the defect list with severities, and the pass/fail verdict.

**Pass bar:** the participant reaches a LIVE asset with minted tokens, with **zero author intervention** and **zero P0 defects** open. Time is recorded but is not a gate.

---

## 6. Acceptance criteria — the done-bar the Researcher checks

Objective, runnable by a third party, exact error names. No criterion below says "works" or "looks right".

**T6.0 — schema**

- **AC-1** `packages/types/src/onboarding.ts` exports an `OnboardingInput` type and a validator; `pnpm --filter @rwa-vault/types typecheck` passes.
- **AC-2** `attestations` is typed as an array. A fixture with two elements type-checks (even if the script rejects >1 for MS1 with a named error).
- **AC-3** The type has **no** field that could hold a private key or mnemonic. Verified by inspection at review.

**T6.1a — script**

- **AC-4** `forge script script/OnboardAsset.s.sol --rpc-url http://localhost:8545 --broadcast` against a fresh T5.1 deployment ends with the asset `LIVE`, `attestedSupply == intendedSupply`, and `attestedSupply ≤ reserve`. Shown by the script's own printed receipt **and** re-read with `cast call`.
- **AC-5** Four tests in `contracts/test/registry/OnboardAsset.t.sol`, one per clause failing **in isolation**, each asserting the exact error **and** the exact operator-facing sentence from §3.4: `test_OnboardRejectsBadAttestationSig`, `test_OnboardRejectsStaleSequence`, `test_OnboardRejectsReserveTooLow`, `test_OnboardRejectsValuationStale`. A bare `vm.expectRevert()` with no selector **fails review**.
- **AC-6** Idempotency: running the script twice in a row on the same input leaves exactly one asset LIVE, mints exactly once, and the second run exits 0 with "already live". Asserted in `test_OnboardIsIdempotent`.
- **AC-7** Fail-fast: with an unverified `providerWallet`, the script aborts **before broadcasting any transaction** (asset stays UNREGISTERED) and names the wallet. `test_OnboardAbortsOnUnverifiedTreasury`.
- **AC-8** No value is hardcoded: changing `assetId` and `intendedSupply` in the JSON alone onboards a second lot with no Solidity edit.

**T6.1b — console**

- **AC-9** `pnpm --filter @rwa-vault/ops-console dev` serves the page; `build`, `typecheck` and `lint` all pass from the repo root (`pnpm -r`).
- **AC-10** An ADR exists recording the React/Vite/viem scaffolding decision for `apps/ops-console` — **`0025` at the time of writing**, but confirm the next free number against [[ADR Index]] first: this was `0018`, then `0023`, and both were claimed by other sessions before it could be written.
- **AC-11** Step 1's Next button is disabled while `isVerified(providerWallet) == false`. Component test.
- **AC-12** The ADR-`0017` non-dismissible banner is present on the attestation step. Component test asserting the text.
- **AC-13** A forced `ReserveTooLow` revert renders the §3.4 sentence with the actual R and S values, and **no** raw selector or hex anywhere in the DOM.
- **AC-14** The page's exported surface contains no transfer, `forcedTransfer`, freeze or pause call. Verified by grep at review.

**T6.2 — rehearsal**

- **AC-15** `docs/reports/M3-onboarding-rehearsal.md` exists, names a participant who authored none of T6, and records a commit SHA.
- **AC-16** Verdict is PASS with zero author intervention and zero open P0 defects.

**T6.3 — bypass**

- **AC-17** `contracts/test/registry/BypassTest.t.sol` calls the token **directly** (no service, no console) and asserts **three** distinct refusals with exact errors:
  - `test_DirectTransferToUnverifiedReverts` → `ReceiverNotVerified`
  - `test_DirectMintToUnverifiedReverts` → `ReceiverNotVerified`
  - `test_DirectTransferWhenAssetNotLiveReverts` → the compliance veto error from `AssetLiveModule` (T2.2 names it)
- **AC-18** The `cast send` manual demo in [[How to Run Module 3]] §7 is updated with the real token address pattern and the real expected error string, and a third party reproduces it.

**Added 2026-10-27 from the Coder's questions ([[T6.0 - Researcher Answers]] B1, B5)**

- **AC-19** The `ValuationStale` message names its source: *"…This is the timestamp inside the signed envelope — editing the input file will not change it."* The script's pre-flight prints the input's `valuationBasis.valuationTs` and the envelope's side by side, and warns when they differ by more than 1 hour. Asserted in `test_OnboardValuationStaleMessageNamesEnvelope`.
- **AC-20** The script (T6.1a) and the console (T6.1b) each reject a mixed-case address failing its EIP-55 checksum, with a named error quoting the address; an all-lowercase address is accepted. `test_OnboardRejectsBadChecksumAddress` + a component test.

**Added 2026-10-27 — owed from §9.0/§9.1 and the D6 ruling**

- **AC-21** The mint path names its failing condition **before sending a transaction.** T6.1a and T6.1b read
  `isLive(assetId)` and `reserveOf(assetId)` and compare against the intended amount in pre-flight, then say which
  condition fails. A compliance veto reaches the token as a generic failure — `IModule.moduleCheck` returns `bool`, so
  the named errors are **not** available on the mint path (§8 of [[T0.6 - Fix Spec (round 2)]]). Specificity therefore
  comes from reading first, not from decoding a revert. `test_OnboardPreflightNamesFailingCondition`.
- **AC-22** The script **refuses to proceed when `valuationBasis.source` is marked `FIXTURE` and the run is not a
  test**, with a named error quoting the source string. A placeholder price must not be able to reach a real
  admission: `unitValue` is committed into `metadataHash`, so whatever a demo uses is permanent and irreversible for
  that lot. `test_OnboardRefusesFixtureSourceOutsideTest`.
- **AC-23** The onboarding receipt prints the **weight basis** alongside the numbers — `intendedSupply` in fine grams,
  `unitValue` per fine gram (ADR `0020`). The ambiguity that forced `0020`'s amendment lived in a unit that was never
  written down; a receipt that prints bare numbers reintroduces it at the one moment a human is checking the work.

> **Why three tests in AC-17 and not one.** "Bypass" is not only "an unverified wallet receives tokens". It is also "an asset that is not LIVE still mints" — which is the gate Q4=A moved into compliance, and therefore the gate most likely to be wired wrong. One test on the verification path would pass while the liveness path hung open.

---

## 7. For the Debugger — intended behaviour on the likely ambiguities

| Ambiguity | Intended behaviour | Why / cite |
| --------- | ------------------ | ---------- |
| Script re-run on a LIVE asset — error or no-op? | **No-op, exit 0**, print "already live". | AC-6; a rehearsal participant must be able to re-run safely |
| Script run on a FROZEN asset? | **Abort, non-zero**, with "this asset is frozen; an operator must resolve it". Never auto-unfreeze. | Flow D in [[Decision Algorithms - for Fahad]] — unfreezing is an operator decision |
| Attestation whose reserve ≥ supply but valuation is 1 second past τ? | **Reject** with `ValuationStale`. No grace window. | §2 clause 4 of the maths note is a hard inequality; a grace window is a τ change and needs an ADR |
| Two attestations in the input for MS1? | **Reject** with a named error, do not silently use the first. | Q11 is open; silently picking one would hide a real config error |
| Mint of `intendedSupply` when reserve is strictly higher? | **Allowed.** The invariant is `attestedSupply ≤ reserve`, not equality. | §3 of the maths note |
| Console shows a stale state after a revert | Re-read `stateOf` from chain; never trust local state. | §4.2 |

If something is not in this table, the Debugger **asks the Researcher** — it does not pick a behaviour. That is the loop rule in [[Agents - Workflow]].

---

## 8. Risks

| Risk | Severity | Mitigation |
| ---- | -------- | ---------- |
| T6 is behind the entire stack (§2); starting it now produces unverifiable code | **High** | Only T6.0 ships in this handoff; the rest is specified and queued behind T5.1 |
| `apps/ops-console` has no UI stack at all, so T6.1b is secretly a scaffolding task | **High** | Split explicitly (§4.1); ADR `0018`; the script (T6.1a) is the fallback deliverable, per Q9's own wording |
| MS1's reserve is asserted, not verified — an examiner calls this out | **Medium** | ADR `0017` already concedes it; AC-12 forces the admission onto the screen rather than hiding it |
| Q11 lands after the schema is written | **Medium** | `attestations` is an array from day one (§3.2) |
| M2's ML-DSA-65 verifier not callable in time | **Medium** | Fixture-envelope path with the explicit banner; the real path swaps in behind the same `IReserveAttestationSource` seam |
| Rehearsal becomes a rubber stamp | **Medium** | §5's protocol: non-author, docs only, defects logged against the doc, PASS requires zero intervention |
| Someone commits a key into the input JSON | **Low likelihood / severe impact** | The schema has no key field (AC-3); keys only via `--private-key` or env |

---

## 9.0 Weight basis: supply is FINE grams, not gross — ruled 2026-10-27

Found by the Debugger's unit sweep, and it is the kind of hole that only shows up at a demo. ADR `0020` says two
things that **agree only for chemically pure gold**: one token is one gram of **fine** gold, *and* "a 1 kg lot mints
1000e18".

A real kilobar is **999.9 fine** — 1,000 g gross, 999.9 g of actual gold. So:

- If the custodian attests reserve in **fine** grams, which is what the token claims, then `999.9e18 ≥ 1000e18` is
  **false** and admission rejects **an honest bar** with `ReserveTooLow`. The fixture lot fails.
- If supply is minted on **gross** weight, then every token over-claims fine gold by 0.01%.

**Ruling for M3: fine weight, on ALL THREE sides** — extended 2026-10-27 after the custody session caught a third
place I had missed. `intendedSupply` is fine grams, the attested `reserve` is fine grams, **and `unitValue` is the
price per FINE gram**.

Their catch is the same bug one layer along, and it is worth stating because I named two sides and stopped: a price
"per gram" reads unambiguous until you ask *which* gram. Value a lot per **gross** gram while its supply is counted in
**fine** grams and every valuation is 0.01% low, with the admission predicate inheriting the error. It also happens to
match reality — LBMA benchmarks are quoted for fine gold — so M5 needs no conversion. The schema documentation must say
**"per fine gram"**, not "per gram".

The reason is the invariant itself. `attestedSupply ≤ reserve` only means something if both sides measure **the same
substance** — compare a claim on fine gold against a count of gross metal and the inequality is arithmetic without
content. And minting on gross weight would bake a 0.01% over-claim into every token by design. 0.01% is small; an
over-claim that is *deliberate* is not, because "backed" is the single property this whole project rests on, and it
is the first thing an examiner will test.

**Fixture corrected:** `intendedSupply` becomes `999.9e18`, and the description now records the fineness the supply
depends on.

**Also corrected, and it mattered more than it looks:** the description said "1kg LBMA Good Delivery bar", which is
factually wrong — Good Delivery gold bars are ~350–430 oz, roughly 11–13 kg. A 1 kg bar is a **kilobar**. That string
is hashed into `metadataHash`, so it would have been committed on-chain permanently, **and** §3.2 is the template
every provider copies, so the error would have propagated to every lot.

**Raised with the custody session:** ADR `0020`'s own example needs amending, since "a 1 kg lot mints 1000e18" is the
sentence that is wrong, and the ADR must name the weight basis explicitly for both `reserve` and `intendedSupply`.
**Recommended for a later T6.0 round:** carry fineness as a *field* rather than prose, so the script can derive
`intendedSupply` from gross weight × fineness and reject a mismatch. Recorded in free text, nothing can check it.

---

## 9.1 Rule: a fixture never carries a real market price

This field has been wrong twice in one day, in two different ways, and the second time is the instructive one.

First it held `2385e18` — an **ounce** price in a per-gram field, wrong by ~31× once ADR `0020` fixed one token to one
gram. I corrected the unit to `76.68e18`. The custody session then pointed out that `2385/oz` is itself **roughly a
2024 level**: it reports the October 2026 LBMA afternoon fix nearer **$4,120–$4,180/oz**, about **$132/g** — from
secondary sources that disagree by tens of dollars, so treat it as a level and not a figure. **I cannot verify that
price and neither can they.** Its cross-check is the better evidence: Fahad's own PKR 400,000/tola is 34,293 PKR/g,
which against ~$132/g implies ~259 PKR/USD — plausible, so his number is the sound input and the ounce price is the
stale one. The fixture's `valuationTs` is 27 October 2026, so it also paired a 2024 price with a 2026 timestamp.

**So the fix is not a better number.** Replacing a 2024 price with an October 2026 price only resets the clock on the
same defect: it is stale next month, and it looks authoritative while being unverifiable. A test fixture's job is to
exercise the schema's *shape*, and it needs no real price to do that.

**The rule, binding on every fixture in M3:**

1. `unitValue` in a fixture is an **obviously synthetic, round placeholder**, and the `source` string declares it a
   fixture rather than a quote. `130e18` with `source: "FIXTURE - synthetic, not a quote; per FINE gram"`.
2. It must stay **unit-correct and the right order of magnitude** — per gram, low hundreds of USD — so that a
   unit error like ounce-for-gram is still obvious by eye. A placeholder of `1e18` would have hidden the original bug.
3. **The MS1 demo takes its price from an M5 source, never from a fixture.** A demo that reads a committed number is
   presenting a hardcoded valuation as a live one, and `unitValue` goes into `metadataHash`, so whatever the demo uses
   is committed to that lot permanently and irreversibly.
4. Any fixture price that is meant to be real carries its **quote date and source** beside it, or it is a placeholder.

Carried to **T6.1a** as an acceptance criterion: the onboarding script must refuse to proceed when `source` is marked
`FIXTURE` and the run is not a test — so a placeholder cannot reach a real admission by accident.

---

## 9. New question for Fahad

**Q12 — Who operates the onboarding console: the provider, or us on their behalf?**

Q9 settled *that* there is a UI; it did not settle *who logs into it*. The two answers are different products:

- **(a) Internal operator tool** — we run it, the provider sends us the lot details. No accounts, no authn beyond network access, the Tier 1 agent key sits with the operator. Small, shippable for MS1.
- **(b) Provider self-service** — the provider logs in themselves. Now T6 also needs accounts, sessions, authorisation, per-provider scoping and an audit trail of who submitted what.

**Recommendation: (a) for MS1.** "Unaided onboarding" (T6.2) is a test of whether the *procedure* is self-explanatory, not of whether we built a multi-tenant SaaS — and (a) satisfies it. Record (b) as Phase 2.

**Blocks:** T6.1b's scope only. T6.0, T6.1a and T6.3 proceed either way, so this is **not** a blocker for this handoff. Logged in [[Open Questions for Fahad]].

---

## 10. Handoff

**To the [[Coder Agent]] — now:** T6.0 only (§3.2 schema), acceptance AC-1 → AC-3. Needs T0.6 landed first for the `IAssetRegistry` shape.
**To the [[Coder Agent]] — on T5.1 green:** T6.1a (§3) → T6.3 (AC-17/18) → T6.1b (§4), in that order. T6.3 before T6.1b deliberately: it proves the on-chain gate, which is the MS1 claim; the UI is only the presentation of it.
**To Fahad:** Q12 (§9), and Q11 before T4.2 is written.
**Back to the Researcher:** verification against §6 — and T6 gets its ✅ from nobody else.

---

## 11. Coder handoff — T6.0 (2026-10-27)

**State: ⌨️ → 🐞.** Not checkmarked — the Researcher verifies against AC-1…AC-3.

**What was built**

| File | What |
| ---- | ---- |
| `packages/types/src/onboarding.ts` | `OnboardingInput` (+ `ValuationBasis`, `AttestationRef`), `validateOnboardingInput()` returning `{ok, value}` or `{ok:false, issues[]}` with JSON-pointer paths; collects every issue in one pass. Zero runtime deps, so the package's "depends on nothing" rule holds. |
| `packages/types/schema/onboarding-input.schema.json` | JSON Schema 2020-12 twin, `additionalProperties: false` at every level. Exported as `@rwa-vault/types/schema/onboarding-input.schema.json`. |
| `packages/types/src/__tests__/onboarding.test.ts` | 9 `node:test` cases + one `@ts-expect-error` compile-time check. Includes a drift test: schema and TS must agree on field names and required-ness. |
| `packages/types/src/index.ts`, `package.json` | Re-export; `test` script now runs the suite; `exports` map added. |

**Results:** `pnpm --filter @rwa-vault/types typecheck` ✅ · `lint` ✅ · `test` 9/9 ✅ · `pnpm -r typecheck` and `pnpm -r lint` ✅ · Prettier clean.

**AC mapping**
- **AC-1** — type + validator exported; typecheck passes; §3.2 fixture validates.
- **AC-2** — `attestations: readonly AttestationRef[]`, `minItems 1`. A two-element fixture type-checks **and** validates; a scalar fails to compile (`@ts-expect-error`) and fails validation. Rejecting >1 for MS1 stays in T6.1a, as §3.2 says.
- **AC-3** — no key-shaped field (test greps every field name for key/secret/mnemonic/seed/password/keystore/signer). Also **unknown fields are rejected**, so a smuggled `"privateKey"` is an error rather than silently ignored — at any nesting level.

**Where the plan was silent — flagged, not decided for good.** Sent to the Researcher as [[T6.0 - Coder Questions for Researcher]], which also adds three gaps found on review: no `metadataHash` source, an input `valuationTs` that duplicates the envelope's, and an unused `unitValue`.
1. **T0.6 has not landed.** Built against the §3.2 JSON shape. How the string `assetId` maps on-chain (`bytes32` packing vs `keccak256`) is T0.6's call; the schema only caps it at 32 bytes so either works.
2. **`assetId` format** = lowercase slug `^[a-z0-9][a-z0-9-]{0,31}$`. My choice; §3.2 only gives an example.
3. **`attestor`** accepts only `"custodian"`. If Q11 = B, widen `AttestorRole` / the schema `enum` to add `"insurer"`.
4. **Address checksum (EIP-55) is not enforced** — would need keccak, i.e. a runtime dependency. Format only; the script/viem will reject a bad checksum anyway.
5. **Amounts** must be base-10 strings, > 0, no leading zeros. `valuationTs` stays a JSON number (positive safe integer), as in §3.2.
6. **`attestations[].path`** is documented as relative to `contracts/`, matching §3.2's `script/input/...`.

### 11.1 Researcher answers applied (2026-10-27) — ⌨️ → 🐞

Applied [[T6.0 - Researcher Answers]] "What the Coder does next", items 1–3. Nothing else changed; T0.6 was not touched.

| Change | Where |
| ------ | ----- |
| **B6:** `AttestationRef` is now `AttestationFromPath \| AttestationInline`: `attestor` plus exactly one of `path` or `bytesBase64`. The validator reports *neither* or *both* at `/attestations/i`; `bytesBase64` must be standard base64. | `onboarding.ts` |
| **B6:** schema item has `required: ["attestor"]` and `oneOf: [{required:[path]}, {required:[bytesBase64]}]`, still `additionalProperties: false`. | `onboarding-input.schema.json` |
| **B1:** doc comment on `valuationBasis.valuationTs`: informational; `ValuationStale` uses the envelope's timestamp, so editing this field never clears it. | `onboarding.ts` |
| **Tests:** the two the Researcher asked for (both / neither), plus inline-base64 accepted, bad base64 rejected, a `@ts-expect-error` that *both* fails to compile, and the drift test now checks the `oneOf`. | `onboarding.test.ts` |

**Results:** `typecheck` ✅ · `lint` ✅ · `test` **13/13** ✅ · `pnpm -r typecheck` and `pnpm -r lint` ✅ · Prettier clean.

**One spot where I went past the letter of the answer, flagged:** the Researcher's union snippet would still *type-check* an object with both `path` and `bytesBase64` (TypeScript's excess-property check doesn't catch it across a union). I added `bytesBase64?: never` / `path?: never` to the opposite branch so the **type** enforces "exactly one", matching the Researcher's stated intent ("never both, never neither"). The runtime validator enforces it either way.

**New exported constant:** `ATTESTATION_SOURCE_FIELDS = ["path", "bytesBase64"]`; `ATTESTATION_REF_FIELDS` is now `["attestor", "path", "bytesBase64"]` (every allowed field, not every required one).

**Noticed while reading [[T0.6 - IAssetRegistry Interface]], not acted on (for the Researcher):**
- Its `recordMint` / `recordBurn` are called **by the token**, which means the token references the registry. ADR `0014` says *"the token itself never references an asset, an assetId, or the registry."* One of the two needs to change, or the ADR needs an amendment.
- `admit` takes `bytes calldata attestation` and passes it to the source's `verifyAndDecode`. When M5's oracle replaces the source (ADR `0017`), it would have to accept bytes it has no use for. That works, but worth a sentence in ADR `0019` saying it's intended.

Next: [[T6.0 - Debugger Brief]] (now 13 existing cases, not 9: §1's "already covered" list predates B6).

## 12. T6.0 — Debugger Report (2026-10-27)

**🐞 → ⌨️ (4 defects) + 🧭 (7 questions).** Not ready for verification. Do not checkmark.

**Method:** every row of the brief, plus about 15 extra edge cases, was run through **both** the TS validator (`dist/onboarding.js`) **and** Ajv 8 `Ajv2020` (`strict:false, allErrors:true`) against `onboarding-input.schema.json`. 80 cases in total. The harness is a scratch script and is not committed (see "For the Coder" #6).

### What held ✅
- **A1–A4:** `null`, an array, a string, a number, `true` and `undefined` each give one issue at `""` and never throw.
- **A6 (prototype pollution):** `__proto__`, `constructor` and `prototype` are rejected as unknown fields at the top level and nested, and `({}).polluted` stays `undefined`. The validator never builds an object from input keys. Now asserted by a test.
- **A7:** a 10 MB unknown field is rejected in milliseconds, because unknown fields are never walked. **C7:** 1,000 attestations are accepted, with no blow-up.
- **B1–B3, B5** (the Cyrillic `о` and a trailing `\n` are both rejected, since a JS `$` does not match before `\n`), **B6** (empty description is rejected), **B7–B9** (including full-width `１`), **B11, B12** (`NaN` never reaches the validator because `JSON.parse` throws first), **B14** case and length, **B17**, **B18**.
- **C1–C3, C5, C6** (and url-safe base64 is rejected), **C8** (accepted, so T6.1a owns it), **C9, C10**.
- **D1: 0 divergences** between TS and JSON Schema across all 80 cases. **D3:** the drift test fails if a field is added to only one side, in either direction.
- **E2:** six-plus errors are all returned with the new union. **E4:** no message or path echoes a rejected value. Now asserted by a test.

### Defects found → Coder 🔴
Each has a failing test in `onboarding.test.ts`, under `// Debugger (T6.0 Debugger Brief)`. All four were predicted in the brief's §5, so this is confirmation of the prediction, not new discovery.

| # | Case | Today | Fix spec |
| - | ---- | ----- | -------- |
| **B10** | `intendedSupply` / `unitValue` = `2²⁵⁶` or 1000 digits | accepted | In `checkPositiveUint`, after the regex: `BigInt(v) > UINT256_MAX` → `"exceeds the uint256 maximum (2^256 − 1)"`. Schema part is waiting on **Q2**. |
| **B13** | `valuationTs` = 2100-01-01 | accepted | Reject a future timestamp at `/valuationBasis/valuationTs`. The bound is waiting on **Q1**. The test only uses year 2100, so it is safe under any reasonable δ. |
| **B15** | `treasuryWallet` / `token` = `0x000…0` | accepted | In `checkAddress`: `/^0x0{40}$/` → `"must not be the zero address — a mint to it destroys the supply"`. Schema: in `$defs.address` add `"not": {"pattern": "^0x0{40}$"}`. |
| **C4** | `path` = `../../../etc/passwd`, `script/../../x`, `/etc/passwd`, `C:\keys`, `\\srv\share\x` | accepted | Reject a leading `/` or `\`, a `^[A-Za-z]:` drive prefix, and any `..` segment (split on `/` and `\`) → `"must be a path relative to contracts/, without '..'"`. Schema: on `path`, add `"not": {"pattern": "(^[\\\\/])|(^[A-Za-z]:)|(^|[\\\\/])\\.\\.([\\\\/]|$)"}`. |

**For the Coder:**
1. Fix TS **and** schema together, then rerun the D1 parity check.
2. Do not change the four `(defect)` tests to make them pass.
3. **A5 doc defect:** add one sentence to the module doc: "duplicate keys are resolved by `JSON.parse` (last wins) and are invisible to this validator; git review is the only defence."
4. **E3:** messages read fine to a provider. One small nit: `"must be an object"` at `/attestations/i` could say `"each attestation must be an object with attestor and path"`.
5. **D2 gap, noted:** the drift test compares field names and required-ness only. Loosening a `pattern` in the schema alone would **not** fail it, so pattern drift is only caught by a D1-style parity check.
6. **Recommended, as a Researcher call (it adds a devDependency):** commit the D1 parity harness (Ajv 8) as a test. Patterns and bounds then cannot drift silently.

### Back to the Researcher 🧭
[[T6.0 - Debugger Questions]] has 7 questions:
- Q1: the future-timestamp bound (B13)
- Q2: how the schema expresses the uint256 limit (B10)
- Q3: treasury == token, reject or warn (B16)
- Q4: `gold-` and `go--ld` (B4)
- Q5: currency allow-list (B14)
- Q6: invisible-only strings
- Q7: where a missing-field path should point (E1)

Q1–Q3 also decide whether a TS-only check may deliberately break D1 parity.

### Not T6.0 defects (recorded so they aren't lost)
- **B17 / AC-20:** a bad EIP-55 checksum is accepted, which is correct for T6.0. This is a T6.1a/T6.1b requirement.
- **C8:** more than one custodian attestation → T6.1a's named error.
- **E4 edge:** a secret pasted as a *key name* is echoed in the issue path (`/0xabab…`). This is very unlikely, and redacting it would cost useful paths, so it is noted rather than fixed. The Researcher can promote it.

**Results:** `typecheck` ✅ · `lint` ✅ · `test` **15 pass / 4 fail**. The 4 failures are the intended red tests above.

Up: [[M3 Task Board and Todo]] · Related: [[Agents - Workflow]], [[Researcher Agent]], [[Decision Algorithms - for Fahad]], [[Mathematics - Admission Predicate and Invariants]], [[Decisions Log]], [[How to Run Module 3]]
