---
tags: [rwa-vault, m3, task]
type: task
id: M3-T1
status: ready
agent: coder
progress: 0/6
unblocked_by: ["Q01=C", "Q02=A", "Q03=A"]
updated: 2026-10-27
---
# 📋 Task Group T1 — Identity Layer (ONCHAINID + Registries)

> **Decisions Applied:** Q1=C (Vendor onchain-id, build registries), Q2=A (Single KYC claim topic), Q3=A (ECDSA claims).  
> **Status:** Unblocked and ready for Coder implementation.

### Subtasks Checklist
- [ ] **T1.1** Vendor `onchain-id` as git submodule (`Identity` + `ClaimIssuer` from upstream, reconciled to `solc 0.8.26`).
- [ ] **T1.2** `ClaimIssuer` adapter tests.
- [ ] **T1.3** `ClaimTopicsRegistry` implementation seeded with single `KYC` topic (Q2=A).
- [ ] **T1.4** `TrustedIssuersRegistry` binding ECDSA project KYC issuer to `KYC` topic (Q3=A).
- [ ] **T1.5** `IdentityRegistryStorage` + `IdentityRegistry` with working `isVerified(address)`.
- [ ] **T1.6** Unit test matrix: verified/unverified wallets, revoked claims, wrong issuer, country update.

Up: [[M3 Task Board and Todo]]
