---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q08
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q8 — One token per asset (TokenFactory), or a shared multi-asset token?
**Why it matters:** ERC-3643 is **one token contract per asset** by design. A gold lot and a property share would be separate tokens. Confirm the pattern and whether we need a factory for the demo.
- **Option A — One ERC-3643 token per asset, deployed by a `TokenFactory`.** Standard-correct; the factory makes onboarding "unaided" real.
- **Option B — Single token, assets distinguished off-chain.** Non-standard, breaks the ERC-3643 model; not recommended.
- **Recommendation:** **Option A**, but for MS1 a single hand-deployed token for one gold lot is enough; build the factory only if onboarding a *second* asset is in the demo.
- **Blocks:** the "provider onboards a gold lot unaided" done-criterion and the provider console scope.
- `Decision:` **Option A** — one ERC-3643 token per asset, with `IdentityRegistryStorage` shared across assets. MS1 uses one hand-deployed token for one gold lot; `TokenFactory` (T3.5) only when a second asset enters the demo. ADR `0016`. _(Fahad Naseer, 2026-10-27)_