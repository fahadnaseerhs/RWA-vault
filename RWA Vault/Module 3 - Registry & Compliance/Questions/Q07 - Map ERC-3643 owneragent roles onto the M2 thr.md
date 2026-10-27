---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q07
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q7 — Map ERC-3643 owner/agent roles onto the M2 three-tier PQ key hierarchy.
**Why it matters:** ERC-3643 has `owner` (config) and `agent` (operations). M2 defines Tier 0 (SLH-DSA root, offline), Tier 1 (ML-DSA-65 service), Tier 2 (Falcon device). We should state which on-chain role is controlled by which tier, even if enforcement is social for the FYP.
- **Suggested mapping:** owner ⇐ Tier 0/1 governance (multisig or service key), agent ⇐ Tier 1 service key (the operator service that mints/freezes). Investor wallets are Tier 2 device keys.
- **Recommendation:** adopt the suggested mapping; document it, enforce socially now, consider on-chain PQ-gated admin later.
- **Blocks:** deployment script roles, the provider console's signing story.
- `Decision:` **Adopt the suggested mapping, upgraded per published ERC-3643 audit guidance:** `owner` ⇐ Tier 0/1 **as a 2-of-3 multisig, not a single service key**; `agent` ⇐ Tier 1 service key; investor wallets ⇐ Tier 2 device keys. `setIdentityRegistry` and `setCompliance` sit behind the multisig, since either call replaces the token's whole trust basis in one transaction. ADR `0015`. _(Fahad Naseer, 2026-10-27)_