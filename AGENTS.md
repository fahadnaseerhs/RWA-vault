# AGENTS.md — Master Agent Protocol & Project Operating System

> **MANDATORY INSTRUCTION FOR ALL AI SESSIONS (Researcher, Coder, Debugger, Architect, Auditor):**
> **"Now you will work in this structure."**
> This document is the master instruction and orientation for RWA-Vault (QORA). Read this completely before inspecting or modifying any file.

---

## 1. Project Essence & Architecture

**Project:** RWA-Vault (QORA / Quantum-Resistant Real-World Asset Tokenisation & Secured Lending Platform)  
**Core Purpose:** Tokenise physical gold (and future real-world assets) into compliant, legally sound on-chain assets with end-to-end post-quantum cryptographic security (PQ-Core) and on-chain compliance (ERC-3643 / T-REX).

### The Four Milestone Gates (True Project Roadmap)

1. **MS1 (Week 6 - Phase 1 Foundation):** A physical gold lot registered and tokenised against an attested reserve in fine grams, verified on-chain via ERC-3643 and post-quantum custodian envelope. (Modules: M0, M1, M2, M3, M4).
2. **MS2 (Week 11 - Phase 2 Investment Path / FYP-I Gate):** PKR 5,000 cash deposit through on-ramp seam → Merkle proof generated → offline verification succeeds without platform holding fiat. (Modules: M5, M8, M9).
3. **MS3 (Week 19 - Phase 3 Lending & Risk):** Borrow against tokenised gold → simulated price drop → risk engine liquidation buffer triggered, resulting in zero bad debt. (Modules: M6, M7, M10).
4. **MS4 (Week 24 - Phase 4 Thesis Gate):** Empirical evaluation harness executing all cryptographic, gas, and latency benchmarks proving research claims. (Module: M11).

---

## 2. Structure Rules & Anti-Drift Contract (Non-Negotiable)

1. **Single Source of Truth (No Status Prose):**
   - The status of any Question, Task, or Decision lives **only in its respective note frontmatter**.
   - NEVER write status prose across 5 different notes (e.g., do not write "Q11 is open..." in task boards or readmes). Use frontmatter or link directly.
2. **No Memory Loss — Append-Only Thread Chat:**
   - Conversations, debate rounds, questions, and handoffs between agents do not live in scattered, arbitrary scratch notes.
   - Every active task has a dedicated thread in `Module <N>/Threads/Thread - <Task>.md`.
   - All agent communication follows the structured message envelope:
     ```markdown
     ### YYYY-MM-DD HH:MM · 🎭 [Role] → 🎭 [Role] · [ACTION_TYPE]

     **Context:** <task/bug context>
     **On Disk Now:** `<file>:<line>` → `<code>` (Always quote exact on-disk code, not intent)
     **Message/Question/Finding:** <concise, high-density content>
     **Blocks/Unblocks:** <target>
     ```
     _Permitted Action Types:_ `PLAN`, `HANDOFF`, `REPORT`, `ASK`, `RULING`, `VERIFY ✅`.
3. **ADR Claim-By-File Protocol:**
   - ADR numbers cannot be assumed or promised in conversation.
   - The **only** way to claim an ADR number is to commit a stub file in `docs/adr/00XX-<slug>.md` with `Status: Reserved`.
   - Never renumber or reuse an ADR number.
4. **The Non-Negotiable Done Rule:**
   - A task is checkmarked **only when the Researcher verifies that all acceptance criteria are demonstrably met on disk**.
   - The Coder saying "it compiles" or "tests pass" is NOT done.
   - Debuggers never invent intended behavior. Ambiguity always routes back to the Researcher via an `ASK` in the thread.

---

## 3. The 3-Agent Operational Loop

