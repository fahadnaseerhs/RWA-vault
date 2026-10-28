---
tags: [rwa-vault, m3, task]
type: task
id: M3-T8
status: queued
agent: researcher
progress: 0/4
updated: 2026-10-27
---
# 📋 Task Group T8 — Custodian Attestation Portal

> **Origin:** Identified during custody session (C1). Signing reserve attestations requires a distinct actor, role, and key hierarchy from provider onboarding (ADR 0015).

### Subtasks Checklist
- [ ] **T8.1** Research note: MS1 simulated custodian actor flow and signing ceremony.
- [ ] **T8.2** ML-DSA-65 envelope generation and submission to `IReserveAttestationSource`.
- [ ] **T8.3** Custodian CLI/screen implementation.
- [ ] **T8.4** On-chain key separation ensuring custodian key is distinct from platform operator key.
- [ ] **T8.5** **Derive and record `seq` per asset — an operational procedure, not code.** [[T0.7 - Reserve Attestation Source]] §4.1 rules that `seq` is a **per-asset** counter and explicitly **not** M2's envelope `nonce` (which is scoped per signer *and action*, and declared `bigint` with no width). Nothing on disk produces a per-asset sequence today, so T8 must define who derives it, from what record, and how a gap or a repeat is detected before submission. Named here rather than left inside the spec because **T8 is the task that has to produce the number**, and a missing procedure is invisible until the MS1 rehearsal and then blocks it.

Up: [[M3 Task Board and Todo]]
