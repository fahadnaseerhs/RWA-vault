---
tags: [rwa-vault, decisions, custody, tokenisation, fahad]
status: all-settled-c11-deferred
updated: 2026-10-27
---
# Open Questions — Custody & Tokenisation ⭐

**These are the custody-model decisions that [[Open Questions for Fahad|M3's Q1–Q10]] do *not* cover.** M3's questions settle *how* the ERC-3643 machinery is built; these settle *who holds what*, which is the question the viva will push on ("is this custodial?") and which currently has no written answer anywhere in the vault.

They cut across [[M3 - Registry & Compliance]], [[M4 - Vault Accounting]], [[M5 - Oracle & Proof-of-Reserve]] and [[M8 - Settlement Rail]], so they live here in Project Memory rather than in one module folder.

**How to answer:** edit the `Decision:` line under each question (e.g. `Decision: Option B, 2026-10-28`). Each answered question lands in the relevant module's Decisions Log and, if non-obvious, an ADR in `docs/adr/` — same convention as [[All Modules]].

Format per question: the question · why it matters · each option with **what we actually build if you pick it** · a recommendation · what it blocks.

---

## C1 — Who is the custodian of the physical gold for the FYP?
**Why it matters:** every reserve attestation in M3/M5 is signed by *somebody*. That identity decides whether the demo story is "a real vault attested to this" or "we simulated a vault", and it decides how much of M2's key hierarchy has to be real.

- **Option A — Simulated custodian we operate.** We generate a Tier-1 ML-DSA-65 keypair, run a small custodian service in `services/`, and it signs attestation envelopes for fixture gold lots.
  *What we build:* a `custodian-sim` service, a fixture lot catalogue, and a documented statement in the thesis that the custodian is simulated. Zero external dependency, zero schedule risk.
- **Option B — A named real vault partner, paper agreement only.** We approach a Lahore/Karachi bullion vault, get a letter of intent, and model their process — but still sign attestations with our own keys.
  *What we build:* the same as A, plus a process-fidelity appendix and a real-world validation section. Cost: weeks of outreach that may return nothing, and the demo itself does not change.
- **Option C — Real custodian holding their own key.** They hold a Tier-1 key and genuinely sign.
  *What we build:* a key ceremony, onboarding documentation, a support burden, and a hard external dependency sitting on the demo path.

- **Recommendation:** **A**, with B's letter as a stretch goal if outreach turns out to be cheap. The thesis contribution is the *verifiability* of attestations, not the existence of a vault partner; an examiner will accept a simulated custodian provided it is labelled honestly.
- **Blocks:** M3 T4.4, M5's re-attestation flow, the MS1 demo script, and how the thesis words its custody claim (see C10).
- `Decision:` **Option A — simulated custodian.** Not a real vault partner. The custodian is a **role behind an interface**: whoever holds the gold signs the attestation through a **custodian portal**, and for the FYP we operate that portal and hold that key ourselves. Who the production custodian would be — a bank, an insurer, or a dedicated vault operator — is deliberately **deferred to C11**. _(Fahad Naseer, 2026-10-27)_

> **Two things this decision creates, both new work:**
> 1. **A custodian portal is not the provider console.** T6 in M3 builds the *provider* onboarding console (register a lot). Signing a reserve attestation is a *custodian* action with a different actor, a different key and a different screen. Nothing on the M3 board covers it yet — it needs a task.
> 2. Because the custodian signs through an interface, swapping a simulated custodian for a real one later is a key-and-account change, not a redesign. That is the point of taking A now.

## C2 — Does the operator ever hold investor tokens?
**Why it matters:** this is the single decision that makes the on-chain layer custodial or not. Everything else about custody is wording; this one is code.

- **Option A — Mint direct to the investor; the vault pulls via `approve`/`transferFrom`.** No operator-controlled address ever appears in the token's balance map for investor funds.
  *What we build:* `Token.mint(investorAddress, …)` called by the agent, and `AssetVault.deposit` using `transferFrom`. Investors must send an extra `approve` transaction, so M10 needs a two-step deposit UX.
- **Option B — Mint to an operator hot wallet, then distribute.** Simpler batching and a simpler UX.
  *What we build:* a hot-wallet service with key management, a distribution job and a reconciliation report — and we are custodial, carrying all the key-loss risk that implies.
- **Option C — The vault contract is the minter; investors receive shares directly.** Gold units never exist in a user balance at all, only vault shares do.
  *What we build:* tighter coupling between M3 and M4 (the vault becomes an ERC-3643 agent) and fewer transfers, but gold units become un-transferable between investors, which weakens the whole ERC-3643 story.

- **Recommendation:** **A.** It is barely more work, it is the only option that supports the non-custodial claim, and the extra `approve` step is a pattern users already meet on every DEX.
- **Blocks:** M3 T3.1/T5.3, M4's deposit path, M10's deposit screen, and the C10 claim.
- `Decision:` **Option A — the operator never holds investor tokens.** Mint direct to the investor's address; the vault
  pulls via `approve`/`transferFrom`. No operator-controlled address appears in the token's balance map for investor
  funds. M10's deposit screen is therefore two-step. _(2026-10-27 — **inferred**, not separately stated: C7 decided we hold no
  money, C10 decided we build the non-custodial layer, and C4's self-custody wallet only makes sense if tokens go
  straight to the holder. A is the only option consistent with all three; B would make us custodial at the token layer
  and would make C10 false. Flag it if that is not what you meant.)_

## C3 — What governs the agent powers (`freeze`, `forcedTransfer`, `recoveryAddress`)?
**Why it matters:** ERC-3643 gives the agent power to move user tokens. That cannot be removed without breaking the standard, so the only real question is how accountable it is. M3's Q10 decides whether we *implement* these; this decides who may *fire* them.

- **Option A — A single agent EOA.** The service key can freeze or seize at will.
  *What we build:* nothing extra. Fastest, and indefensible in the viva the moment someone asks who can take your tokens.
- **Option B — A multisig agent.** A 2-of-3 Safe, or a minimal in-house multisig, holds the agent role.
  *What we build:* a multisig deployment in `contracts/script/`, three team keys, and a slower demo (two signatures per freeze). Turns "we can seize your tokens" into "a quorum can".
- **Option C — Multisig + timelock + mandatory reason code.** Powers queue for N hours and emit a typed reason before execution.
  *What we build:* a `TimelockedAgent` wrapper contract, a reason enum, an events feed in the ops console, and roughly two extra days of contract and test work. Strongest thesis story: the power exists, is delayed, and is publicly auditable.

- **Recommendation:** **C** for the `forcedTransfer` path and **B** for `freeze` — freeze needs to be fast in a real incident, seizure does not. That split is worth an ADR on its own.
- **Blocks:** M3 T3.3/T5.2, the Q7 key-tier mapping, and the honest version of C10.
- `Decision:` _____________________

## C4 — What wallet model do investors use?
**Why it matters:** "non-custodial" is meaningless if a Pakistani retail investor cannot actually hold a key. This decides M10's hardest screen, and whether key loss means lost gold.

- **Option A — Self-custody EOA (MetaMask / WalletConnect).** The user holds a seed phrase.
  *What we build:* a wallet-connect flow in M10 and nothing else. Genuinely non-custodial; key loss is permanent, recoverable only through the agent `recoveryAddress` power, which lands us back in C3.
- **Option B — Smart account with guardian recovery (ERC-4337 or a minimal account).** The user holds a device key; guardians can rotate it.
  *What we build:* an account factory, a guardian-set UI, and optional bundler/paymaster plumbing. Non-custodial *and* survivable, and it lines up neatly with M2's Tier-2 device keys. Real added scope.
- **Option C — Operator-held keys behind a password login.** The most familiar UX for the target market.
  *What we build:* a KMS, an auth system, and a fully custodial product that contradicts the project's premise.

- **Recommendation:** **A** for MS1–MS3 — it is the honest baseline and costs nothing — with **B** written up as the named path to production in future work. Pick B now only if M10 has slack, which on the current plan it does not.
- **Blocks:** M10's scope, C3's recovery argument, and the demo rehearsal script.
- `Decision:` **Option A — self-custody EOA (MetaMask / WalletConnect)** for MS1–MS3, with Option B (smart account with
  guardian recovery) named as the path to production in future work. Key loss is permanent, recoverable only through the
  agent `recoveryAddress` power, which is governed per Q7/ADR `0015`. _(2026-10-27 — **inferred** from the stated intent to use
  a MetaMask-style non-custodial wallet and from C7. Flag it if that is not what you meant.)_

## C5 — What is one token unit?
**Why it matters:** it fixes the mint arithmetic, the oracle's price denomination, and every fixture in M3/M4/M5. Changing it later touches all three modules at once.

- **Option A — 1 token = 1 gram, 18 decimals.** A 1 kg bar mints 1,000 × 10¹⁸ units.
  *What we build:* gram-denominated prices from M5, familiar ERC-20 ergonomics, and M4's ERC-4626 σ = 10⁶ offset stays comfortable.
- **Option B — 1 token = 1 milligram, 18 decimals.** A smaller minimum economic unit on paper.
  *What we build:* the same as A, except every fixture number grows by 10³ and the numbers in the thesis get harder to read for no actual gain.
- **Option C — 1 token = 1 tola (11.664 g).** Matches how gold is actually quoted and sold in Pakistan.
  *What we build:* a non-integer gram conversion everywhere, a rounding-direction problem in M4 that interacts badly with the inflation hardening, and a tola→gram constant that needs justifying. Strong local-relevance story, real arithmetic cost.

- **Recommendation:** **A**, with tola shown only as a *display* unit in M10. Keep the on-chain unit metric and integer; localise in the UI.
- **Blocks:** M3's mint fixtures, M4's share-arithmetic tests, M5's price denomination, M10's display formatting.
- `Decision:` **Option A — 1 token = 1 **fine** gram, 18 decimals. LOCKED.** (Basis amended 2026-10-27: supply,
  attested reserve and `unitValue` are all on **fine** grams, so a 999.9-fine kilobar mints 999.9e18, not 1000e18.
  ADR `0020`'s original worked example was wrong and would have rejected an honest bar at the MS1 demo — see its
  Amendment section. Overrule if you want gross weight instead, but it would bake a deliberate 0.01% over-claim into
  every token.) Tola is rejected: at ~PKR 400,000/tola a one-tola
  unit would price the smallest holdable amount at four lakh. Grams do not have that problem, because 18 decimals make
  the unit a *denomination*, not a minimum purchase — a PKR 1,000 buy is 0.029 tokens and is representable exactly.
  **The minimum investment is a separate deposit-path check, not a property of the token unit.** Tola and milligram are
  **display units only**, formatted in M10. ADR `0020`. _(Fahad Naseer, 2026-10-27)_

## C6 — Is physical redemption in scope?
**Why it matters:** the right to redeem metal is what makes a gold token a claim rather than a price tracker, and it is the first thing a finance examiner asks. It also decides whether burn is a demo path or just a unit test.

- **Option A — No physical redemption; cash-settled only.** Holders exit by selling, or by redeeming to PKR through M8.
  *What we build:* the existing burn + M8 payout path. Honest and simple, and the token is explicitly a cash-settled claim in the thesis.
- **Option B — Redemption above a threshold (e.g. 100 g), request-only.** Modelled, never executed.
  *What we build:* a `RedemptionRequest` flow in the registry, a custodian acknowledgement envelope, a burn-on-release path, and a documented off-chain leg nobody performs during the FYP. Three to four days.
- **Option C — Full redemption, executed in the demo.** Requires a real custodian (C1 = C) and real metal.
  *What we build:* out of scope for an FYP — logistics, insurance and a licence.

- **Recommendation:** **A** for the build, with **B** specified as an `IRedemption` interface that nobody implements — the same stub-the-seam trick as M3's Q5. It costs an afternoon and answers the examiner's question with a design rather than a shrug.
- **Blocks:** M3's burn semantics, M8's payout direction, and the legal-claim wording in C8.
- `Decision:` **Option A — cash-settled only.** A holder exits by selling, or by redeeming tokens for PKR or USDC at the
  prevailing gold price; the tokens burn and the metal stays in the vault. **Option B's `IRedemption` interface is still
  written** so the design is on record and Phase 2 is an implementation rather than a redesign, but nothing satisfies it
  during the FYP. ADR `0023`. _(Fahad Naseer, 2026-10-27)_

> **What physical redemption would have looked like, for the record:** a threshold at a *deliverable* unit — 1 tola
> (11.664 g) or a 10 g bar, never a cash amount, since $1 of gold is about 8 mg and is neither assayable nor
> deliverable; a signed request; a custodian acknowledgement; burn-on-release; KYC on the redeemer; a fee covering
> assay, handling and bar-splitting loss; and collection in person. Both major gold tokens do offer physical
> redemption under exactly these kinds of gates — PAXG to LBMA Good Delivery bars (reportedly with a cash option and
> unallocated gold for institutions), XAUT reportedly in 430-token increments, KYC-verified direct customers only,
> delivery inside Switzerland. So it is **not** rare for gold; it is rare for it to be *unconstrained*.
>
> **And gold is the easy case, not the hard one.** Gold is fungible and comes in standard bars, so physical delivery is
> at least definable. Real estate is the opposite — a fraction of a building cannot be handed over, so redemption
> there means selling the property and distributing the proceeds, which *is* cash settlement.
>
> **Where the cash comes from is unresolved.** ADR `0022` says the platform holds no money, so a cash redemption routes
> through the same licensed provider as the on-ramp, or settles in USDC from a buffer whose funding is not yet
> specified. That belongs to M8's research as an open item, not an assumption.

## C7 — Who holds the PKR float in the mock rail?
**Why it matters:** M8 is custodial by regulation in any real deployment. The question is what the *mock* models, because that is what the double-entry ledger has to balance.

- **Option A — Model a licensed third-party rail; our ledger only mirrors it.** The mock has an external settlement account we never control.
  *What we build:* `IFiatRail` with a provider-held settlement account, and a reconciliation job that detects drift between our ledger and theirs. Closest to reality.
- **Option B — Model an operator-held float account.** We are the custodian of PKR in the model.
  *What we build:* a simpler ledger with one internal account, and a thesis that has to admit fiat custody sits with us.
- **Option C — Skip fiat entirely; investors arrive holding testnet USDC.** No PKR leg at all.
  *What we build:* much less — but MS2's "PKR 5,000 deposit → Merkle proof verifies offline" gate no longer means what it says.

- **Recommendation:** **A.** It keeps the MS2 gate intact, it is the arrangement a real deployment would have, and the reconciliation job it forces is exactly what Experiment D needs something to injure.
- **Blocks:** M8 T1–T4, the MS2 gate wording, and Experiment D's failure injection.
- `Decision:` **Option D (new) — we never hold the money.** Neither PKR nor USDC passes through an account we control.
  The wallets and licensed providers hold it and we **integrate** them, so `IFiatRail` is reframed as an **on-ramp
  integration seam** rather than an in-house rail. For the FYP the provider behind that seam is mocked, so MS2 still has
  something to verify. ADR `0022`. _(Fahad Naseer, 2026-10-27)_

> **Why this is the right shape, from industry practice:** non-custodial apps do not build fiat rails. They embed a
> licensed third-party on-ramp that delivers crypto **straight to the user's own wallet**, with the provider as
> **Merchant of Record** — so the integrating app needs no money-transmitter licence of its own, because fiat never
> touches its balance sheet. MoonPay is described as operating exactly this way and Ramp Network as non-custodial;
> Transak positions itself as embedded infrastructure, though sources disagree on whether its flow is custodial, so that
> one needs checking directly.
>
> **And the Pakistani position changed in 2026.** The **Virtual Assets Act, 2026** took effect **5 March 2026**, creating
> **PVARA** as federal regulator, with eleven licensable activity categories including exchange services and an
> application deadline of 5 September 2026. The **State Bank lifted its ban on banks serving virtual-asset firms in
> April 2026**, though banks still may not hold or trade virtual assets themselves. So a real PKR→USDC path is now
> legally conceivable — but **operating that conversion is a licensable VASP activity**, which is precisely why the
> decision above is to integrate rather than operate. (Secondary sources; check the PVARA and State Bank texts before
> anything goes in the thesis.)

> **Deferred, by agreement:** how far the *real* money path goes. The gold-purchase leg needs physical metal, so a live
> investment flow may stay out of scope; token transfer, and lending/borrowing against USDC or non-gold assets, are the
> parts that could run for real. **Revisit in Phase 2** — nothing in MS1/MS2 depends on it, and the integration seam
> above is the same either way.

## C8 — What does a token holder legally hold?
**Why it matters:** it is paper rather than code, but it determines whether the thesis can say "asset-backed", and it shapes both C6 and C10. It needs one paragraph, written once.

- **Option A — Beneficial interest in a custodied pool (trust-style).** Holders are beneficiaries; the custodian holds legal title.
  *What we build:* a one-page claim-structure note in `docs/`, cited from the thesis. This is what PAXG and XAUT do, so there is precedent to cite.
- **Option B — Direct fractional title to an identified bar.** Each lot maps to a serial number and holders co-own it.
  *What we build:* the same note, plus a per-bar allocation model in the registry — which we already have, since M3 registers identified lots. Stronger story, more hand-waving about Pakistani co-ownership law.
- **Option C — A debt claim against the issuer, gold-referenced.** We owe you the gold value.
  *What we build:* the simplest paper, but the token stops being asset-backed in any meaningful sense and proof-of-reserve loses its point.

- **Recommendation:** **B**, because the architecture already registers identified lots with serials — the design is doing the work, so claim it. Keep the note short and flag explicitly that it is not legal advice.
- **Blocks:** the thesis §II framing, C6, C10, and the provider onboarding form's fields.
- `Decision:` **Option B — fractional title to an identified lot.** A specific bar, registered with serial, weight and
  purity, covered by a PQ-signed reserve attestation. This is what the contracts already do: Q8/ADR `0016` put one
  ERC-3643 token per asset, and M3 registers lots individually. ADR `0024`. _(Fahad Naseer, 2026-10-27)_

> **The one open thread it leaves:** holders own title to a *specific* bar, so the issuer cannot sell that bar to fund a
> cash redemption (C6) without co-owner consent. Cash settlement therefore needs a **buffer, a market maker, or
> whole-lot disposal with consent**. Structure question, not a contract change — it belongs in M8's research as an open
> item, and in the claim-structure note.

## C9 — What happens when a reserve attestation goes stale?
**Why it matters:** M5 already defines a 60 s *price* heartbeat, but nothing defines the *reserve* attestation cadence or the consequence of missing one. Without this, `attestedSupply ≤ reserveAmount` can silently rest on month-old evidence.

- **Option A — Freeze minting only.** No new tokens for that asset; existing transfers, borrows, repays and withdrawals all continue.
  *What we build:* a freshness check in the admission predicate and a `MintFrozen` state. Minimal, and consistent with M5's existing "never block repay or withdraw" principle.
- **Option B — Freeze minting and new borrows.** Treats a stale reserve the way we treat a stale price.
  *What we build:* A, plus a gate in M6/M7's borrow path and a reason surfaced in the client. Slightly more coupling.
- **Option C — Freeze the asset entirely (the FROZEN state).** Transfers stop too.
  *What we build:* A, plus an automatic FROZEN transition — which hands an attestation outage the power to trap holders, probably a worse outcome than the risk it mitigates.

- **Recommendation:** **B**, with a 24 h cadence for gold. A stale reserve is a solvency signal, so it should stop new risk being taken but never trap an existing holder — the same asymmetry M5 already applies to prices.
- **Blocks:** M3 T4.2's freshness clause, M5's re-attestation flow, M7's borrow gate, and Experiment C's check list.
- `Decision:` **Option A — freeze minting only. Borrowing is NOT frozen.** Transfers, borrows, repays and withdrawals
  all continue when a reserve attestation goes stale. ADR `0021`. _(Fahad Naseer, 2026-10-27)_

> **The reasoning that has to be written down, because an examiner will ask why stale *reserve* is treated more leniently
> than stale *price* (which M5 says blocks new borrows):**
> 1. **Minting is the only action that increases the claim on the reserve.** Blocking it is the exact, minimal response to
>    uncertainty about reserve size. Borrowing does not change the token-to-metal ratio at all.
> 2. **A known shortfall is a different event, handled harder.** [[Open Questions for Fahad|Q14]] governs an attestation
>    that reports *less* reserve than the supply already minted. Stale means "nobody has spoken lately"; under-reserved
>    means "we have been told it is short". The second deserves the stronger response, and gets it.
> 3. **Freezing borrows would let an off-chain party halt a core protocol function by going silent.** That is a liveness
>    and centralisation cost paid to a custodian's inaction.
>
> **Residual risk, stated plainly:** during a prolonged outage, borrowing continues against backing that has not been
> reconfirmed. Mitigated by the short τ window (Q13), by Q14 catching reported shortfalls, and by the operator's manual
> freeze remaining available — but not eliminated. Experiment C should include a stale-reserve-then-borrow path so the
> behaviour is measured rather than assumed.

## C10 — What custody claim does the thesis actually defend?
**Why it matters:** this is the sentence an examiner will read back to you. It has to be defensible given C1–C9, and it should be chosen *before* the chapters are written, not after.

- **Option A — "A non-custodial token layer over a custodied physical asset."** The accurate position, and the same one PAXG and XAUT occupy.
  *What we build:* a short custody-model section stating the layer-by-layer split — tokens self-custodied, metal custodied, fiat rail custodied, agent powers governed per C3. Defensible as long as C2 = A.
- **Option B — "Fully non-custodial."** Not true while a custodian holds metal and an agent can freeze.
  *What we build:* an argument that will not survive the viva. Not recommended at any price.
- **Option C — Avoid the claim; describe the architecture and let the reader judge.**
  *What we build:* less exposure, but we also forfeit a genuine contribution — the verifiable-custodian design — because nobody ever names it.

- **Recommendation:** **A**, stated early and explicitly, with the table of which layer is custodial. Claiming less than you built is a smaller error than claiming more, and A lets the PQ-attested proof-of-reserve be the headline: the custodian cannot be removed, but it can be made *unable to lie silently*.
- **Blocks:** the thesis §I/§II wording, the MS1 demo narration, and the README's framing.
- `Decision:` **Option A in substance, unannounced.** We **build** the non-custodial token layer and we **document the
  layer-by-layer custody split truthfully**, so any reader or user can verify it for themselves — but we do **not lead
  with "non-custodial" as a headline claim**. Not claiming it is not the same as not doing it. If the claim is required
  — by an examiner's question, a reviewer, or a submission that asks directly — we state it, backed by the custody
  table. No ADR: this is thesis and product framing, not architecture. _(Fahad Naseer, 2026-10-27)_


## C11 — Who is the production custodian: a bank, an insurer, or a vault operator? 🕓 DEFERRED
**Deferred by agreement on 2026-10-27** (see C1). Not needed for MS1 — the custodian is simulated behind a portal — but it
shapes the thesis's "path to production" section and interacts with [[Open Questions for Fahad|Q11]], where an insurer
may become a required co-signer rather than the custodian itself.

- **(a) A commercial bank as custodian.** Banks already hold gold on behalf of clients and are supervised. In Pakistan the
  State Bank lifted its ban on banks *serving* virtual-asset firms in April 2026, but banks remain barred from holding or
  trading virtual assets themselves — so a bank could plausibly custody the *metal* while never touching the *token*.
  That separation is clean, and worth checking against the current State Bank circulars rather than news coverage.
- **(b) An insurer as custodian.** Conflates two roles that are stronger kept apart: under Q11=B the insurer's value is
  that it is an *independent* party whose money is at risk if the custodian overstates reserves. If the insurer *is* the
  custodian, the opposing-incentive argument collapses.
- **(c) A dedicated bullion vault operator**, insured by a third party. The arrangement PAXG and XAUT use, and the one
  that keeps custodian, insurer and issuer as three separate parties.

- **Leaning:** **(c)**, with the insurer kept separate per Q11. Decide before the production-path chapter, not before MS1.
- `Decision:` _____________________ _(deferred — no date set)_

---

## Decision summary (fill as you go)
| Q | Topic | Recommended | Decision |
|---|-------|-------------|----------|
| C1 | Custodian identity | A (simulated, we operate) | **A** — simulated, behind a custodian portal |
| C2 | Operator holds tokens? | A (mint direct + approve) | **A** — mint direct, vault pulls _(inferred)_ |
| C3 | Agent-power governance | C for seizure, B for freeze | ✅ **closed by Q7** — 2-of-3 multisig on `owner`, timelock on `forcedTransfer` (ADR `0015`) |
| C4 | Investor wallet model | A (self-custody EOA) | **A** — self-custody EOA; smart account = future work _(inferred)_ |
| C5 | Token unit | A (1 token = 1 g) | **A** — 1 **fine** g, 18 dp; tola display-only (ADR `0020`, amended) |
| C6 | Physical redemption | A, with B's interface stubbed | **A** — cash-settled; `IRedemption` stubbed (ADR `0023`) |
| C7 | PKR float holder | A (third-party rail modelled) | **D** — we hold no money; on-ramp integration seam (ADR `0022`) |
| C8 | Legal claim | B (fractional title to a lot) | **B** — fractional title to an identified lot (ADR `0024`) |
| C9 | Stale reserve attestation | B (freeze mint + new borrows) | **A** — freeze minting only (ADR `0021`) |
| C10 | Thesis custody claim | A (non-custodial token layer) | **A in substance, unannounced** — documented, not headlined |
| C11 | Production custodian (bank / insurer / vault operator) | (c) vault operator, insurer kept separate | 🕓 **deferred** |

## A note on the gold prices used in this file

**PKR 400,000 per tola is Fahad's undated working figure of 2026-10-27, not a sourced quote.**
Everything priced here derives from it: PKR 34,293/gram is 400,000 ÷ 11.664, the 0.029-token purchase is
PKR 1,000 ÷ 34,293, and "$1 of gold is about 8 mg" follows from the same figure. As a cross-check rather than a
source, it is consistent with contemporaneous secondary reporting of roughly USD 4,120–4,180/oz in October 2026
(≈ USD 133 per fine gram, implying ≈ PKR 259/USD), which fixes the order of magnitude and nothing finer.

**No decision in this file depends on the price level.** The tola argument holds at any plausible gold price, and the
milligram-threshold argument for C6 holds across any level gold has traded at in recent years.

Convention, following the M3 fixtures: **any figure quoted as current in the thesis or demo material carries its date
and source, or is marked a placeholder.** The M3 onboarding fixture does this by declaring its synthetic `unitValue`
in its own `source` string — a reader must never be able to mistake a placeholder for a market claim.

## Where this stands (2026-10-27)

**Settled:** C1 (simulated custodian behind a portal), C3 (closed by Q7), C5 (1 token = 1 g), C7 (we hold no money),
C9 (freeze minting only), C10 (Option A in substance, unannounced). ADRs `0020`–`0022`.

**Settled by inference on 2026-10-27** (from C7, C10 and the stated wallet intent — say the word if either is wrong):
C2 = A (the operator never holds investor tokens) and C4 = A (self-custody EOA, smart accounts as future work).

**All ten live questions are now settled.** C11 (production custodian) is deferred by agreement; nothing else is open.

**Three threads these decisions leave behind — none of them a decision, all of them work:**
1. **A custodian portal has no task.** C1 makes the custodian a role behind an interface, and signing a reserve
   attestation is a different actor and screen from M3's T6 *provider* console. Nothing on any board covers it.
2. **Cash-redemption funding is unspecified.** C6 + C8 together mean a buffer, a market maker, or whole-lot disposal
   with consent. Belongs to M8's research.
3. **The claim-structure note does not exist yet.** One page in `docs/`, cited from the thesis, stating the C8
   structure and flagging plainly that Pakistani co-ownership law for movable property is the unsettled part and that
   this is not legal advice.

> **How a holder actually verifies their bar** (from the Researcher session, 2026-10-27 — goes in the note above):
> the serial lives in the lot's `description`, which is committed into `metadataHash` at registration. So a holder
> given the description can hash it, check it matches what the chain stores, and then check
> `attestedSupply ≤ reserveOf` for that specific `assetId`. **Commit on-chain, reveal off-chain** — the serial is
> deliberately *not* stored as a string.
>
> **The gap that creates, and it is a real one:** commit-and-reveal is only as good as the reveal channel. If a holder
> cannot obtain the description, they cannot verify anything — the hash alone proves nothing without the preimage. So
> C8's title claim depends on descriptions being **published durably** somewhere a holder can reach years later, and
> nothing currently specifies where. [[M9 - Anchoring & Audit]] is the natural home. Without it, "fractional title to
> an identified lot" is true on paper and unverifiable in practice.
>
> **And what goes in the description has to be factually right, permanently.** The first fixture described the lot as a
> "1kg LBMA Good Delivery bar", which is a category error: LBMA **Good Delivery** gold bars are roughly 350–430 troy
> ounces, about 11–13 kg, at a minimum 995.0 fineness. A 1 kg bar is a **kilobar**, a different standard, typically
> 999.9 fine. Corrected to "1kg kilobar, 999.9 fine, serial XAU-88213". It mattered for two reasons that bear directly
> on C8: the description is hashed into `metadataHash`, so a wrong bar class would be committed **on-chain
> permanently** for that lot, and the fixture is the template every provider copies, so the error would have
> propagated to every asset. Under C8 a holder is meant to be able to name their bar — a wrong bar class in the
> permanent record undercuts precisely that claim. **The note should therefore specify the bar class and fineness as
> required fields, not prose.** (Found by the M3 Debugger / Researcher sessions.)
- **C11 — production custodian.** Deferred by agreement.

**Why C6 and C8 are still open while the rest are closed:** C6 you deferred yourself, pending the token-economics
question — what a redemption threshold and fee do to the peg and to the pool. C8 has never been discussed in any
session; it is the only question here that has had no input at all. They are also the pair that **conflict**, so they
have to be answered together.

Up: [[Project Memory]] · Related: [[Open Questions for Fahad]], [[All Modules]], [[ADR Index]], [[M5 - Oracle & Proof-of-Reserve]]
