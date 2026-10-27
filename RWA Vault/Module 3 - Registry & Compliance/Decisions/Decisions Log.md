---
tags: [rwa-vault, m3, decisions]
updated: 2026-10-27
---
# M3 Decisions Log

A running record of decisions actually made for M3. Each entry: date, the decision, who decided, and a link to the ADR if the decision was non-obvious. Open items still live in [[Open Questions for Fahad]].

> Convention (from [[All Modules]]): write an ADR in `docs/adr/` for every non-obvious decision. This log is the human-readable mirror; the ADR is the source of truth.

## Decided

| Date | Q | Decision | Decided by | ADR |
| ---- | - | -------- | ---------- | --- |
| 2026-10-27 | Q1 | **Hybrid implementation (Option C):** vendor `onchain-id` for the ERC-734/735 identity plumbing; build the token, the three registries, ModularCompliance and AssetRegistry in-house | Fahad | `0012-hybrid-erc3643-implementation.md` |
| 2026-10-27 | Q2 | **One claim topic, `KYC` (Option A).** No country restriction; the IdentityRegistry's own `uint16` country field is retained | Fahad | — (scope) |
| 2026-10-27 | Q3 | **Investor claims are ECDSA; PQ is confined to the custodian reserve attestation (Option A)** | Fahad | `0013-claims-ecdsa-pq-at-reserve.md` |
| 2026-10-27 | Q4 | **Asset liveness is a compliance module (Option A)** — `AssetLiveModule` bound to ModularCompliance, not a mint-time check in the token | Fahad | `0014-asset-liveness-as-compliance-module.md` |
| 2026-10-27 | Q6 | **Only the is-LIVE module for MS1 (Option A).** Official `SupplyLimitModule` to be evaluated for the reserve cap; no `CountryRestrictModule` | Fahad | — (scope) |
| 2026-10-27 | Q7 | **Suggested key-tier mapping adopted, upgraded:** `owner` ⇐ Tier 0/1 as a 2-of-3 multisig, `agent` ⇐ Tier 1 service key, investors ⇐ Tier 2 device keys; registry/compliance setters behind the multisig | Fahad | `0015-agent-powers-and-key-tiers.md` |
| 2026-10-27 | Q8 | **One ERC-3643 token per asset (Option A)**, shared `IdentityRegistryStorage`; `TokenFactory` deferred until a second asset enters the demo | Fahad | `0016-one-token-per-asset.md` |
| 2026-10-27 | Q9 | **Provider console is a real UI (Option B)** in `apps/ops-console`, with the onboarding script built first as the fallback | Fahad | `0026` |
| 2026-10-27 | Q5 | **Stub the reserve source behind `IReserveAttestationSource` (Option A)**, driven by a signed custodian envelope for MS1; M5 implements the same interface in Phase 2. The MS1 reserve figure is asserted, not independently verified, and must be stated as such | Fahad | `0017-reserve-attestation-source-seam.md` |
| 2026-10-27 | Q11 | **Insurer co-signs the reserve attestation (Option B)** — custodian + insurer 2-of-2 via an attestor registry, plus a fifth clause checking policy coverage ≥ attested value and policy not expired. **Gas check required before build**; needs M2's agreement on the envelope schema. **MS1 scope reopened as [[Q17 - Does the insurer co-sign at MS1, or after it|Q17]]** | Fahad | none yet — follows Q17 |
| 2026-10-27 | Q12 | **Internal operator tool for MS1 (Option (a))** — no accounts or auth beyond network access; provider self-service is Phase 2 | Fahad | — (scope) |
| 2026-10-27 | Q13 | **τ = 24 hours for gold (Option A)**, set via `setValuationWindowFor`. **Tests set a short window (≤ 1 h) through the setter** — 24 h is the deployed default, never a constant in the predicate | Fahad | `0018` |
| 2026-10-27 | Q14 | **Accept a downward attestation, block further mints, emit `UnderReserve` (Option B)** — an operator decides on a freeze; no auto-freeze | Fahad | `0019` §3 |
| 2026-10-27 | Q15 | **Immutable — no proxy (Option A).** Plain deploys, constructors, no storage gaps. Stated explicitly *because* ADR `0012` vendors part of Tokeny's proxy-based stack, so silence would let proxies and plain deploys coexist unchosen | Fahad | `0025` |
| 2026-10-27 | Q16 | **FROZEN blocks minting only; transfers continue (Option A)** — confirmed as a holder-rights decision, not inherited from C9. Holders keep their exit however the freeze arose | Fahad | `0019` §6 |
| 2026-10-27 | Ajv | **Approved as a `devDependency`** for the schema/TypeScript parity harness, with the three intentional divergences in one named allow-list. Unblocks T6.0 batch 2 | Fahad | — (tooling) |
| 2026-10-27 | Q10 | **Implement `forcedTransfer` / `burn` / `recoveryAddress`** — EIP-3643 mandates them — but keep them off the MS1 demo path and govern `forcedTransfer` by multisig + timelock | Fahad | `0015-agent-powers-and-key-tiers.md` |

## Still open

Six questions raised on 2026-10-27 for Task 6 — **Q17 to Q22** — are open. They are listed, with recommendations, in
[[Open Questions for Fahad]]; each lives in its own note in `Questions/`. C11 (production custodian) is deferred by
agreement.

**Carried work that is not a decision:**
- **Q13's test carve-out must not be lost:** 24 h is the deployed default; T4.2's boundary tests set a short window
  through the setter and assert behaviour at whatever τ is configured, never a hard-coded 24 h.
- **A custodian portal (T8)** exists on the board but is unstarted.

## Already locked by the scaffold (commit `0b2dd0e`)
- **ERC-3643 is the token standard** (not a custom allowlist).
- **Interface-first PR** before implementation, with an `abstract` acceptance spec as the merge bar.
- **OpenZeppelin + forge-std as submodules**, Solidity `0.8.26`, GPL-3.0 licence headers. Q1=C adds `onchain-id` as a third submodule; its GPL-3.0 licence is compatible with the headers already in place.
- **The six acceptance guarantees** in `ERC3643Acceptance.t.sol` are the behavioural contract.

## Notes on the research behind Q2, Q4, Q6, Q7, Q8
The Q2/Q4/Q6/Q7/Q8 answers were taken against published ERC-3643 practice rather than from first principles:
- **Claim topics are registry-defined, not canonical** — the T-REX whitepaper uses `KYC = 42` only as an example, and the issuer chooses the indices.
- **ModularCompliance is the intended extension point** — the official example modules (country allow/restrict, max balance, supply cap, time-window limits, fees, permit list) are explicitly described as platform-developed and *not* part of the open-source protocol, so `AssetLiveModule` is exactly the sanctioned pattern.
- **Agent powers are a known centralisation finding** — published audit guidance asks for every owner/agent address to be recorded as multisig-or-single-key, and for `setIdentityRegistry` / `setCompliance` to sit behind a multisig or timelock.
- **Per-asset deployment is the norm** — the official factory deploys a full suite per token, compliance is bound 1:1 to a token, while identity storage and the implementation authority are shared across tokens.

Up: [[Module 3 - Registry & Compliance]] · Related: [[Open Questions for Fahad]], [[ADR Index]]
