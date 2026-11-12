---
type: decision
id: M3-Q27
module: M3
status: decided
raised_by: debugger
raised_on: 2026-11-12
blocks: []
recommendation: "B — lower to 5, with the measured gas figures recorded beside the constant"
decision: "B — lower to 5. Hard cap, permanent (ADR 0025). If Pakistani regulators or future compliance needs require more, redeploy via setClaimTopicsRegistry at that time."
decided_by: "Fahad Naseer"
decided_on: "2026-11-12"
adr: none
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-12
---
# Q27 — Does `MAX_CLAIM_TOPICS` stay at `15`, now that `isVerified` at the cap is measured at 276k gas?

**Why it matters (plain words):** `isVerified` runs on **every mint and every transfer**, and it loops once per
required topic. The cap is the only thing that limits how long that loop can get. It was chosen before anyone had
measured the loop, on the reasoning that an unbounded list would let the owner make the token's own gate too expensive
to call. Now it is measured, and the number it implies is larger than the reasoning assumed: at the cap, a transfer
carries roughly **twelve times** the verification cost it carries at MS1's single topic. Nobody is blocked — but every
holder pays, and the owner sets the number unilaterally.

**Why it is not already answered:** Q02 = A settled *how many topics we require today* (one, KYC). Q24 settled *which
number* that topic is. Neither sets a ceiling, and the ceiling was added during T1.3 as an implementation guard rather
than as a decision. The T1 Researcher explicitly asked for the measurement and said that if 15 is already too
expensive, the bound is the wrong number — this note is that question, with the figures attached.

