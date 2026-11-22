---
type: task
id: M1-T7
module: M1
stage: 7
status: blocked
agent: researcher
progress: 0/9
depends_on: [M1-T4, M1-T5, M1-T6]
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T7 — Release gate

**In plain words:** a supply-chain-checked, tagged release of the library and all artefacts, with conformance, benchmark and gas reports attached.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Stages 4, 5 and 6 complete | task | Coder | T4, T5 and T6 status are `done` after Researcher VERIFY |

## Subtasks
- [ ] **S7-01** `deny.toml` + `cargo deny` in CI (licences + advisories)
- [ ] **S7-02** SBOM (CycloneDX + `pnpm licenses`)
- [ ] **S7-03** `metadata.json` + `SHA256SUMS` emitter (ADR 0008 fields)
- [ ] **S7-04** CI job `pq-artifacts` (tags only): addon prebuilts, WASM package, `pqctl`
- [ ] **S7-05** `kat`-absence assertion in the release job (hard failure)
- [ ] **S7-06** Weekly scheduled `cargo deny` / `pnpm audit`
- [ ] **S7-07** Path filters on the four M1 CI jobs
- [ ] **S7-08** `packages/pq-core/README.md` covers the six items in manual §9
- [ ] **S7-09** Tag the library and artefacts together at one commit, with all reports

## Acceptance criteria (runnable by a third party)
> _Not written yet. The Researcher writes these as a `PLAN` entry in the thread before the Coder starts. Without them no `VERIFY ✅` is possible, so this task cannot reach `done`._

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Prev: [[T6 - ETHFALCON dispute verifier]]
