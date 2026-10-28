---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q14
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q14 — What happens when a new attestation shows *less* reserve than the tokens already minted? ⭐ NEW
Raised by the T0.6 research ([[T0.6 - IAssetRegistry Interface]] §2.3); this is the corollary in
[[Mathematics - Admission Predicate and Invariants]] §3 that explicitly says "decide which".

**In plain words:** 1,000 tokens are already in investors' hands. The custodian's next note says the vault only holds
900 tokens' worth of gold. The bad thing has already happened — the question is only what the contract does about it.

- **Option A — Refuse the attestation.** Reserve stays at the old, higher figure. Simple, but it **hides bad news**: the
  chain keeps publishing a reserve the custodian no longer claims.
- **Option B — Accept it, block further mints, emit `UnderReserve`; an operator decides on a freeze.** The chain tells
  the truth, and the master invariant becomes "no new mint while under-reserved".
- **Option C — Accept it and auto-freeze the asset.** Strongest, but one bad attestation (a typo, stale data) halts
  every holder's transfers with no human in the loop — which hands the custodian a denial-of-service switch.
- **Recommendation:** **B.** It keeps the chain honest without letting a single message freeze an asset, and it matches
  the maths note's own original recommendation.
- **Blocks:** T4.2 (`admit` behaviour on a downward attestation) and T4.5 (the exact statement of the invariant).
  **Not a blocker** for T0.6.
- `Decision:` **Option B — accept the attestation, block further mints, emit `UnderReserve`; an operator decides on a freeze.** The chain tells the truth rather than continuing to publish a reserve the custodian has withdrawn, and the master invariant becomes "no new minting while under-reserved". Refusing the attestation (Option A) was rejected because it hides bad news; auto-freezing (Option C) was rejected because one typo or stale feed would trap every holder and hand the custodian a denial-of-service switch. Recorded in ADR `0019`. _(Fahad Naseer, 2026-10-27)_

> ⚠ **Corrected 2026-10-28.** This note previously carried the answer belonging to a different question. The misalignment was introduced on 2026-10-27 when the decision lines were filled in the old monolithic `Open Questions for Fahad.md` by line number; three of them landed one heading too early, and the vault restructure then split that file faithfully, propagating the error. The ADRs were written independently and are correct, so they are the authority here — this note is now reconciled to them.

---