**On disk now:** `contracts/src/registry/ClaimTopicsRegistry.sol:37` →
`uint256 public constant MAX_CLAIM_TOPICS = 15;`, with the rationale in its NatSpec at `:32-36`
("an unbounded list would let the owner make the token's own gate too expensive to call and effectively brick
transfers. Generous against MS1's one"). The loop it bounds is `IdentityRegistry.sol:244-272`.

## The measurement (Debugger gate, 2026-11-12)

Taken with a wallet that verifies successfully in both cases, against the **real vendored `Identity` + `ClaimIssuer`**
— the mock issuer skips the ECDSA recovery and understates the cost, so the mock column is shown only to make that
gap visible.

| Required topics | Mock identity + mock issuer | **Real vendored stack** |
| --- | --- | --- |
| 1 (MS1 today) | 19,447 | **22,040** |
| 15 (the cap) | 205,087 | **275,957** |
| marginal per extra topic | 13,260 | **18,136** |

Derived from the measured marginal, not separately measured: **3 topics ≈ 58k**, **5 topics ≈ 95k**, **8 topics ≈ 149k**.

`evm_version = "cancun"`, `optimizer_runs = 200`, solc `0.8.26` — the settings in `contracts/foundry.toml` at the time
of measurement, stated because a gas figure under unstated settings is not a result (ADR `0008`, ADR `0011`).

**What the number does and does not show.** It does **not** show a brick: 276k is far under any block limit, so the
gate stays callable and the stated rationale for having a cap is satisfied at 15. What it shows is a second edge the
rationale never priced — ERC-3643 calls `isVerified` on the receiver inside `transfer`, so at the cap a transfer
carries ~276k of verification *before* the token's own ~50k and before any compliance module. That is griefing by
**degree** rather than by denial: no single action anyone can point to as an attack, just a permanent cost the owner
can impose on every holder.

**The escape hatch matters to this choice.** `IdentityRegistry.sol:212` declares
`setClaimTopicsRegistry(address) external onlyOwner`. A cap that proves **too low** is therefore recoverable: deploy a
new `ClaimTopicsRegistry` with a higher constant and point the `IdentityRegistry` at it (the new registry seeds `KYC`
in its constructor; the other topics are re-added). A cap that proves **too high** is not recoverable in the same way,
because it is not a failure anyone notices — it is a standing surface that only ever gets used. That asymmetry runs
*against* keeping the larger number, and it is the opposite of what immutability (ADR `0025`) usually implies.

**Blocks:** nothing. T1.1–T1.6 passed their gate at `15`, and MS1 uses one topic · **Does not block:** the T1
checkmark, T2, T3

## Options
- **Option A — keep `15`, and record the measured figures in the NatSpec.** *Cost:* none; one comment edit.
  *Risk:* leaves ~276k of owner-settable per-transfer cost standing for the life of the deployment. Mitigating
  context: the owner is our own 2-of-3 multisig (ADR `0015`), so the threat model is a mistake or a compromised
  multisig, not a hostile third party.
- **Option B — lower to `5`.** MS1 needs one; Phase 2's plausible additions are AML, accreditation and country, which
  is four, leaving one spare. Caps `isVerified` at ≈ 95k. *Cost:* none; one constant and its NatSpec.
  *Risk:* a fifth compliance requirement we have not foreseen forces a registry swap through
  `setClaimTopicsRegistry` — recoverable, but a live-system operation that briefly changes the verification rule.
- **Option C — lower to `3`.** Caps `isVerified` at ≈ 58k, close to MS1's real cost. *Cost:* none.
  *Risk:* too tight to absorb Phase 2 without a swap; three is barely above the one we use, so the cap stops being
  headroom and becomes a constraint we will hit.
- **Option D — keep `15` and add a documented operational rule** that adding a topic is a governance action requiring
  a recorded gas impact. *Cost:* none in code; a line in the runbook. *Risk:* a convention, not a guard — the same
  class of protection the project already rejected for the empty topic set ("impossible by construction, not merely
  avoided by convention", Q24's carried requirement).

## Recommendation
**Option B — lower to `5`.** Three reasons that survive a viva. First, the cap's stated job is to bound a cost the
owner can impose on holders, and a bound that permits a 12.5× increase does not really bound it; `5` holds the worst
case to ~4×. Second, the error is asymmetric in `B`'s favour: too low is fixable through `setClaimTopicsRegistry`,
too high is invisible and permanent. Third, `15` was never chosen against a number — the NatSpec calls it "generous
against MS1's one", which is a feeling, not a measurement, and we now have the measurement.

The honest case **for A** is that the owner is us, the gate is not bricked at 15, and swapping a live registry is a
real operational risk that `B` quietly accepts. If that weighs heavier than the standing cost, A is defensible —
but then the figures above belong in the NatSpec, so that `15` is on record as a measured choice rather than a guess.

**Either way:** the measured figures should be written beside the constant. The current NatSpec justifies the cap
without a number in it.

## Decision
**Option B — lower to `5`.** Hard cap, permanent per ADR 0025 (no upgradeable proxies). If Pakistani regulators or
future DeFi compliance requirements demand more topics, redeploy a new `ClaimTopicsRegistry` with a higher constant
via `setClaimTopicsRegistry` at that time — the escape hatch is built in. For the FYP, 5 gives enough headroom
(KYC + AML + accreditation + country + one spare) while capping `isVerified` at ~95k gas.
*(Fahad Naseer, 2026-11-12)*

**On disk:** `contracts/src/registry/ClaimTopicsRegistry.sol:37` → `uint256 public constant MAX_CLAIM_TOPICS = 5;`
— changed and verified (115/115 tests pass).

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[Thread - T1 Identity Layer]], [[Q24 - What is our KYC claim topic number]], [[Q02 - Which claim topics make a wallet verified, an]]

---

## Addendum — 2026-11-12, re-measured at the decided cap (🐞 Debugger)

**The `~95k` estimate is confirmed almost exactly.** At `MAX_CLAIM_TOPICS = 5`, with five topics required and all five
satisfied, `isVerified` costs **94,605 gas** against the **94,584** this note projected — a 21-gas, 0.02% error. The
marginal came out at **18,115** per topic against the projected 18,136. The cap now refuses a sixth topic
(`TooManyClaimTopics(5)`), and the full suite is green at the new constant: `forge build` ✅ · `forge fmt --check` ✅ ·
`forge test` **115 passed, 0 failed**. Both the cap test and the invariant read `MAX_CLAIM_TOPICS()` from the contract
rather than hardcoding `15`, so neither needed editing.

**But the figures this note was decided on are warm-path figures, and I have to correct that.** All the measurements
above — in the table and in the Decision — were taken on a *second* call, after the first had already warmed the
registry, the storage, the identity and the issuer. A real transfer is the **first** thing in its transaction to touch
those contracts, so it pays cold SLOAD and cold account-access prices. Re-measured from fully cold state (all wiring
moved into `setUp`, so the EVM access list resets before the measured call), one deployment per topic count, real
vendored `Identity` + `ClaimIssuer`:

| Required topics | **COLD — what a transfer pays** | warm — repeat call |
| --- | --- | --- |
| 1 (MS1 today) | **93,149** | 22,143 |
| 2 | 145,258 | 40,252 |
| 3 | 197,372 | 58,366 |
| 4 | 249,489 | 76,483 |
| **5 (the decided cap)** | **301,611** | **94,605** |
| marginal per extra topic | **~52,116** | ~18,115 |

Settings unchanged: solc `0.8.26`, `evm_version = "cancun"`, `optimizer_runs = 200`.

**What this does and does not change.**

It does **not** reverse the decision — it strengthens it. Extrapolating the cold marginal, the rejected cap of `15`
would have cost roughly **820k gas** per verification, not the 276k this note reported. Option B was the right call on
the warm numbers and is a clearer call on the cold ones.

It **does** change what "~95k" means, and that number is quoted in the Decision block above. The honest figure for a
transfer at the decided cap is **~302k of verification**, before the token's own ~50k and before any compliance
module. At MS1's single topic it is **~93k**. If the Decision's "capping `isVerified` at ~95k gas" was read as the
cost a holder pays, that reading is wrong by about 3.2× — and the correction is recorded here rather than absorbed,
per AC-T1-4's own standard.

Whether ~302k at the cap is still acceptable is Fahad's to say. It is not a new question: `5` remains far below
anything that bricks a transfer, MS1 uses one topic at ~93k, and the four spare topics are headroom nobody is
required to spend. I am not reopening the decision — only making sure the number under it is the real one.

**Condition met — 2026-11-12.** The measured figures are now in the contract. `ClaimTopicsRegistry.sol:30-60`
records the cold/warm table with the compiler settings beside it, marks cold as the figure to read and why, states why
`5` rather than more (the replaced `15` extrapolates to ~820k cold), and notes that a low cap is the safe error because
`setClaimTopicsRegistry` makes it replaceable. "Generous against MS1's one" is gone. `forge build` ✅ ·
`forge fmt --check` ✅ · `forge test` **115 passed, 0 failed**. Nothing remains owed on this decision.