```
                     ┌──────────────────────────────────────────────────────────────┐
                     │                                                              │
TASK (from Board) ──►│ 🧭 RESEARCHER (Owns WHAT & WHY)                              │
                     │    - Reads ADRs, math predicates, standards                  │
                     │    - Formulates Plan + Runnable Acceptance Criteria (AC)     │
                     └──────────────┬───────────────────────────────────────────────┘
                                    │ Plan + AC
                                    ▼
                     ┌──────────────────────────────────────────────────────────────┐
                     │ ⌨️ CODER (Owns HOW)                                          │
                     │    - Implements strictly against interface definitions       │
                     │    - Writes unit & boundary tests                            │
                     │    - Emits clean compiles & test runs                        │
                     └──────────────┬───────────────────────────────────────────────┘
                                    │ Code + Test Results
                                    ▼
                     ┌──────────────────────────────────────────────────────────────┐
                     │ 🐞 DEBUGGER (Owns CLOSING GAP TO GREEN)                      │
                     │    - Isolates failures to invariants & clauses               │
                     │    - Mechanical bug? → Gives minimal diff back to Coder      │
                     │    - Ambiguous behavior? → ASKS Researcher (No guessing!)   │
                     └──────────────┬───────────────────────────────────────────────┘
                                    │ Criteria Met
                                    ▼
                     ┌──────────────────────────────────────────────────────────────┐
                     │ ✅ RESEARCHER VERIFICATION (Checkmarks task & logs ADR)      │
                     └──────────────────────────────────────────────────────────────┘
```

---

## 4. Key Architectural Constants & Locked Invariants

- **Token Standard:** ERC-3643 (T-REX), Hybrid implementation: vendor `onchain-id` ERC-734/735, custom Token, Registries, and `ModularCompliance`.
- **Token Unit:** 1 Token = 1 **fine gram** of gold ($10^{18}$ base units). A 1 kg kilobar of 999.9 purity yields exactly $999.9 \times 10^{18}$ units (ADR 0020).
- **Valuation Window ($\tau$):** Default 24 hours for gold. In tests, parameterized via `setValuationWindowFor` to $\le 1$ hour. Never hardcode 24h into invariant checks (ADR 0018).
- **Asset Admission Predicate — 4 clauses (ADR 0017). A 5th insurer/policy clause is NOT locked: it depends on open decision Q17, and where clause 1's ML-DSA-65 signature is checked depends on Q18:**
  1. $SigValid(attestation, pk_{custodian})$ (+ $pk_{insurer}$ only if Q17 keeps the 2-of-2).
  2. $Seq(attestation) > lastSeq(assetId)$ (Strictly monotonic sequence).
  3. $reserveAmount \ge attestedSupply$ (Never fractional; 100% reserve backing).
  4. $now - valuationTs \le \tau \land valuationTs \le now$ (Fresh, no future timestamps).
  5. _(Only if Q17 keeps the 2-of-2)_ $policyCoverage \ge attestedValue \land policyExpiry > now$.
- **Immutability:** No upgradeable proxies. Plain deployments with immutable constructor wiring (ADR 0025).
- **Freezing Semantics:** `FROZEN` blocks **minting only**; `AssetLiveModule` vetoes a mint, never a transfer. Investor transfers and exits stay enabled. A stale reserve also blocks minting only (ADR 0019 §6, ADR 0021).
- **Post-Quantum Cryptography Inventory (M1 owns all six):**
  - Signatures: Falcon-padded-512, ML-DSA-44, ML-DSA-65, SLH-DSA-SHA2-128s.
  - KEM: ML-KEM-768, ML-KEM-1024.

---

## 5. Navigation & File Organization

```
RWA Vault/
├── 00 Dashboard - Project Command Center.md    ← Live high-level status of entire project
├── _Templates/                                 ← 🔒 LOCKED: 00 Vault Standard + templates (decision, task, thread, concept, hub)
├── Project Memory/
│   ├── Project Modules To-Do (True Values).md  ← Verified code census & state of M0..M11
│   ├── Decisions Register.md                   ← Every decision, open and decided, in one table
│   ├── Audits/                                 ← Dated decision-conflict audits
│   ├── ADR Index.md                            ← Canonical ADR register (0001–0026)
│   ├── Changelog.md                            ← Concise, dated milestone log
│   └── ...
├── Agents/
│   ├── Protocol.md                             ← Human-readable Agent operating rules
│   ├── Researcher Agent.md
│   ├── Coder Agent.md
│   └── Debugger Agent.md
└── Module 3 - Registry & Compliance/
    ├── 00 M3 Dashboard.md                      ← Module 3 command center
    ├── Questions/                              ← Q01 to Q22 (one Decision note per question)
    ├── Tasks/                                  ← T0 to T8 task group notes
    ├── Threads/                                ← Append-only agent threads; long rounds in Threads/Rounds/
    ├── Specs/                                  ← Deep technical specifications
    ├── Algorithms/                             ← Mathematical predicates & decision trees
    └── Understanding/                          ← Conceptual walkthroughs
```
