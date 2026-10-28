---
tags: [rwa-vault, m3, thread, t0]
task: T0.7
status: open
lead_agent: researcher
updated: 2026-10-28
---
# 💬 Agent Thread — T0.7: `IReserveAttestationSource` Specification

> **Topic:** The written specification for the seam through which an attested reserve enters the chain — the half of MS1's gate that the compiler does not check.
> **Status:** 🧭 Open, triggered 2026-10-28. Interface slice exists and compiles; the full spec is owed.

---

### 2026-10-28 · 🎭 Custody session → 🧭 Researcher · HANDOFF

**Context:** Fahad asked for T0.7 to be completed. T0.6 is verified and checkmarked; T0.7 is the last open item in T0 apart from the T0.8 consumer sign-off. The interface file exists and compiles, so the **code half is done and the written specification is what is outstanding** — the file's own header says so: _"Only the slice T0.6 needed to compile; T0.7's full research is still owed."_

**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol` (56 lines) → `struct ReserveAttestation { bytes32 assetId; uint256 reserve; uint64 seq; uint64 valuationTs; }`, `error BadAttestationSig()`, `function latest(bytes32) external view returns (ReserveAttestation memory)`, `function hasAttestation(bytes32) external view returns (bool)`. `submitAttestation(bytes)` is deliberately **absent** from the interface.

**Message — the seven points the specification has to settle:**

1. **The submit path.** `submitAttestation(bytes)` is excluded on purpose, because the Phase 2 M5 oracle has no envelope to submit. That means nobody has specified who may call it on the MS1 implementation, what the envelope bytes contain, or its error taxonomy.
2. **ADR `0027` postdates the interface comment and changes the answer.** Clause 1 is verified **off-chain for MS1** with the envelope hash anchored. The spec must absorb this rather than restate the older "verification happens on the source at submit time" wording.
3. **Q11 = B and Q17 land on this seam.** The insurer co-signs 2-of-2, and the fifth admission clause (policy coverage ≥ attested value, policy not expired) is checked **at the source on submit**, not in the registry. Neither the second signer nor the policy fields appear in the struct or the errors today.
4. **Replay and monotonicity at the source.** Clause 2 (strictly increasing `seq`) is checked by the registry at `admit`. State explicitly whether the source also rejects a stale or repeated `seq` on submit, or accepts anything and lets the registry be the only gate.
5. **The zeroed-struct hazard.** `latest()` returns a zeroed struct when no attestation exists — reserve 0, seq 0, `valuationTs` at the Unix epoch. A caller that skips `hasAttestation` sees an unattested bar as an empty one. The registry reverts `NoAttestation` today; the spec must make that a **stated requirement with a test**, not a convention.
6. **Units, restated as a requirement.** `reserve` is in the token's base units — fine grams × 10¹⁸ for gold (ADR `0020`). Gross weight never appears. The spec should say what a conforming implementation must do if its upstream source quotes gross or per-ounce.
7. **What M5 must satisfy in Phase 2.** This is the only M3 interface that a module written weeks later, by someone not in these conversations, has to implement exactly. `assetId` is pinned as the struct's first member and cross-checked at `admit` (`AssetIdMismatch`) precisely because a wrongly keyed source could hand one asset's reserve to another with every clause passing.

**Decisions:** Route any decision this raises back to the custody session rather than ruling it alone. It will be put to Fahad in chat and **logged in Obsidian either way, answered or not** — that is his explicit instruction.

**Blocks/Unblocks:** T0.7 blocks no build task directly, and T2.2/T3.1/T6.1a can continue against `AssetRegistryMock`. It does gate the **attested-reserve half of the MS1 gate**, which the compiler cannot check.

---

### 2026-10-28 · ⌨️ Coder → 🧭 Researcher · ASK

**Context:** The user asked the Coder to work on T0.7. T0.7 is a research note first, so the Coder is not writing code until the Researcher hands off a plan with acceptance criteria. The user confirmed this routing.
**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol` → `struct ReserveAttestation { bytes32 assetId; uint256 reserve; uint64 seq; uint64 valuationTs; }`, `error BadAttestationSig()`, `latest(bytes32)`, `hasAttestation(bytes32)`. Its header still says signature verification "happens on the source at submit time", which ADR 0027 / Q18 = A (off-chain verification, allow-listed Tier 1 submitter, envelope hash anchored) now contradicts.
**Message/Question/Finding:** Please write the T0.7 spec and hand back a Coder plan with ACs here. Expected code half: at least a NatSpec pass for ADR 0027; possibly new members or tests for points 3 and 5 above. The Coder will not add or rename any interface member the spec does not name. Note: AGENTS.md records Q17 = B (insurer 2-of-2 and policy clause are Phase 2), which narrows point 3 for MS1.
**Blocks/Unblocks:** Coder work on T0.7 is blocked on this handoff.

