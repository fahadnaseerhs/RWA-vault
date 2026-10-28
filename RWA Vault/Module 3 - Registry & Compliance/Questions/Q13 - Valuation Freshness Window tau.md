---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q13
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q13 — How long is a valuation "fresh"? (the value of τ) ⭐ NEW
Raised by the T0.6 research ([[T0.6 - IAssetRegistry Interface]] §8). Clause 4 of the admission predicate rejects an
attestation whose valuation is older than τ. The interface exposes τ as an owner-set value (`valuationWindow()` /
`setValuationWindow`), so T0.6 does not need the number — but T4.2 and its boundary tests do.

**In plain words:** the custodian's note says "as of 2 p.m. today". How old is too old to trust?

- **Option A — 24 hours.** Matches daily LBMA pricing; tolerant of a custodian who signs once a day, in another timezone.
- **Option B — 1 hour.** Aligns with the M2 envelope's 3600 s validity; forces near-real-time attestations.
- **Option C — per asset class** (gold 24 h, T-bills 24 h, REIT 90 days). Right long-term; nothing in MS1 needs it.
- **Recommendation:** **A (24 h)** for MS1, set via `setValuationWindow` so a change later is configuration, not code.
  Record the chosen number in ADR `0019`.
- **Blocks:** T4.2 and its boundary tests. **Not a blocker** for T0.6 — the interface only exposes the setter.
- `Decision:` **Option A — τ = 24 hours** for gold in production, set through `setValuationWindowFor` so a change is configuration, not code.
  **Explicit test carve-out:** a unit test cannot wait 24 hours, so the boundary tests set a **short window (1 hour or less) via the setter** and exercise the clause against that. The 24 h value is the deployed default, not a constant baked into the predicate — which is precisely why the setter exists. T4.2's tests must assert the *boundary behaviour* at whatever τ is configured, never a hard-coded 24 h. _(Fahad Naseer, 2026-10-27)_

---