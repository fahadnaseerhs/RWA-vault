---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q04
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q4 — Is "asset is LIVE" a Compliance Module, or a mint-time check in the token?
**Why it matters:** this is *how the two halves of M3 join* (see [[00 - What is Module 3]]). It sets the AssetRegistry's interface and the token wiring.
- **Option A — AssetRegistry is read by a Compliance Module (`IModule`) plugged into ModularCompliance.** Idiomatic ERC-3643 — all transfer rules live in one place, pluggable, testable. Recommended.
- **Option B — The token checks `assetRegistry.isLive(assetId)` directly in `mint`/`transfer`.** Simpler to reason about, but hard-wires the asset concept into the token and departs from the standard.
- **Recommendation:** **Option A** — keeps the token standard and puts our custom logic in a module, which is exactly what ModularCompliance is for.
- **Blocks:** `IAssetRegistry.sol` shape, the compliance module list, and the invariant test wiring.
- `Decision:` **Option A** — `AssetLiveModule` (`IModule`) bound to ModularCompliance reads AssetRegistry; the token stays standard and never references assets. ADR `0014`. _(Fahad Naseer, 2026-10-27)_