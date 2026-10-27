---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q02
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q2 — Which claim topics make a wallet "verified", and how many?
**Why it matters:** the Claim Topics Registry set is the policy every `isVerified` check enforces. More topics = more realistic but more fixtures and issuer plumbing.
- **Option A — Single topic: `KYC` (1).** Simplest thing that demonstrates the gate.
- **Option B — Two topics: `KYC` (1) + `COUNTRY_ALLOWED` (3).** Shows topic composition and uses the `country` field already in the registry.
- **Option C — Three: KYC + accredited-investor + country.** Most realistic, most work.
- **Recommendation:** **Option B** — enough to prove multi-topic verification without fixture sprawl; the acceptance spec only needs verified/unverified to differ.
- **Blocks:** Claim Topics Registry impl, all test fixtures, the provider/investor onboarding flow.
- `Decision:` **Option A** — single topic `KYC`. No country *restriction* is intended; note that ERC-3643's IdentityRegistry already stores each investor's country as a `uint16` at registration, so choosing A loses no country data, and no `CountryRestrictModule` is bound (Q6). Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_