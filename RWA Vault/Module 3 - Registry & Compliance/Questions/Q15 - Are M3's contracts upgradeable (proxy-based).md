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
- `Decision:` **Option A — immutable.** Plain deploys, constructors, no proxy and no storage gaps, for M3 at MS1. The registry already exposes the two knobs we expect to turn (`setAttestationSource`, `setValuationWindowFor`), so the realistic changes need no upgrade, and an upgrade key would be a permanent audit finding and a second centralisation question at the defence on top of the agent powers in ADR `0015`. Stated explicitly *because* ADR `0012` vendors part of Tokeny's proxy-based stack while we build the rest, so silence would let proxies and plain deploys coexist unchosen. Recorded in ADR `0025`. _(Fahad Naseer, 2026-10-27)_

> ⚠ **Corrected 2026-10-28.** This note previously carried the answer belonging to a different question. The misalignment was introduced on 2026-10-27 when the decision lines were filled in the old monolithic `Open Questions for Fahad.md` by line number; three of them landed one heading too early, and the vault restructure then split that file faithfully, propagating the error. The ADRs were written independently and are correct, so they are the authority here — this note is now reconciled to them.

---