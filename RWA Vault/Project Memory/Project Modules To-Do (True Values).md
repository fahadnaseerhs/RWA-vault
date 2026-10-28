---
tags: [rwa-vault, project-memory, roadmap, tasks, true-values]
updated: 2026-10-27
---
# 📊 Project Modules To-Do List — Verified True Values

> **Zero Guesswork Guarantee:** Every status, task count, and metric below was verified directly against the repository codebase (`apps/`, `services/`, `packages/`, `contracts/`, `infra/`), git history (`git log`, `git branch -a`, `git status`), and active test suites as of **2026-10-27 23:20 PKT**.

---

## Executive Summary & Milestone Progress

```
[Phase 1: Foundation & Crypto Core (W1–W6)] ═══════════════► MS1 Gate: Gold lot tokenised with PQ attestation
  ├── M0 Foundation & Devnet       : 🟡 57% Done (4/7 tasks)
  ├── M1 Post-Quantum Core         : 🔵 49% Done (50/102 tasks; Stages 0–2 complete, Stage 3 12/15)
  ├── M2 PQ-PKI & Envelope Codec   : 🟠 10% Skeleton (PqEnvelope type & condition list exist)
  ├── M3 Registry & Compliance     : 🔵 25% Interface & Scaffold Done (T0.6 verified; 16 decisions locked)
  └── M4 Vault Accounting          : ⬜ 0% Not Started (Queued for Sprint 3)

[Phase 2: Investment Path (W7–W11)] ──────────────────────► MS2 Gate: PKR 5,000 deposit → offline Merkle proof
  ├── M5 Oracle & Proof-of-Reserve : ⬜ 0% (Types scaffolded)
  ├── M8 Settlement Rail (Fiat)    : ⬜ 0% (Seam architecture designed; ADR 0022)
  └── M9 Anchoring & Audit         : ⬜ 0% (Batcher stub exists)

[Phase 3: Lending & Risk (W12–W19)] ──────────────────────► MS3 Gate: Borrow → Price Drop → Liquidation buffer
  ├── M6 Risk Engine               : ⬜ 0% (Service stub exists)
  ├── M7 Lending & Liquidation     : ⬜ 0% (ADR 0023/0024 aligned)
  └── M10 Client Interfaces        : ⬜ 5% (App shells exist in apps/client and apps/ops-console)

[Phase 4: Evaluation & Thesis (W20–W24)] ─────────────────► MS4 Gate: Empirical benchmark evaluation report
  └── M11 Evaluation Harness       : ⬜ 5% (Python venv and Jupyter skeleton in eval/)
```

---

## Detailed True-Value Breakdown Per Module

### M0 — Foundation & Devnet
- **True Status:** 🟡 Mostly Done (4 of 7 tasks verified)
- **On-Disk Reality:**
  - `pnpm-workspace.yaml`, Node 22 LTS, TypeScript project references wired (`f15f5e0`).
  - Foundry initialized with `OpenZeppelin 5.x` and `forge-std` submodules.
  - `infra/docker-compose.yml` operational: Anvil, PostgreSQL 16, Redis 7.
  - GitHub Actions CI workflow in `.github/workflows/ci.yml` running Forge build, fmt, test, invariant jobs, and PQ-Core build.
- **Pending Tasks (To-Do):**
  - [ ] Deploy scripts targeting Arbitrum Sepolia in `contracts/script/` (currently empty).
  - [ ] Self-hosted alternatives documentation for free-tier infrastructure dependencies.
  - [ ] Verification of GitHub branch protection rules (2-reviewer requirement).

---