---

### Log of decisions raised by this task

#### 2026-10-28 · 🎭 Custody session → 👤 Fahad · ASK — how is T0.8 consumer sign-off satisfied?

**Context:** T0 stands at 7/8. T0.6 is verified, T0.7 is in progress, and **T0.8 — "consumer sign-off (M4, M5, M9
owners) on interface signatures" — cannot be performed as written.** Logged here per Fahad's instruction that a
decision is recorded whether or not he has answered.

**On Disk Now:** `RWA Vault/Module 3 - Registry & Compliance/Tasks/T0 - Interface PR.md:23` →
`- [ ] **T0.8** Consumer sign-off (M4, M5, M9 owners) on interface signatures.`
The rule it comes from: `RWA Vault/Modules/All Modules.md:50` → _"Open with an **interface-only PR**, approved by its
consumers before any implementation."_

**Why it cannot be done as written:** M4 is 0%, M5 and M9 are not started, so no consumer exists that could tell us
whether the signatures fit. `RWA Vault/Project Memory/Team.md` lists Fahad, Hassan and Fawaz but records **no
per-module owner**, so "the M4 owner" is not yet a named person. The task therefore has neither a signatory nor a
basis for signing.

**Why it still matters, and more than usual here:** ADR `0025` made M3's contracts **immutable — plain deploys, no
proxies**. An interface error is a redeploy and a migration, not an upgrade. And `IReserveAttestationSource` is the one
interface a later module (M5, Phase 2) must implement *exactly*, written by someone who will not be in these
conversations.

**Options:**
- **(a) Assign the three module owners by name now**, and have each read `IAssetRegistry.sol` and
  `IReserveAttestationSource.sol` against their own module's needs, recording a dated sign-off in this thread.
  *Cheap, honest, and satisfies the rule as written — but a sign-off from someone who has built nothing is weak
  evidence.*
- **(b) Defer T0.8 explicitly** until M4 and M5 start, with the reason recorded, and re-open it as a gate on those
  modules rather than on M3. *Honest about the sequencing; leaves M3's interfaces unreviewed by anyone but their
  author.*
- **(c) Replace the signature with a conformance test.** Write the test suite M5 must pass to be a valid
  `IReserveAttestationSource` — zeroed-struct handling, `assetId` cross-check, monotonic `seq`, unit basis — and treat
  a passing implementation as the sign-off. *Converts a human promise into something executable, and matches the
  project's own rule that "the acceptance test must be runnable by a third party". Most work of the three, and the
  only one that still means something in Phase 2.*

**Recommendation:** **(c), with (a) alongside** — name the owners now so the next review has a signatory, and build the
conformance suite as part of T0.7 while the interface is still being specified rather than after T4 is built on it.

**Blocks/Unblocks:** T0.8 blocks the formal closure of T0 and nothing else. It does not block T1–T5.

**Status:** ⏳ Awaiting Fahad.

---

_(further decisions appended here as they arise, whether or not Fahad has answered)_

---

### 2026-10-28 23:05 · 🧭 Researcher → ⌨️ Coder · HANDOFF (re-append — the 14:10 copy was lost to a concurrent write)

**Context:** T0.7 spec complete — [[T0.7 - Reserve Attestation Source]]. You were right that this entry was missing: the file held 3 entries and `AC-T07` appeared nowhere in the repo. Re-appending in full. **Headline unchanged: the shared interface does not change** — not one signature, name or type.

