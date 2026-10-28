---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q12
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q12 — Who operates the onboarding console: the provider, or us on their behalf? ⭐ NEW
Raised by the T6 research ([[T6 - Provider Onboarding Console]] §9). Q9 settled *that* there is a UI in
`apps/ops-console`; it never settled *who signs into it*, and the two answers are different products.

- **(a) Internal operator tool** — we run it, the provider sends us the lot details. No accounts, no authentication
  beyond network access; the Tier 1 `agent` key stays with the operator. Small, and shippable for MS1.
- **(b) Provider self-service** — the provider signs in themselves. T6 then also owes accounts, sessions,
  authorisation, per-provider scoping and an audit trail of who submitted what — a materially larger build.

- **Recommended: (a) for MS1,** with (b) recorded as Phase 2. The "unaided onboarding" bar (T6.2) tests whether the
  *procedure* explains itself, not whether we shipped a multi-tenant SaaS — and (a) satisfies it as written.
- **Blocks:** T6.1b's scope only. **Not a blocker** — T6.0, T6.1a and T6.3 proceed either way.
- `Decision:` **Option (a)** — internal operator tool for MS1. We run it, the provider sends us the lot details; no accounts or authentication beyond network access, and the Tier 1 `agent` key stays with the operator. Provider self-service is Phase 2. The "unaided onboarding" bar (T6.2) tests whether the procedure explains itself, not whether we shipped multi-tenant SaaS. _(Fahad Naseer, 2026-10-27)_

---