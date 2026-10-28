---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q06
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q6 — Which transfer-restriction compliance modules do we actually implement?
**Why it matters:** ModularCompliance can hold many modules (max-holders, country-restrict, daily-limit, lockup). Each is real work. The acceptance spec needs none of them beyond the identity gate.
- **Option A — Only the AssetRegistry "is-LIVE" module (from Q4). No extra restriction modules.** Minimal; passes the acceptance spec.
- **Option B — Add one showcase module, e.g. `CountryRestrictModule` or `MaxHoldersModule`,** to demonstrate the pluggable design.
- **Recommendation:** **Option A** for the MS1 deadline; add Option B's one module only if time remains, as it strengthens the thesis.
- **Blocks:** scope of the compliance work, extra tests.
- `Decision:` **Option A** — only the AssetRegistry is-LIVE module for MS1. Evaluate the official `SupplyLimitModule` as a near-free way to enforce `attestedSupply ≤ reserveAmount`. No `CountryRestrictModule`. Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_