### M1 — Post-Quantum Core (`packages/pq-core`)
- **True Status:** 🔵 In Progress — **50 / 102 tasks complete**
- **Code Census:**
  - Rust crate: 4,374 lines of Rust across `native/src/` (`algorithms.rs`, `falcon.rs`, `mldsa.rs`, `mlkem.rs`, `slhdsa.rs`, `rng.rs`, `wasm.rs`, `wasm_shim.rs`, `kat.rs`, `error.rs`).
  - Native N-API bindings: `packages/pq-core/native/napi/src/lib.rs` (289 lines).
  - CLI: `packages/pq-core/native/pqctl/src/main.rs` (92 lines).
  - TypeScript wrappers: 690 lines across `src/index.ts`, `native.ts`, `wasm.ts`, `metadata.ts`, `errors.ts`.
  - All 6 NIST algorithms functional: Falcon-512, ML-DSA-44, ML-DSA-65, SLH-DSA-SHA2-128s, ML-KEM-768, ML-KEM-1024.
- **Stage Completion Table:**
  | Stage | Name | Total Tasks | Completed | Real Status |
  |---|---|---|---|---|
  | Stage 0 | Decision follow-through | 3 | **3** | ✅ 100% |
  | Stage 1 | Crate skeleton & Falcon slice | 18 | **18** | ✅ 100% (`afe574c`) |
  | Stage 2 | Full algorithm matrix | 17 | **17** | ✅ 100% (`e13b18a`) |
  | Stage 3 | Runtime adapters (Node + WASM) | 15 | **12** | 🟡 80% (Core adapters merged `7eb5fc8`) |
  | Stage 4 | NIST CAVP/ACVP Conformance | 18 | **0** | ⬜ Ready to start |
  | Stage 5 | Benchmarks (Latency/Gas) | 12 | **0** | ⬜ Blocked on S4 |
  | Stage 6 | ETHFALCON Dispute Verifier | 10 | **0** | ⬜ Blocked on S4 |
  | Stage 7 | Release Gate & Packaging | 9 | **0** | ⬜ Final stage |
- **Remaining Stage 3 Tasks (Immediate To-Do):**
  - [ ] **S3-05:** Prebuild CI for Linux + Windows native N-API binaries.
  - [ ] **S3-10:** Cross-adapter contract-equivalence test running identical suite against both WASM and native.
  - [ ] **S3-13:** Implement `pnpm test` suite in `packages/pq-core` replacing placeholder.

---

### M2 — PQ-PKI & Envelope (`packages/envelope-codec`, `services/pq-verifier`)
- **True Status:** 🟠 Skeleton / Specification Phase
- **On-Disk Reality:**
  - `packages/envelope-codec/src/index.ts` defines `PqEnvelope` interface (36 lines).
  - `services/pq-verifier/src/index.ts` lists the 7 named verification conditions (16 lines).
  - Contracts in `contracts/src/keys/` are not yet created.
- **Key Blockers:** Depends on M1 Stage 3 completion (`native/napi` bridge).
- **Core To-Do:**
  - [ ] **T0:** `IPQKeyRegistry.sol` interface + canonical envelope binary serialization ADR.
  - [ ] **T1:** `PQKeyRegistry.sol` implementation with 3-tier hierarchy (Tier 0 SLH-DSA, Tier 1 ML-DSA-65, Tier 2 Falcon-512).
  - [ ] **T3:** Dual TS/Rust byte-identical canonical serializer/deserializer.
  - [ ] **T4:** 7-condition stateless verification service (`services/pq-verifier`).
  - [ ] **T6:** Adversarial replay test harness.

---

### M3 — Registry & Compliance (`contracts/src/`, `packages/types`)
- **True Status:** 🔵 Active Build Sprint — Scaffold Complete, Decisions 100% Locked
- **Decisions Locked:** **16 of 16 Decided** (Q1–Q16 closed 2026-10-27; Ajv approved as devDependency).
- **Code Census:**
  - ERC-3643 interface suite in `contracts/src/` (8 interfaces, 497 lines).
  - Acceptance suite in `contracts/test/registry/ERC3643Acceptance.t.sol` (97 lines, 6 guarantees).
  - AssetRegistry interface: `IAssetRegistry.sol` (259 lines, 12 views, 3 agent, 7 owner, 11 events, 21 errors, 22 selectors).
  - Reserve seam interface: `IReserveAttestationSource.sol` (52 lines).
  - Verification suite: `contracts/test/registry/AssetRegistryInterface.t.sol` (163 lines, 6/6 tests passing).
  - Types & Schema: `packages/types/src/onboarding.ts` (394 lines) + parity tests (318 lines).
