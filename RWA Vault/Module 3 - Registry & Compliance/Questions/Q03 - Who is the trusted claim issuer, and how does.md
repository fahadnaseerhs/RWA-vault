---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q03
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q3 — Who is the trusted claim issuer, and how does it tie to the M2 PQ attestation?
**Why it matters:** ERC-3643 claims are signed by an issuer (ECDSA on-chain). M2 attestations are **ML-DSA-65 PQ envelopes**. These are two different signature worlds. We must decide where the PQ story lives.
- **Option A — Issuer is a plain ECDSA KYC service; PQ is used only for the custodian *reserve* attestation in AssetRegistry (not for investor claims).** Cleanest separation: investor-eligibility = ECDSA claims, asset-reserve = PQ envelope. Recommended.
- **Option B — Investor claims are also backed by a PQ envelope** verified via the M2 verifier before the on-chain claim is accepted. Stronger "PQ everywhere" thesis, much more plumbing, and M2 is still skeleton-only.
- **Recommendation:** **Option A.** Keep investor claims standard ERC-3643; concentrate PQ at the AssetRegistry reserve attestation, which is the project's distinctive contribution.
- **Blocks:** Trusted Issuers Registry impl, the issuer key setup, the AssetRegistry ↔ M2 binding, and depends on how much of M2 is ready.
- `Decision:` **Option A** — investor eligibility is standard ECDSA ERC-3643 claims from one project KYC issuer; PQ (ML-DSA-65) is confined to the custodian reserve attestation in AssetRegistry. ADR `0013`. _(Fahad Naseer, 2026-10-27)_