**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol:8-11` → `"Signature verification (admission clause 1) therefore happens on the source at submit time"` — **false since ADR `0027`**, and the one thing in the file that must change.

**Message — three deliverables, nothing else.**

**D1 · NatSpec correction** (`IReserveAttestationSource.sol`). Replace the header's clause-1 sentence with §2's wording, including **"This contract verifies no signature."** Re-document `BadAttestationSig` per §2.1 — kept and declared, raised by the off-chain verifier's reporting path, reserved for a Phase 2 on-chain implementation, and **not** reading as though this contract raises it. Strike `"Only the slice T0.6 needs to compile; T0.7's full research is still owed"`; point at the spec. Comments only.

**D2 · `contracts/test/registry/ReserveAttestationSourceConformance.t.sol`** — `abstract`, shaped like `ERC3643Acceptance.t.sol`, nine tests C1–C9 from §7.

**D3 · Nothing else.** The MS1 implementation is **T4.4**.

**Your two questions, ruled:**

**① The `_attest` hook — your provisional choice is adopted, with one change: it returns `bool`.**

```solidity
function deploySource() internal virtual returns (IReserveAttestationSource);
function _attest(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs)
    internal virtual returns (bool accepted);
```

Real gap in my §7 — the suite had no way to cause an attestation, and C9 forbids naming `submitAttestation`. Your hook fixes it and keeps C9 true. The `bool` matters: the subclass owns the knowledge of *how its source refuses*, and translates that into `false` (MS1: `try source.submitAttestation(...) { true } catch { false }`; M5: whatever its oracle path returns). An internal function that reverts cannot report a refusal, so without the return the suite cannot distinguish "refused" from "exploded".

**② C4 asserts the STATE INVARIANT, not the control flow — neither of your two options.**

You are right that the suite cannot name `StaleSequenceAtSource`: it lives on the MS1 implementation (T4.4), not the shared interface. But `expectRevert` with any reason is also wrong, and not only because it breaches the house rule against unnamed reverts — **a conforming implementation is not required to revert.** MS1 reverts (§4). An M5 oracle might legitimately ignore a stale update and carry on. Both conform.

What the interface actually requires is that **a non-increasing `seq` does not take effect.** So:

- **C4a** two accepted attestations → `latest().seq` strictly increased and `reserve` updated.
- **C4b** replay a non-increasing `seq` → **`latest()` is unchanged, field for field**, regardless of whether `_attest` returned `false` or reverted. Assert the struct, not the control flow.
- **C8** same shape for a future `valuationTs`: attempt it, assert `latest()` unchanged.

Asserting state rather than mechanism is what makes this suite portable to an implementation written by someone who has never read this thread — which is the entire point of it.

**Acceptance criteria:**
- **AC-T07-1** `forge build` + `forge fmt --check` green; the interface's public surface **byte-identical** (same signatures, names, types, order). Comments only — a signature diff must be empty.
- **AC-T07-2** No `"happens on the source at submit time"` remains; the replacement cites ADR `0027` and states this contract verifies no signature.
- **AC-T07-3** `BadAttestationSig`'s NatSpec names the off-chain verifier as its source and does not attribute it to this contract.
- **AC-T07-4** The conformance contract exists, is `abstract`, declares `deploySource()` **and `_attest(...) returns (bool)`**, and holds C1–C9 with those names.
- **AC-T07-5** `forge test` runs **zero** tests from it (abstract), and it compiles.
- **AC-T07-6** A throwaway concrete subclass over a minimal mock makes **all nine pass** — proving the suite is satisfiable, not merely well-formed. Not committed; report the run.
- **AC-T07-7** C2 asserts `assetId == bytes32(0)` in the zeroed case, not merely `reserve == 0`.
- **AC-T07-8** C4b and C8 assert `latest()` is unchanged **field by field** and contain **no** `expectRevert`.

**Blocks/Unblocks:** Unblocks T0.7's code half. Does not unblock T4.4.
