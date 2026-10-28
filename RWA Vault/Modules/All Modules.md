---
tags: [rwa-vault, moc, modules]
updated: 2026-09-26
---
# All Modules

Source: `docs/manuals/QORA_Module_Build_Plan.docx`. 12 modules, 13 two-week sprints, 4 phases, 4 milestone gates.

## 1. Module list

| #   | Module                                    | Phase              | Sprint | Status |
| --- | ----------------------------------------- | ------------------ | ------ | ------ |
| M0  | [[M0 - Foundation & Devnet]]              | 1 Foundation       | 1      | 🟡 Mostly done (deploy scripts missing) |
| M1  | [[Module 1 - PQ Core]]                    | 1 Foundation       | 1–2    | 🔵 In progress: Stages 0–2 done, Stage 3 in progress (49/102) |
| M2  | [[Module 2 - PQ-PKI & Envelope]]          | 1 Foundation       | 2–3    | 🟠 Skeleton only |
| M3  | [[M3 - Registry & Compliance]]            | 1 Foundation       | 3      | 🔵 Interfaces scaffolded (`0b2dd0e`); 9/10 decisions locked (ADRs 0012–0016), Q5 open |
| M4  | [[M4 - Vault Accounting]]                 | 1 Foundation       | 3      | ⬜ Not started |
| M5  | [[M5 - Oracle & Proof-of-Reserve]]        | 2 Investment Path  | 4–5    | ⬜ Not started |
| M8  | [[M8 - Settlement Rail]]                  | 2 Investment Path  | 4      | ⬜ Not started |
| M9  | [[M9 - Anchoring & Audit]]                | 2 Investment Path  | 4–5    | ⬜ Not started |
| M6  | [[M6 - Risk Engine]]                      | 3 Lending & Risk   | 7–8    | ⬜ Not started |
| M7  | [[M7 - Lending & Liquidation]]            | 3 Lending & Risk   | 8–10   | ⬜ Not started |
| M10 | [[M10 - Clients]]                         | 3 Lending & Risk   | 7–10   | ⬜ Not started (app shells exist) |
| M11 | [[M11 - Evaluation Harness]]              | 4 Evaluation       | 11–13  | ⬜ Not started |

(Ordered by phase. M8 and M9 come before M6 because the build plan puts them in Phase 2.)

## Phases and gates

| Phase | Weeks | Modules | Gate |
| ----- | ----- | ------- | ---- |
| 1 Foundation & Crypto Core | 1–6 | M0–M4 | **MS1 (wk 6)**: a gold lot registered and tokenised against an attested reserve |
| 2 Investment Path | 7–11 | M5, M8, M9 | **MS2 (wk 11, FYP-I)**: PKR 5,000 deposit → Merkle proof verifies offline |
| 3 Lending & Risk | 12–19 | M6, M7, M10 | **MS3 (wk 19)**: borrow → price drop → buffer/liquidation, zero bad debt |
| 4 Evaluation & Thesis | 20–24 | M11 | **MS4 (wk 24)**: every research question answered with measured data |

## Dependency chain

```
M0 → M1 → M2 → M3 → M4
              M2 → M5 (+M3)      M4 → M8      M2 → M9
                   M5 + M4 → M6 → M7
              M3, M4, M7 interfaces → M10
                        M0–M10 → M11
```

**M1 → M2 is the critical path.** M2 is blocked on M1, and nearly everything else is blocked on M2.

## Rules for every module
- Open with an **interface-only PR**, approved by its consumers before any implementation.
- The dependency set must be acyclic, and the acceptance test must be runnable by a third party.
- Contract changes must pass the Foundry invariant suite and get two approvals.
- Write an ADR in `docs/adr/` for every non-obvious decision.

Related: [[Project Memory]], [[Roadmap & Milestones]]
