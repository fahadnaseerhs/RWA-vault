---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q15
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q15 — Are M3's contracts upgradeable (proxy-based) or immutable? ⭐ NEW
Raised by the T0.6 research ([[T0.6 - IAssetRegistry Interface]] §10). **No ADR covers this**, which is the problem:
Tokeny's upstream T-REX is proxy-based with an implementation authority, and ADR `0012` has us vendoring part of that
stack while building the rest — so we could end up with proxies on one half and plain deploys on the other without
ever having decided to.

**In plain words:** if we find a bug in the admission predicate after launch, do we patch the contract in place, or
does every token holder have to migrate?

- **Option A — Immutable.** Plain deploys. A bug means a new deployment and a migration.
- **Option B — Proxy (UUPS or transparent), matching upstream T-REX.** Bugs are patchable in place; the upgrade key
  becomes a permanent audit finding and a centralisation question at the defence.
- **Recommendation:** **A (immutable) for MS1.** The registry already exposes the two knobs we actually expect to turn
  — `setAttestationSource` and `setValuationWindowFor` — so the realistic changes need no upgrade. Record it as an ADR
  either way: "we never decided" is the worst answer to this question in a viva.
- **Blocks:** **T4.1** (initializer vs constructor, storage gaps) and T5.1's deploy script. **Not a blocker** for
  T0.6/T0.7 — interfaces have no constructor or storage, so they are proxy-agnostic.
- `Decision:` **Option A — FROZEN blocks minting only; transfers continue.** Confirmed, not inherited: holders keep their exit even when the asset is frozen, whether the freeze came from staleness, a legal hold or an incident. This affirms the Researcher's ruling (ADR `0019` decision 6, superseding ADR `0014`'s "or transfer") and matches C9 reached independently on the staleness path. `pause` remains the mechanism for the systemic case and per-wallet freeze for the targeted one, so FROZEN does not duplicate either. _(Fahad Naseer, 2026-10-27)_

---