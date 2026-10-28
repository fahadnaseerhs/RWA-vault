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
| 2026-10-28 | Q17 | **Four clauses and one custodian signer for MS1 (Option B)**; insurer 2-of-2 + policy clause move to Phase 2 under their own ADR. Q11 remains the target design | Fahad | `0017` (stands) |
| 2026-10-28 | Q18 | **Clause 1 is verified off-chain for MS1 (Option A)** — M2 verifier (or `pqctl`) checks ML-DSA-65; Tier 1 submitter records result + envelope hash; M9 anchors it. Trust in the submitter is disclosed | Fahad | `0027` |
| 2026-10-28 | Q19 | **Task 6 order (Option A):** Researcher verifies T6.0 and writes the T6.2 protocol; Coder builds T1.1 → T4.1 → T2 → T3 → T5.1; then T6.1a → T6.3 → T6.1b | Fahad | none (sequencing) |
| 2026-10-28 | Q20 | **Push all local-only work, restore the deleted PDF and PNGs (Option A)** — code and docs committed on the vault PR branch | Fahad | none |
| 2026-10-28 | Q21 | **Accept ADRs 0002–0027; licence GPL-3.0** — 0014 marked partly superseded by 0019 §6; CI runners pinned per 0008; `LICENSE` added, README badge fixed | Fahad | `0001` (process) |
| 2026-10-28 | Q22 | **T6.2 tester (Option A):** Hassan or Fawaz (non-author of T6), on devnet after T6.1a is green; an outside tester repeats it for the final MS1 dry run if time allows | Fahad | none |

## Still open

All Task 6 questions (Q17–Q22) were decided on 2026-10-28 (rows above). The index is
[[Open Questions for Fahad]]; each lives in its own note in `Questions/`. C11 (production custodian) is deferred by
agreement.

### T0.7 decisions — D3 decided 2026-10-28; D1, D2 and T0.8 deferred by Fahad

Moved here from the T0.7 thread on 2026-10-28. A thread is append-only, so a table that gets revised cannot live in
one — later entries are appended *after* it and its own "appended here" promise becomes false, which is what happened.
Threads hold entries; revisable tables belong in the task note, the spec, or here.

| # | Decision | Recommended by Researcher | Blocks |
| - | -------- | ------------------------- | ------ |
| **D1** 🕓 | _Deferred by Fahad, 2026-10-28 — documentation rather than code or design, to be taken in the final pass._ May T0.7 be checkmarked as a spec while T0.8 is impossible? | Yes — complete as a spec, leave T0.8 open, make §8 a standing review item. Checkmarking T0.8 on the Researcher's own assertion would turn a later real review into a rubber stamp. | Formal closure of T0.7 |
| **D2** 🕓 | _Deferred by Fahad, 2026-10-28 — same reason._ Reserve ADR `0028` as a stub now for the Phase 2 insurer design? | Yes — Q17 promises that work its own ADR, claim-by-file means the number exists only once committed, and a stub costs one file against the churn that caused three renumbers on 2026-10-27. | Nothing; prevents renumbering |
| **D3** ✅ | **DECIDED 2026-10-28 — TWO SEPARATE ADDRESSES, same Tier 1.** Is the Tier 1 submitter key a separate address from the registry's agent key? | Separate addresses, same tier. ADR `0015` puts both at Tier 1 but never says whether they are one address; submitting an attestation and administering an asset are different acts, and one key means one compromise does both. | **T5.2 role assignment** |
| **T0.8** 🕓 | _Deferred by Fahad, 2026-10-28 — "we will see task 0.8 later"._ How is consumer sign-off satisfied when M4, M5 and M9 do not exist? | See the three options below. | Formal closure of T0 |

#### D3 — decided 2026-10-28: the submitter and the agent are two addresses

**Decision:** the Tier 1 **attestation submitter** and the registry's **agent** are **two separate addresses at the same
key tier**. Fahad's reasoning, recorded in his words: they are two different people doing two entirely different tasks,
so sharing an address is not a trade-off to weigh — it is a mistake.

**What it changes.** T5.2's role assignment deploys and records two addresses rather than one. A compromised submitter
key can assert a false reserve but cannot mint against it; a compromised agent key can mint but cannot fabricate the
attestation that would justify the mint. One stolen key no longer completes the whole attack.

**Where it is recorded.** Here, and in the T5 task note at the point of use. **It does not yet have an ADR.** ADR `0015`
maps the roles onto the PQ key tiers but never says whether the two are one address, and `0015` is now **Accepted**, so
under ADR `0001` it is immutable and cannot absorb this. This is a clarification of something `0015` left unsaid rather
than a reversal of anything it decided, so it wants its own short record when the documentation pass happens — which is
the pass Fahad has deferred D1 and D2 to. Until then the register and the task note are the authority.

#### T0.8 in full

**Why it cannot be done as written.** `Tasks/T0 - Interface PR.md` asks for "consumer sign-off (M4, M5, M9 owners) on
interface signatures", from the rule in `Modules/All Modules.md` — _"Open with an interface-only PR, approved by its
consumers before any implementation."_ But M4 is 0%, M5 and M9 are not started, so no consumer exists that could say
whether the signatures fit; and `Project Memory/Team.md` names Fahad, Hassan and Fawaz without recording any
per-module owner, so "the M4 owner" is not yet a person. The task has neither a signatory nor a basis for signing.

**Why it still matters.** ADR `0025` made M3's contracts immutable — plain deploys, no proxies — so an interface error
is a redeploy and a migration, not an upgrade. And `IReserveAttestationSource` is the one interface a later module
(M5, Phase 2) must implement exactly, written by someone who will not be in these conversations.

- **(a) Name the three module owners now** and have each read `IAssetRegistry.sol` and `IReserveAttestationSource.sol`
  against their own module's needs, recording a dated sign-off. Cheap and satisfies the rule — but a sign-off from
  someone who has built nothing is weak evidence.
- **(b) Defer T0.8 explicitly** until M4 and M5 start, reason recorded, re-opened as a gate on those modules. Honest
  about sequencing; leaves M3's interfaces reviewed by nobody but their author.
- **(c) Replace the signature with the conformance test.** `ReserveAttestationSourceConformance.t.sol` already exists
  and is proved satisfiable by mutation, so a later M5 "signs off" by passing it. Matches the project's own rule that
  the acceptance test must be runnable by a third party.

**Recommendation: (c) with (a) alongside, and do not close T0.8 on the suite alone.** Two caveats from the Researcher
decide the shape: the suite can only test what the interface can observe, so it covers **conformance, not whether M5's
upstream data is honest**; and a passing suite says nothing about **whether `latest`/`hasAttestation` was the right
shape to ask for in the first place**. So: executable sign-off for the mechanical half, a human for the design half,
and §8's four assertions still need a real reviewer.

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
