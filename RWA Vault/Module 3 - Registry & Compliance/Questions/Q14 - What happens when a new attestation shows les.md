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
- `Decision:` **Option A — immutable.** Plain deploys, constructors, no proxy and no storage gaps, for M3 at MS1. The registry already exposes the two knobs we expect to turn (`setAttestationSource`, `setValuationWindowFor`), so the realistic changes need no upgrade, and an upgrade key would be a permanent audit finding and a second centralisation question at the defence on top of the agent powers in ADR `0015`. **Needs its own ADR**, per the note's own point that "we never decided" is the worst answer in a viva — and it must be stated explicitly *because* ADR `0012` vendors part of Tokeny's proxy-based stack while we build the rest, so silence would let proxies and plain deploys coexist unchosen. _(Fahad Naseer, 2026-10-27)_

---