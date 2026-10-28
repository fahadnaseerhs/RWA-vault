---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q01
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q1 — Build our own ONCHAINID + T-REX, or vendor Tokeny's libraries?
**Why it matters:** decides whether we hand-write ~8 contracts (token, 4 registries, modular compliance, ONCHAINID ERC-734/735) or `forge install` Tokeny's audited `T-REX` + `onchain-id` and wire them. This is the single biggest effort lever in M3.
- **Option A — Vendor Tokeny T-REX + onchain-id.** Fast, audited, standard-correct. Cost: large dependency, their Solidity version/licence (GPL-3.0, OK), less of "we built it" for the thesis, and it may not bend easily to our AssetRegistry + PQ attestation seam.
- **Option B — Build minimal ourselves against the scaffolded interfaces.** Full control, clean integration with AssetRegistry and M2 envelopes, strong thesis story ("we implemented ERC-3643"). Cost: more code and test burden; must get the claim-verification logic right.
- **Option C — Hybrid:** vendor `onchain-id` (the fiddly ERC-734/735 identity) but build our own token + registries + compliance + AssetRegistry.
- **Recommendation:** **Option B** for FYP credibility and clean integration, *scoped minimal* (see Q2/Q6). Fall back to C if the identity contracts eat too much time.
- **Blocks:** T1–T6 — essentially everything. **Decide first.**
- `Decision:` **Option C** — hybrid: vendor `onchain-id` (the ERC-734/735 key-and-claim plumbing), build the token, the three registries, ModularCompliance and AssetRegistry ourselves. Standard-conformance where it is externally checkable, authorship where it is examinable. ADR `0012`. _(Fahad Naseer, 2026-10-27)_