- **Immediate Task Board:**
  - [x] **T0.6:** `IAssetRegistry.sol` & `AssetRegistryMock` verified clean through 2-round loop.
  - [ ] **T0.7:** Complete research and spec note for `IReserveAttestationSource.sol`.
  - [ ] **T1.1:** Vendor `onchain-id` ERC-734/735 as Git submodule (Q1=C).
  - [ ] **T1.3–T1.5:** Implement `ClaimTopicsRegistry`, `TrustedIssuersRegistry`, and `IdentityRegistry`.
  - [ ] **T2.2:** Implement `AssetLiveModule.sol` (vetoes **mints** unless asset is LIVE; transfers continue — ADR 0019 §6).
  - [ ] **T4.1:** Implement `AssetRegistry.sol` state machine (`UNREGISTERED` → `PENDING` → `LIVE` → `FROZEN`).
  - [ ] **T4.2:** Implement the admission predicate (4 clauses per ADR 0017; 5th only if Q17 keeps the insurer 2-of-2).
  - [ ] **T6.0:** Batch 2 applied and 32/32 green on disk (2026-10-27) — awaiting Researcher VERIFY.
  - [ ] **T6.1a:** Forge onboarding script `contracts/script/OnboardAsset.s.sol`.

---

### M4 — Vault Accounting
- **True Status:** ⬜ Not Started (Scheduled for Phase 1 close)
- **Scope (Build Plan):** `AssetVault.sol`, an OpenZeppelin ERC-4626 subclass with `_decimalsOffset() = 6`, explicit rounding on all four conversions, donation-attack hardening, 10⁶-sequence fuzzing and a Halmos proof. Holds ERC-3643 units of a LIVE asset, so it waits on M3's token.

---

### M5 — Oracle & Proof-of-Reserve
- **True Status:** ⬜ Not Started (Phase 2 entry point)
- **Scope:** Custodian attestation ingestion, LBMA gold price feeds via push oracle, valuation freshness verification. Implements `IReserveAttestationSource`.

---

### M6 to M11 — Downstream Modules
- **M6 (Risk Engine):** Service shell in `services/risk-engine/` (15 lines). Blocked on M4 + M5.
- **M7 (Lending & Liquidation):** Collateralized loan contracts. Blocked on M6.
- **M8 (Settlement Rail):** Cash-settled fiat on-ramp integration seam (ADR 0022). Zero fiat custody.
- **M9 (Anchoring & Audit):** Merkle tree batcher in `services/anchor-batcher/` (16 lines).
- **M10 (Clients):** App shells in `apps/client/` and `apps/ops-console/`.
- **M11 (Evaluation Harness):** Python 3.12 environment with Jupyter setup in `eval/` for thesis benchmarking.

---

## Repository & Git Health (True Values)

- **Active Tracking Branch:** `feat/finance-modules` (Commit `bbc4eb0` local, ahead of remote origin).
- **Remote Branches:**
  - `origin/main` (Production target)
  - `origin/codex/module-1` (Contains verified M1 Stage 3 adapters)
  - `origin/feat/finance-modules` (Active M3 workspace)
- **Uncommitted High-Value Artifacts on Disk:**
  - `contracts/src/registry/interfaces/IAssetRegistry.sol`
  - `contracts/src/registry/interfaces/IReserveAttestationSource.sol`
  - `contracts/test/registry/AssetRegistryInterface.t.sol`
  - `packages/types/src/onboarding.ts` & test suite
  - `docs/adr/0018-valuation-freshness-window.md`
  - `docs/adr/0025-immutable-deployments.md`
