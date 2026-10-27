---
tags: [rwa-vault, module, m3]
phase: 1
sprint: 3
status: interface-scaffolded
---
# M3 — Registry & Compliance ⬜→🟠

> 📂 **Full working folder:** [[Module 3 - Registry & Compliance]] — Understanding, [[Open Questions for Fahad]], [[M3 Task Board and Todo]], [[Mathematics - Admission Predicate and Invariants|the maths]], [[Decision Algorithms - for Fahad]] and [[How to Run Module 3]]. This note is the one-screen summary; the folder is where the work lives.

**Depends on:** [[Module 2 - PQ-PKI & Envelope]] (custodian attestations are ML-DSA-65-signed envelopes)
**Done when:** a provider onboards a gold lot unaided, and a direct-contract transfer that bypasses the API is refused.

**Status (2026-10-27):** ERC-3643 interface suite + `abstract` acceptance spec scaffolded (commit `0b2dd0e`). All ten build decisions are locked (ADRs `0012`–`0017`; see [[Decisions Log]]), so **coding starts at T0.6, T0.7, T1 and T4.1 with nothing blocked**. One new question — **Q11, whether an insurer co-signs the reserve attestation** — is open and affects only the predicate's clause count (T4.2).

Shape as decided: vendor `onchain-id` and build the token, the three registries, ModularCompliance and AssetRegistry in-house; one token per asset; a single `KYC` claim topic; asset liveness enforced by `AssetLiveModule` rather than inside the token; reserve data stubbed behind `IReserveAttestationSource`; `owner` held by a 2-of-3 multisig.

## Tasks
- [ ] `AssetRegistry.sol` state machine: UNREGISTERED → PENDING → LIVE → FROZEN
- [ ] On-chain check of the 4-clause admission predicate: signature valid, sequence increasing, reserve ≥ intended supply, valuation fresh
- [ ] Invariant `attestedSupply ≤ reserveAmount` on every mint and every attestation
- [ ] ERC-3643 (T-REX) bound to AssetRegistry, so no token can exist for an asset that is not LIVE
- [ ] ONCHAINID identity claims plus IdentityRegistry-gated transfers, enforced inside the token
- [ ] Minimal provider console: metadata, valuation basis, custodian, trigger attestation

Prev: [[Module 2 - PQ-PKI & Envelope]] · Next: [[M4 - Vault Accounting]] · Up: [[All Modules]]
