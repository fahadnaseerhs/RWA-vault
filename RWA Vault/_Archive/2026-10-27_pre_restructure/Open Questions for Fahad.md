---
tags: [rwa-vault, m3, decisions, fahad]
status: all-sixteen-decided
updated: 2026-10-27
---
# Open Questions for Fahad ⭐

> **Status 2026-10-27 — ALL SIXTEEN QUESTIONS DECIDED.** Q1–Q16 are answered below and mirrored in [[Decisions Log]].
> The Ajv devDependency is approved. **Nothing in M3 is decision-blocked.**
> Two ADRs remain to be written — Q15 (immutable, no proxy) and Q11 (insurer co-signature) — and Q13 belongs in `0018`,
> which the Researcher session holds. Q14 and Q16 are already covered by `0019`.
> **Q11 needs a gas measurement before it is built.** **Q13's 24 h is a deployed default, not a constant:** T4.2's
> boundary tests set a short window through `setValuationWindowFor`.

**Read this before any M3 implementation starts.** Each question below changes the shape of the module. For each one: the question, why it matters, the options, a **recommendation**, and what it **blocks**. Fill in the `Decision:` line, then the [[Agents - Workflow|Researcher]] turns the chosen path into tasks and the build moves.

How to answer: edit the `Decision:` line under each Q (e.g. `Decision: Option B — build minimal, 2026-10-10`). Anything decided here should also land in [[M3 Decisions Log]] and, if non-obvious, an ADR in `docs/adr/`.

---

## Q1 — Build our own ONCHAINID + T-REX, or vendor Tokeny's libraries?
**Why it matters:** decides whether we hand-write ~8 contracts (token, 4 registries, modular compliance, ONCHAINID ERC-734/735) or `forge install` Tokeny's audited `T-REX` + `onchain-id` and wire them. This is the single biggest effort lever in M3.
- **Option A — Vendor Tokeny T-REX + onchain-id.** Fast, audited, standard-correct. Cost: large dependency, their Solidity version/licence (GPL-3.0, OK), less of "we built it" for the thesis, and it may not bend easily to our AssetRegistry + PQ attestation seam.
- **Option B — Build minimal ourselves against the scaffolded interfaces.** Full control, clean integration with AssetRegistry and M2 envelopes, strong thesis story ("we implemented ERC-3643"). Cost: more code and test burden; must get the claim-verification logic right.
- **Option C — Hybrid:** vendor `onchain-id` (the fiddly ERC-734/735 identity) but build our own token + registries + compliance + AssetRegistry.
- **Recommendation:** **Option B** for FYP credibility and clean integration, *scoped minimal* (see Q2/Q6). Fall back to C if the identity contracts eat too much time.
- **Blocks:** T1–T6 — essentially everything. **Decide first.**
- `Decision:` **Option C** — hybrid: vendor `onchain-id` (the ERC-734/735 key-and-claim plumbing), build the token, the three registries, ModularCompliance and AssetRegistry ourselves. Standard-conformance where it is externally checkable, authorship where it is examinable. ADR `0012`. _(Fahad Naseer, 2026-10-27)_

## Q2 — Which claim topics make a wallet "verified", and how many?
**Why it matters:** the Claim Topics Registry set is the policy every `isVerified` check enforces. More topics = more realistic but more fixtures and issuer plumbing.
- **Option A — Single topic: `KYC` (1).** Simplest thing that demonstrates the gate.
- **Option B — Two topics: `KYC` (1) + `COUNTRY_ALLOWED` (3).** Shows topic composition and uses the `country` field already in the registry.
- **Option C — Three: KYC + accredited-investor + country.** Most realistic, most work.
- **Recommendation:** **Option B** — enough to prove multi-topic verification without fixture sprawl; the acceptance spec only needs verified/unverified to differ.
- **Blocks:** Claim Topics Registry impl, all test fixtures, the provider/investor onboarding flow.
- `Decision:` **Option A** — single topic `KYC`. No country *restriction* is intended; note that ERC-3643's IdentityRegistry already stores each investor's country as a `uint16` at registration, so choosing A loses no country data, and no `CountryRestrictModule` is bound (Q6). Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_

