---
type: audit
tags: [rwa-vault, audit, decisions, adr]
status: done
date: 2026-10-27
scope: "RWA Vault/ (all notes), docs/adr/0001-0026, AGENTS.md, Module Build Plan, code in contracts/, packages/types, packages/pq-core, .github/workflows"
updated: 2026-10-27
---
# 🔎 Decision Conflict Audit — 2026-10-27

Every place where two sources in the project say different things about the same decision, plus every place where an
ADR says one thing and the code on disk does another. **Source of truth order used to judge each conflict:**
code on disk → ADR → Question/Task note frontmatter → everything else (dashboards, logs, AGENTS.md, summaries).

Legend: **Fixed** = stale text corrected in this pass (no decision needed). **Needs Fahad** = a real choice, logged as
a decision note in [[Module 3 - Registry & Compliance/Decisions/Open Questions for Fahad|Open Questions for Fahad]].

## A. Decision conflicts inside the vault and ADRs

| # | Conflict | Sources that disagree | Resolution |
|---|---|---|---|
| A1 | **Insurer co-signature (Q11) is called "locked" but has no ADR, no gas figure, and is missing from the interface.** AGENTS.md lists a 5-clause predicate as a locked invariant; ADR 0017/0019, the maths note, Understanding notes and the T6 spec all say 4 clauses; `IReserveAttestationSource` has no insurer signature or policy fields. | AGENTS.md §4, T4 task, True Values vs ADR 0017, ADR 0019, `IReserveAttestationSource.sol` | **Needs Fahad → Q17** |
| A2 | **The "~3.9M gas" figure used for Q11 is Falcon's, not ML-DSA-65's.** ADR 0011's 3.9M is `ZKNOX_falcon`. The project has no on-chain ML-DSA-65 verifier at all, and the Build Plan puts the M2 verifier off-chain (NestJS). So "where is clause 1 checked" is undecided. | Command Center "Open Actions", Q11 note, Decisions Log vs ADR 0011, Build Plan M2 | **Needs Fahad → Q18** |
| A3 | **"16/16 decided, zero blocking"** vs an open gas sign-off and a Q11 "ADR needed" on the same dashboard. | Command Center, M3 Questions Index vs Decisions Log "carried work" | **Fixed** — dashboards now show Q17–Q22 as open |
| A4 | **Q9 ADR:** Decisions Log says "— (scope)", index and dashboard say ADR 0026. | Decisions Log vs Questions Index, Command Center | **Fixed** — 0026 |
| A5 | **Q15 ADR:** Decisions Log says "needs an ADR"; ADR 0025 exists. **Q13:** "0018 (Researcher to write)"; ADR 0018 exists. | Decisions Log vs docs/adr | **Fixed** |
| A6 | **ADR 0018 cites "ADR 0015's immutable deployment".** Immutability is ADR 0025; 0015 is agent powers. | ADR 0018 Rationale | **Fixed** (cross-reference only; ADR still Proposed) |
| A7 | **T6 spec cites "ADR 0018" for the ops-console UI stack.** That is ADR 0026; 0018 is the freshness window. | T6 spec §8 | **Fixed** |
| A8 | **ADR 0026 status is "Reserved / Proposed".** ADR 0001 allows only Proposed → Accepted → Superseded/Rejected. | ADR 0026 vs ADR 0001 | **Fixed** → Proposed |
| A9 | **Every ADR after 0001 is still "Proposed"**, yet M1 Stages 1–3 were built on 0002–0011 and ADR README says Stage 1 must not start before they are Accepted; M3 decisions are "taken by Fahad" but their ADRs are Proposed. | docs/adr/README.md vs git history and Decisions Log | **Needs Fahad → Q21** |
| A10 | **AssetLiveModule vetoes transfers or only mints?** ADR 0019 decision 6 says **mints only** (supersedes ADR 0014's "mint or transfer"); T2 task note and True Values still say "vetoes transfers". | ADR 0019 vs T2 task, True Values | **Fixed** → mints only |
| A11 | **What FROZEN blocks.** `packages/types/src/index.ts` says "no minting, redemption, or borrowing"; ADR 0019/0021 say minting only; AGENTS.md says "minting and new admissions". | code comment vs ADR 0019, 0021, AGENTS.md | **Fixed in vault/AGENTS.md**; code comment flagged for the Coder (T6.0 PR) |
| A12 | **1 kg lot = `1000e18`** still in T6 spec §3.2, contradicting ADR 0020's amendment (999.9-fine kilobar = `999.9e18`) and §9.0 of the same note. | T6 spec §3.2 vs §9.0, ADR 0020, `fixtures.ts` | **Fixed** |
| A13 | **ADR 0019 numbering runs 1,2,3,4,6,5** and amends ADR 0014 without marking 0014. | ADR 0019 / 0014 | **Fixed** — note added to 0014 pointing to 0019 §6; numbering left (cited externally) |
| A14 | **Broken dashboard links.** Command Center links `Q01 - Implementation Strategy` etc.; the real notes are `Q01 - Build our own ONCHAINID…`. All 16 links were dead. | Command Center vs Questions/ | **Fixed** |
| A15 | **M4 scope rewritten.** True Values calls M4 "triple-entry accounting … pending redemptions"; the Build Plan defines M4 as an ERC-4626 vault with `_decimalsOffset() = 6`, fuzzing and a Halmos proof. | True Values vs Build Plan | **Fixed** → Build Plan wording |
| A16 | **M1 Stage 3:** commit `7eb5fc8` says "complete module 1 stage 3"; True Values says 12/15 with three tasks open. | git log vs True Values | Fact check, not a design choice: **Researcher to verify** S3-05, S3-10, S3-13 on disk |
| A17 | **Licence.** README badge says Proprietary; every M3 interface is SPDX GPL-3.0 and the Decisions Log calls GPL-3.0 "locked by the scaffold". | README vs contracts, Decisions Log | **Needs Fahad → Q21** (bundled with ADR acceptance) |
| A18 | **Branching.** CONTRIBUTING says trunk-based, branch from `main`, no long-running branches; real work lives on `feat/finance-modules` and `main` has none of M1. | CONTRIBUTING vs git | Reported; no vault change |
| A19 | **Build Plan is behind the ADRs:** liboqs 0.12 (ADR 0003 chose PQClean + `slh-dsa`), `packages/contracts`/`apps/api`/`apps/web` (repo has `contracts/`, `apps/client`, `apps/ops-console`), name RWA-Vault vs QORA in `docs/manuals/`. | Build Plan .docx vs ADR 0003, repo | Reported; ADRs win. The .docx is not edited |

## B. Process conflicts (how the vault is kept)

| # | Conflict | Resolution |
|---|---|---|
| B1 | **Agent thread for T6.0 is stale and lossy.** It says "4 intentional failing tests, Coder to apply the 7 rulings"; on disk the rulings are applied and `@rwa-vault/types` runs **32/32 green** (checked 2026-10-27 in a clean build). It lists Ajv as the Debugger's Q7, which drops the real Q7 (E1 missing-field path); the Researcher's answer to E1 exists only in `T6.0 - Researcher Answers (round 2)`. It cites `schema/onboarding.json`; the file is `onboarding-input.schema.json`. | **Fixed** — thread corrected and a `REPORT` entry appended; T6.0 moved to *awaiting Researcher VERIFY* |
| B2 | **Four specs exist twice** (`Research/` and `Specs/`, byte-identical) and a third time in `_Archive/`. Edits to one copy silently diverge. | **Fixed** — `Specs/` is canonical; the `Research/` copies moved to `_Archive/2026-10-27_duplicates/` |
| B3 | **Two competing standards:** `_Templates/Module Folder Template.md` (status emoji, `Research/` handoffs, `Decisions/Open Questions`) vs `AGENTS.md` + `Agents/Protocol.md` (frontmatter status, `Questions/`, `Threads/`, `Specs/`). | **Fixed** — one standard: [[_Templates/00 Vault Standard]]; the old template archived |
| B4 | **Custody questions (C1–C11) live in Project Memory** as one 33 KB note, while M3 questions are one note each. | Left in place (cross-cutting, settled); indexed from the Decisions Register |
| B5 | **The vault is not on GitHub.** Commit `bbc4eb0` is local only and ADRs 0018, 0025, 0026, `IAssetRegistry.sol`, the T6.0 schema and all new vault notes are untracked in the local clone. The working tree also deletes `docs/RWA-Vault_proposal_v2.pdf` and three LinkedIn PNGs without committing it. | **Needs Fahad → Q20** |

## C. ADRs vs the code that actually runs

| ADR | Says | Code on disk | Match |
|---|---|---|---|
| 0003 | Vendored PQClean C + pure-Rust `slh-dsa` | `native/vendor/pqclean/…`, `slh-dsa = "=0.1.0"` | ✅ |
| 0004 | `wasm32-unknown-unknown` + freestanding C shim | `rust-toolchain.toml` target, `wasm-include/`, `wasm_shim.rs` | ✅ |
| 0005 | N-API via napi-rs + offline CLI | `native/napi/`, `native/pqctl/` | ✅ |
| 0007 | OS CSPRNG natively, Web Crypto in WASM, fail closed | `getrandom` (+`js` on wasm32), `rng.rs` marks the operation failed | ✅ |
| 0008 | Runners pinned to `ubuntu-24.04` / `windows-2022` | `ci.yml` uses `ubuntu-latest` / `windows-latest` | ⚠️ drift — floating runners |
| 0011 | Pinned ETHFALCON `ZKNOX_falcon` | not vendored yet (M1 Stage 6 not started) | ⏳ not built |
| 0015 / 0019 | `freeze` agent, `unfreeze` owner (2-of-3) | `IAssetRegistry.sol` NatSpec and errors match | ✅ |
| 0016 | One token per asset, no re-binding | `TokenAlreadyBound`, `AssetAlreadyHasToken` | ✅ |
| 0017 | Reserve via `IReserveAttestationSource`, 4 clauses | interface has `assetId, reserve, seq, valuationTs` only — no insurer/policy | ✅ vs 0017, ❌ vs Q11 (A1) |
| 0018 | τ settable, `MAX_VALUATION_WINDOW` 365 d | `uint64 constant MAX_VALUATION_WINDOW = 365 days`, setters present | ✅ |
| 0019 §5 | `AssetIdMismatch` cross-check | error declared | ✅ |
| 0019 §6 / 0021 | FROZEN and stale reserve block minting only | `packages/types/src/index.ts` comment says minting, redemption **and borrowing** | ❌ stale comment (A11) |
| 0020 | Fine grams everywhere, fineness as a field | `onboarding.ts` has `fineness` (parts per 10,000) and checks `grossWeight × fineness` | ✅ |
| 0025 | Immutable, constructors, no proxies | no implementation contracts yet | ⏳ |
| 0026 | React 18 + Vite + viem in `apps/ops-console` | `apps/ops-console/src/index.ts` stub only | ⏳ not built |

Up: [[00 Dashboard - Project Command Center]] · Related: [[Decisions Register]], [[ADR Index]], [[_Templates/00 Vault Standard]]
