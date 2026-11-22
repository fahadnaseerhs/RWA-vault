---
type: task
id: M1-T0
module: M1
stage: 0
status: in-review
agent: coder
progress: 3/3
depends_on: []
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T0 — Decision follow-through

**In plain words:** make the code changes that the ADRs (0002–0011) require. All three tasks are small and block Stage 1.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Researcher VERIFY ✅ against acceptance criteria | task | 🧭 Researcher | VERIFY entry in the thread |

## Subtasks
- [x] **S0-01** Split the algorithm union in `src/index.ts` into `PqSignatureAlgorithm` (4) + `PqKemAlgorithm` (2); add `ml-kem-768` and `ml-kem-1024`
  - Done when: `pnpm typecheck` is green and an exhaustive `switch` compiles with no `default` arm
- [x] **S0-02** Retarget `envelope-codec`: `PqEnvelope.algorithm` becomes `PqSignatureAlgorithm`, since an envelope is never signed by a KEM
  - Done when: assigning `"ml-kem-768"` is a type error
- [x] **S0-03** Set `evm_version` explicitly in `contracts/foundry.toml` (ADR 0008). It is set to `cancun`.
  - Done when: `forge build` succeeds and the value appears in `forge config`

## Acceptance criteria (runnable by a third party)
> _Not written yet. The Researcher writes these as a `PLAN` entry in the thread before the Coder starts. Without them no `VERIFY ✅` is possible, so this task cannot reach `done`._

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Next: [[T1 - Crate skeleton and Falcon slice]]