## Q3 — Who is the trusted claim issuer, and how does it tie to the M2 PQ attestation?
**Why it matters:** ERC-3643 claims are signed by an issuer (ECDSA on-chain). M2 attestations are **ML-DSA-65 PQ envelopes**. These are two different signature worlds. We must decide where the PQ story lives.
- **Option A — Issuer is a plain ECDSA KYC service; PQ is used only for the custodian *reserve* attestation in AssetRegistry (not for investor claims).** Cleanest separation: investor-eligibility = ECDSA claims, asset-reserve = PQ envelope. Recommended.
- **Option B — Investor claims are also backed by a PQ envelope** verified via the M2 verifier before the on-chain claim is accepted. Stronger "PQ everywhere" thesis, much more plumbing, and M2 is still skeleton-only.
- **Recommendation:** **Option A.** Keep investor claims standard ERC-3643; concentrate PQ at the AssetRegistry reserve attestation, which is the project's distinctive contribution.
- **Blocks:** Trusted Issuers Registry impl, the issuer key setup, the AssetRegistry ↔ M2 binding, and depends on how much of M2 is ready.
- `Decision:` **Option A** — investor eligibility is standard ECDSA ERC-3643 claims from one project KYC issuer; PQ (ML-DSA-65) is confined to the custodian reserve attestation in AssetRegistry. ADR `0013`. _(Fahad Naseer, 2026-10-27)_

## Q4 — Is "asset is LIVE" a Compliance Module, or a mint-time check in the token?
**Why it matters:** this is *how the two halves of M3 join* (see [[00 - What is Module 3]]). It sets the AssetRegistry's interface and the token wiring.
- **Option A — AssetRegistry is read by a Compliance Module (`IModule`) plugged into ModularCompliance.** Idiomatic ERC-3643 — all transfer rules live in one place, pluggable, testable. Recommended.
- **Option B — The token checks `assetRegistry.isLive(assetId)` directly in `mint`/`transfer`.** Simpler to reason about, but hard-wires the asset concept into the token and departs from the standard.
- **Recommendation:** **Option A** — keeps the token standard and puts our custom logic in a module, which is exactly what ModularCompliance is for.
- **Blocks:** `IAssetRegistry.sol` shape, the compliance module list, and the invariant test wiring.
- `Decision:` **Option A** — `AssetLiveModule` (`IModule`) bound to ModularCompliance reads AssetRegistry; the token stays standard and never references assets. ADR `0014`. _(Fahad Naseer, 2026-10-27)_

## Q5 — Where does reserve amount + valuation freshness come from in M3, before M5 exists?
**Why it matters:** two of the four admission clauses (reserve ≥ supply, valuation fresh) need reserve data that the **M5 Oracle/Proof-of-Reserve** produces — and M5 is Phase 2, not built. If M3 waits for M5 it cannot finish in Sprint 3.
- **Option A — Stub the reserve source now behind an interface (`IReserveAttestationSource`); feed it a signed custodian attestation directly in M3; swap in M5 later.** Keeps M3 self-contained and MS1-reachable. Recommended.
- **Option B — Block M3 on M5.** Correct dependency-wise but breaks the phase plan (M3 is Phase 1, M5 is Phase 2).
- **Recommendation:** **Option A** — define the interface M5 will later satisfy, drive it from a custodian envelope for the demo. Record the seam in an ADR.
- **Blocks:** admission predicate impl, the demo data flow, the MS1 gate.
- `Decision:` **Option A** — stub the reserve source behind `IReserveAttestationSource`, driven by a signed custodian envelope for MS1; M5 implements the same interface in Phase 2. The MS1 reserve figure is therefore *asserted, not independently verified*, and the demo and thesis must say so. ADR `0017`. **Follow-on: see Q11**, which adds an insurer co-signature so the assertion rests on two parties with opposing incentives. _(Fahad Naseer, 2026-10-27)_

## Q6 — Which transfer-restriction compliance modules do we actually implement?
**Why it matters:** ModularCompliance can hold many modules (max-holders, country-restrict, daily-limit, lockup). Each is real work. The acceptance spec needs none of them beyond the identity gate.
- **Option A — Only the AssetRegistry "is-LIVE" module (from Q4). No extra restriction modules.** Minimal; passes the acceptance spec.
- **Option B — Add one showcase module, e.g. `CountryRestrictModule` or `MaxHoldersModule`,** to demonstrate the pluggable design.
- **Recommendation:** **Option A** for the MS1 deadline; add Option B's one module only if time remains, as it strengthens the thesis.
- **Blocks:** scope of the compliance work, extra tests.
- `Decision:` **Option A** — only the AssetRegistry is-LIVE module for MS1. Evaluate the official `SupplyLimitModule` as a near-free way to enforce `attestedSupply ≤ reserveAmount`. No `CountryRestrictModule`. Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_

