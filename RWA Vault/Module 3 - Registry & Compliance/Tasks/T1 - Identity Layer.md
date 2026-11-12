---
tags: [rwa-vault, m3, task]
type: task
id: M3-T1
status: done
agent: coder
progress: 6/6
unblocked_by: ["Q01=C", "Q02=A", "Q03=A"]
closed_on: 2026-11-12
commit: 61f2e90
updated: 2026-11-12
---
# 📋 Task Group T1 — Identity Layer (ONCHAINID + Registries) ✅

> **Decisions Applied:** Q1=C (Copy-vendor onchain-id, ADR 0031), Q2=A (Single KYC claim topic), Q3=A (ECDSA claims), Q27=B (MAX_CLAIM_TOPICS=5), Q28=A (6 guarantees).  
> **Status:** Done. All 35 acceptance criteria verified. 115/115 tests pass. Committed `61f2e90`.

### Subtasks Checklist
- [x] **T1.1** Copy-vendor `onchain-id` 2.2.1 with pragma rewrite ^0.8.20, PROVENANCE.json, DIGESTS.sha256, verify script (ADR 0031).
- [x] **T1.2** `ClaimIssuer` adapter tests (7 tests with real vendored Identity + ClaimIssuer, deterministic key).
- [x] **T1.3** `ClaimTopicsRegistry` — KYC permanent (ADR 0029), MAX_CLAIM_TOPICS=5 (Q27=B), guard ordering proven by invariant.
- [x] **T1.4** `TrustedIssuersRegistry` — per-topic issuer index, MAX_ISSUERS_PER_TOPIC=10, `hasClaimTopic` (not `isTrustedIssuer`).
- [x] **T1.5** `IdentityRegistryStorage` (shared address book) + `IdentityRegistry` (`isVerified` implementing spec §7).
- [x] **T1.6** 115 tests across 7 suites: unit, invariant (CI: 256×500), integration, acceptance (abstract, compiles clean).

### Deliverables
- 4 production contracts: `ClaimTopicsRegistry`, `TrustedIssuersRegistry`, `IdentityRegistryStorage`, `IdentityRegistry`.
- 9 copy-vendored onchain-id files with provenance tracking.
- 2 vendor scripts (`vendor-onchain-id.sh`, `verify-vendor-onchain-id.sh`).
- Gas measured: `isVerified` at 1 topic = 93k (cold), at cap of 5 = 302k (cold), PKR 3.44/transfer on Arbitrum.

Up: [[M3 Task Board and Todo]] · Thread: [[Thread - T1 Identity Layer]] · Spec: [[T1 - Identity Layer]]