## Q7 — Map ERC-3643 owner/agent roles onto the M2 three-tier PQ key hierarchy.
**Why it matters:** ERC-3643 has `owner` (config) and `agent` (operations). M2 defines Tier 0 (SLH-DSA root, offline), Tier 1 (ML-DSA-65 service), Tier 2 (Falcon device). We should state which on-chain role is controlled by which tier, even if enforcement is social for the FYP.
- **Suggested mapping:** owner ⇐ Tier 0/1 governance (multisig or service key), agent ⇐ Tier 1 service key (the operator service that mints/freezes). Investor wallets are Tier 2 device keys.
- **Recommendation:** adopt the suggested mapping; document it, enforce socially now, consider on-chain PQ-gated admin later.
- **Blocks:** deployment script roles, the provider console's signing story.
- `Decision:` **Adopt the suggested mapping, upgraded per published ERC-3643 audit guidance:** `owner` ⇐ Tier 0/1 **as a 2-of-3 multisig, not a single service key**; `agent` ⇐ Tier 1 service key; investor wallets ⇐ Tier 2 device keys. `setIdentityRegistry` and `setCompliance` sit behind the multisig, since either call replaces the token's whole trust basis in one transaction. ADR `0015`. _(Fahad Naseer, 2026-10-27)_

## Q8 — One token per asset (TokenFactory), or a shared multi-asset token?
**Why it matters:** ERC-3643 is **one token contract per asset** by design. A gold lot and a property share would be separate tokens. Confirm the pattern and whether we need a factory for the demo.
- **Option A — One ERC-3643 token per asset, deployed by a `TokenFactory`.** Standard-correct; the factory makes onboarding "unaided" real.
- **Option B — Single token, assets distinguished off-chain.** Non-standard, breaks the ERC-3643 model; not recommended.
- **Recommendation:** **Option A**, but for MS1 a single hand-deployed token for one gold lot is enough; build the factory only if onboarding a *second* asset is in the demo.
- **Blocks:** the "provider onboards a gold lot unaided" done-criterion and the provider console scope.
- `Decision:` **Option A** — one ERC-3643 token per asset, with `IdentityRegistryStorage` shared across assets. MS1 uses one hand-deployed token for one gold lot; `TokenFactory` (T3.5) only when a second asset enters the demo. ADR `0016`. _(Fahad Naseer, 2026-10-27)_

## Q9 — What is the "minimal provider console" — real UI, or script/CLI?
**Why it matters:** the done-criterion is "a provider onboards a gold lot unaided." That needs *some* interface for metadata + valuation basis + custodian + trigger attestation.
- **Option A — A Foundry/TS script (`contracts/script/` or a small CLI).** Fastest path to "unaided onboarding"; demo-able; no frontend time.
- **Option B — A minimal page in `apps/ops-console`.** More convincing for the demo/thesis, more time.
- **Recommendation:** **Option A** for MS1; upgrade to B if the schedule allows, reusing the same on-chain calls.
- **Blocks:** who owns this (frontend vs contracts), the demo script.
- `Decision:` **Option B** — a page in `apps/ops-console`. Build the onboarding **script first** (the deploy/smoke path needs it anyway), then wrap it in the UI; the script is the fallback if the UI slips, so the MS1 gate is never at risk. Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_

## Q10 — Enable `forcedTransfer` / `recoveryAddress` for the demo, or defer?
**Why it matters:** the interface includes agent recovery and forced transfer. They are powerful and need extra tests; the acceptance spec does not exercise them.
- **Recommendation:** **implement them** (they're cheap given the freeze machinery) but keep them **out of the MS1 demo path**; add targeted unit tests. Defer only if time-pressed.
- **Blocks:** token implementation scope, test count.
- `Decision:` **Implement them — not optional.** EIP-3643 *mandates* a key-recovery system and agent forced transfer, so dropping them would forfeit conformance (and with it Q1 and Q8). Keep them out of the MS1 demo path, unit-test them directly, and govern `forcedTransfer` by multisig + timelock per Q7. Non-custodiality is delivered by C2/C4 in [[Open Questions - Custody & Tokenisation]], not by removing agent powers. ADR `0015`. _(Fahad Naseer, 2026-10-27)_


## Q11 — Is the insurer a required co-signer on the reserve attestation? ⭐ NEW
**Why it matters:** nothing on-chain can verify that gold exists. What a contract *can* verify is that several
independent parties, with **opposing incentives**, all signed the same reserve statement. A custodian benefits from
over-reporting reserves (more tokens mintable); an **insurer underwriting that bullion loses money if the reserve is
overstated**. Requiring both signatures turns "trust our attestation" into "trust two parties who would have to
collude against their own interests". That is the real-world answer to "who guarantees the gold", and it is
implementable in the admission predicate.

It also adds a clause the predicate can genuinely check: **policy coverage ≥ attested value, and policy not expired.**

- **Option A — Custodian signature only** (what Q5's decision currently implies).
  *What we build:* nothing more. One signer, one envelope. Simplest, and the reserve figure rests entirely on one party.
- **Option B — Custodian + insurer, 2-of-2, with policy metadata.** The envelope carries policy number, coverage limit
  and expiry; the predicate gains a 5th clause checking coverage and expiry.
  *What we build:* a required-attestor registry (role → key), threshold verification in the admission predicate, the
  policy fields in the M2 envelope schema, fixtures for both signers, and tests for the failure cases (insurer missing,
  policy expired, coverage below attested value). Realistically **1–2 days, not one line** — and see the gas note below.
- **Option C — Generalised m-of-n attestor set.** Custodian, insurer, auditor, any future party, with a configurable
  threshold per asset class.
  *What we build:* B, plus per-asset threshold configuration and the governance to change it. More tests, more surface,
  and nothing in the FYP demo exercises the third signer.

- **Recommendation:** **Option B, implemented through a small attestor registry so that C is a configuration change
  later rather than a rewrite.** The coverage-and-expiry clause is the part worth having: it is a solvency check that a
  contract can actually perform, unlike "does the gold exist".
- **Caveats to decide with open eyes:**
  1. **The insurer is also simulated for the FYP.** A real underwriter will not countersign a student project, so both
     keys are ours and the collusion argument is architectural rather than demonstrated. Say so plainly.
  2. **Gas.** Each additional post-quantum signature verification is expensive — ADR `0011` puts the Falcon dispute
     verifier at ~3.9M gas. If ML-DSA-65 attestation verification happens on-chain, a second signer roughly doubles that
     cost and the budget needs checking before committing. If verification is off-chain with on-chain dispute, the cost
     is negligible and B is clearly worth it.
  3. It changes the **M2 envelope schema** (policy fields) and the **4-clause predicate becomes 5-clause**, so
     [[Mathematics - Admission Predicate and Invariants]] needs updating and M2's owner has to agree.
- **Blocks:** T4.2 (predicate shape), T4.4 (envelope verification), the M2 envelope schema, and the custody claim in
  [[Open Questions - Custody & Tokenisation|C10]].
- `Decision:` **Option B** — custodian + insurer, 2-of-2, with policy number, coverage limit and expiry in the envelope and a fifth admission clause checking coverage ≥ attested value and policy not expired. Built through a small attestor registry so Option C (m-of-n) becomes configuration later, not a rewrite. **Gas check first:** if ML-DSA-65 verification runs on-chain, a second signature roughly doubles a cost ADR `0011` puts at ~3.9M gas — confirm the budget before committing. Needs M2's agreement on the envelope schema. The insurer is simulated for the FYP, so the opposing-incentive argument is architectural, not demonstrated; say so. _(Fahad Naseer, 2026-10-27)_

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

## Q13 — How long is a valuation "fresh"? (the value of τ) ⭐ NEW
Raised by the T0.6 research ([[T0.6 - IAssetRegistry Interface]] §8). Clause 4 of the admission predicate rejects an
attestation whose valuation is older than τ. The interface exposes τ as an owner-set value (`valuationWindow()` /
`setValuationWindow`), so T0.6 does not need the number — but T4.2 and its boundary tests do.

**In plain words:** the custodian's note says "as of 2 p.m. today". How old is too old to trust?

- **Option A — 24 hours.** Matches daily LBMA pricing; tolerant of a custodian who signs once a day, in another timezone.
- **Option B — 1 hour.** Aligns with the M2 envelope's 3600 s validity; forces near-real-time attestations.
- **Option C — per asset class** (gold 24 h, T-bills 24 h, REIT 90 days). Right long-term; nothing in MS1 needs it.
- **Recommendation:** **A (24 h)** for MS1, set via `setValuationWindow` so a change later is configuration, not code.
  Record the chosen number in ADR `0019`.
- **Blocks:** T4.2 and its boundary tests. **Not a blocker** for T0.6 — the interface only exposes the setter.
- `Decision:` **Option A — τ = 24 hours** for gold in production, set through `setValuationWindowFor` so a change is configuration, not code.
  **Explicit test carve-out:** a unit test cannot wait 24 hours, so the boundary tests set a **short window (1 hour or less) via the setter** and exercise the clause against that. The 24 h value is the deployed default, not a constant baked into the predicate — which is precisely why the setter exists. T4.2's tests must assert the *boundary behaviour* at whatever τ is configured, never a hard-coded 24 h. _(Fahad Naseer, 2026-10-27)_

---

## Q14 — What happens when a new attestation shows *less* reserve than the tokens already minted? ⭐ NEW
Raised by the T0.6 research ([[T0.6 - IAssetRegistry Interface]] §2.3); this is the corollary in
[[Mathematics - Admission Predicate and Invariants]] §3 that explicitly says "decide which".

**In plain words:** 1,000 tokens are already in investors' hands. The custodian's next note says the vault only holds
900 tokens' worth of gold. The bad thing has already happened — the question is only what the contract does about it.

- **Option A — Refuse the attestation.** Reserve stays at the old, higher figure. Simple, but it **hides bad news**: the
  chain keeps publishing a reserve the custodian no longer claims.
- **Option B — Accept it, block further mints, emit `UnderReserve`; an operator decides on a freeze.** The chain tells
  the truth, and the master invariant becomes "no new mint while under-reserved".
- **Option C — Accept it and auto-freeze the asset.** Strongest, but one bad attestation (a typo, stale data) halts
  every holder's transfers with no human in the loop — which hands the custodian a denial-of-service switch.
- **Recommendation:** **B.** It keeps the chain honest without letting a single message freeze an asset, and it matches
  the maths note's own original recommendation.
- **Blocks:** T4.2 (`admit` behaviour on a downward attestation) and T4.5 (the exact statement of the invariant).
  **Not a blocker** for T0.6.
- `Decision:` **Option A — immutable.** Plain deploys, constructors, no proxy and no storage gaps, for M3 at MS1. The registry already exposes the two knobs we expect to turn (`setAttestationSource`, `setValuationWindowFor`), so the realistic changes need no upgrade, and an upgrade key would be a permanent audit finding and a second centralisation question at the defence on top of the agent powers in ADR `0015`. **Needs its own ADR**, per the note's own point that "we never decided" is the worst answer in a viva — and it must be stated explicitly *because* ADR `0012` vendors part of Tokeny's proxy-based stack while we build the rest, so silence would let proxies and plain deploys coexist unchosen. _(Fahad Naseer, 2026-10-27)_

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
- `Decision:` **Option A — FROZEN blocks minting only; transfers continue.** Confirmed, not inherited: holders keep their exit even when the asset is frozen, whether the freeze came from staleness, a legal hold or an incident. This affirms the Researcher's ruling (ADR `0019` decision 6, superseding ADR `0014`'s "or transfer") and matches C9 reached independently on the staleness path. `pause` remains the mechanism for the systemic case and per-wallet freeze for the targeted one, so FROZEN does not duplicate either. _(Fahad Naseer, 2026-10-27)_

---

## Q16 — May a holder transfer tokens of a FROZEN asset? ⭐ NEW
Found by the Debugger on T0.6 ([[T0.6 - IAssetRegistry Interface]] §18.4): **four of our own documents disagree**, and
T2.2 was about to hard-code one of them. ADR `0014` says the module vetoes "any mint **or transfer**" when the asset
is not LIVE; ADR `0021` says a stale reserve freezes **minting only**; the `freeze` documentation says "minting stops,
existing tokens remain"; `packages/types/src/index.ts` lists minting, redemption and borrowing.

**In plain words:** the custodian's valuation went stale, so we froze the gold lot. Can an investor who already holds
tokens still sell them to another verified investor — or are they stuck until we sort the custodian out?

- **Option A — FROZEN blocks minting only; transfers continue.** Holders keep their exit.
- **Option B — FROZEN blocks minting *and* transfers.** Nobody moves anything until the asset is live again.
- **Recommendation: A**, and I have ruled that way so T2.2 is not blocked (ADR `0019` decision 6, which supersedes
  `0014`'s "or transfer"). Reasons: the trigger for FROZEN is almost always the *custodian's* failure, so blocking
  transfers punishes holders for someone else's inaction and hands a third party a liveness switch; halting transfers
  already has its own mechanism in ERC-3643 (`pause` for the systemic case, per-wallet freeze for the targeted one), so
  making FROZEN do it as well duplicates `pause` and removes the operator's ability to distinguish a reserve problem
  from a security incident; and minting is the only action that increases the claim on the reserve.
- **Your call to overrule.** This decides whether investors can exit a troubled asset, which is a holder-rights
  question, not a technical one.
- **Blocks:** nothing — T2.2 has one unambiguous rule to build. If you reverse it, the change is one condition in one
  module. But answer it before T2.2 is **verified**, or we ship a rule you did not choose.
- **⚠ Update 2026-10-27 — you may have already answered this.** Custody decision **C9 = A** (ADR `0021`) settles that a
  stale reserve attestation freezes **minting only**, with transfers, borrows, repays and withdrawals all continuing.
  That is the same rule as Option A above, reached independently on the staleness path, so Q16 is now **corroborated by
  a decision you have already taken** rather than genuinely open. Two caveats before ticking it: C9 was decided about
  *staleness*, whereas Q16 is about the `FROZEN` **state** however it was reached (including a legal hold or an
  incident), and holder-exit rights are the kind of thing worth affirming deliberately rather than inheriting. So the
  question stands, but the expected answer is now **A, consistent with C9**.
- `Decision:` **Leaning (c) confirmed as the direction, still formally deferred** — a dedicated bullion vault operator, with the insurer kept separate per Q11=B so the opposing-incentive argument survives. Revisit before the production-path chapter, not before MS1. _(Fahad Naseer, 2026-10-27)_

---

## Decision summary (fill as you go)
| Q | Topic | Recommended | Decision |
|---|-------|-------------|----------|
| 1 | Own vs vendor ERC-3643 | B (build minimal) | **C** — hybrid (vendor `onchain-id`) |
| 2 | Claim topics | B (KYC + country) | **A** — KYC only |
| 3 | Issuer ↔ PQ | A (ECDSA claims, PQ at reserve) | **A** — ECDSA claims, PQ at reserve |
| 4 | LIVE as module vs mint-check | A (compliance module) | **A** — `AssetLiveModule` |
| 5 | Reserve source pre-M5 | A (stub interface) | **A** — `IReserveAttestationSource` stub |
| 6 | Restriction modules | A (only is-LIVE) | **A** — only is-LIVE (+ maybe `SupplyLimitModule`) |
| 7 | Role ↔ key tier | suggested mapping | **Adopted + 2-of-3 multisig on `owner`** |
| 8 | One token per asset | A (per-asset + factory) | **A** — per-asset; factory deferred |
| 9 | Provider console | A (script/CLI) | **B** — ops-console page, script first |
| 10 | Forced transfer/recovery | implement, defer from demo | **Implement** (mandated); deferred from demo |
| **11** | Insurer co-signs the attestation | B (custodian + insurer, 2-of-2) | **B** — 2-of-2 via attestor registry; gas check first |
| **12** | Who operates the onboarding console | (a) internal operator tool for MS1 | **(a)** — internal operator tool |
| **13** | Value of τ (valuation freshness) | A — 24 h, owner-settable | **A** — 24 h deployed; tests use a short window |
| **14** | Re-attestation below current supply | B — accept, block mints, flag | **B** — accept, block mints, `UnderReserve` |
| **15** | Upgradeable (proxy) or immutable contracts | A — immutable for MS1 | ⛔ **OPEN** |
| **16** | Transfers allowed on a FROZEN asset | A — minting only; transfers continue | ⛔ **OPEN** (ruled A to unblock T2.2) |

**Four open, none blocking today's work.** T0.6, T0.7, T1 and T4.1 can all start now.
- **Q11** → T4.2 / T4.4 (the predicate's clause count)
- **Q12** → T6.1b's scope only
- **Q13, Q14** → **T4.2 and T4.5.** Both are needed *before the admission predicate is written*, not before the
  interface. T0.6 exposes `setValuationWindow` without needing τ's value, and `admit`'s revert behaviour is named in
  the interface without fixing the downward-attestation rule.

**Answer Q13 and Q14 together with Q11** — all three shape the same function (`admit`), so one sitting avoids
three rounds of rework on [[Mathematics - Admission Predicate and Invariants]].

Up: [[Module 3 - Registry & Compliance]] · Related: [[M3 Decisions Log]], [[Decision Algorithms - for Fahad]], [[Agents - Workflow]]
