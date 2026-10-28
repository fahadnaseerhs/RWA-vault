---
type: spec
task: T4
module: M3
status: ruled
from: Researcher
to: [Coder, Debugger]
tags: [rwa-vault, m3, t4, rulings]
updated: 2026-10-28
---
# 🧭 T4 — Researcher rulings, round 1 (readings 1–6) + the T4.3 source spec

Answers the five Coder readings (`21e3091`, branch `claude/project-thread-8x7juo`) and the Debugger's reading 6
(branch `claude/project-thread-sftq63`) in [[Threads/Thread - T4 AssetRegistry & Admission]]. Also specifies T4.3, the
MS1 attestation source, which the Coder asked for. Rulings follow the precedence rule: ADR over NatSpec prose.

## Rulings on the readings

| # | Reading | Ruling | Why |
| - | ------- | ------ | --- |
| 1 | Re-attestation below current supply: accept + `UnderReserve` (code) vs `ReserveTooLow` NatSpec | **Code is right. Fix the NatSpec.** `ReserveTooLow` is raised on **first admission only**. | ADR 0019 §3, Q14 = B. The NatSpec is the defect. |
| 2 | LIVE re-attestation with no token bound treats supply as 0 | **Confirmed.** Add a one-line comment saying why: no token means nothing can have been minted. | A revert here would block the custodian's re-attestation for a wiring gap that has no backing risk. |
| 3 | `register` does not check `assetId == keccak256(bytes(assetRef))` | **Enforce it.** New error `AssetRefMismatch(bytes32 assetId, bytes32 expected)`. An empty `assetRef` reverts `EmptyAssetId()`. | The interface defines the id as the slug hash. Without the check, one agent typo stores a slug that resolves to a different id, permanently. The console and script look assets up by slug. |
| 4 | Zero owner rejected with `NotOwner(address(0))`, owner `immutable` | **Confirmed.** | ADR 0025. Reusing the existing error keeps the translation table unchanged. |
| 5 | `admit` on FROZEN reverts `AssetNotLive` | **Confirmed**, and it is safe because of change (b) below: after `unfreeze`, minting stays blocked until the reserve is fresh again. | Interface says so. `unfreeze` is owner-only (ADR 0019 §4). |
| 6 | Swapping the source keeps `lastSeq`, so a new source starting lower blocks admits | **Keep `lastSeq` per asset. A new source must continue each asset's sequence.** Document it on `setAttestationSource`. | The replay guard belongs to the asset, not the source. Resetting it on a swap would let an old envelope replay through the new source. Blocking is the fail-closed direction. M5's source spec must start above `lastSequenceOf`. |

## Changes for the Coder (T4.1 follow-up, before T2)

**(a) NatSpec.** In `IAssetRegistry.sol`, `ReserveTooLow`'s `@dev` becomes: *"Raised by `admit` (agent) on first
admission only, against `intendedSupply`. A re-attestation below current supply is accepted and emits `UnderReserve`
(ADR 0019 §3)."* Comment-only, no selector change.

**(b) `valuationTsOf`: an additive view, needed by ADR 0021.** ADR 0021 says a stale reserve blocks **minting**. Today
nothing can see how old the admitted reserve is: the registry stores the reserve and the sequence but not the
valuation time. Add:

```solidity
/// @notice Returns the valuationTs of the last accepted attestation; 0 if none. Anyone may call.
function valuationTsOf(bytes32 assetId) external view returns (uint64);
```

Store it in `admit` next to `_reserve` and `_lastSeq`. `AssetLiveModule` (T2.2) uses it for the mint-time freshness
check. This is an addition, so every existing selector, event and error name stays as it is.

**(c) `AssetRefMismatch`.** Add the error to the interface and the check to `register` (reading 3).

**(d) `setAttestationSource` NatSpec.** Add: *"The per-asset sequence (`lastSequenceOf`) is kept across a swap. A new
source must continue each asset's sequence above it."*

**Tests:** `test_RegisterRejectsSlugMismatch`, `test_RegisterRejectsEmptyRef`, `test_ValuationTsOfRecordsAdmitted`,
`test_SourceSwapKeepsLastSeq` (the new source's lower seq reverts `StaleSequence`).

---

## T4.3 — `CustodianAttestationSource` (MS1 source, ADR 0017 + ADR 0027)

**File:** `contracts/src/registry/CustodianAttestationSource.sol`, implementing `IReserveAttestationSource`.
Immutable (ADR 0025). Owner is set in the constructor; zero owner reverts `NotOwner(address(0))`.

**Roles.** `owner` (2-of-3 multisig) manages submitters. `submitter` is the Tier 1 service key (ADR 0015); in MS1 the
same address as the registry agent, but a separate allow-list, because in Phase 2 the source is replaced and the
agent is not.

```solidity
event SubmitterAdded(address indexed account);
event SubmitterRemoved(address indexed account);
event AttestationSubmitted(
    bytes32 indexed assetId, uint64 seq, uint256 reserve, uint64 valuationTs,
    bytes32 envelopeHash, address indexed submitter
);

error NotOwner(address caller);
error NotAuthorisedSubmitter(address caller);
error InvalidSubmitter(address account);          // address(0)
error SubmitterUnchanged(address account);        // add existing / remove absent
error EmptyAssetId();
error MissingEnvelopeHash();
error SequenceNotIncreasing(uint64 submitted, uint64 latest);

function addSubmitter(address account) external;      // owner
function removeSubmitter(address account) external;   // owner
function isSubmitter(address account) external view returns (bool);
function submitAttestation(ReserveAttestation calldata att, bytes32 envelopeHash) external; // submitter
function envelopeHashOf(bytes32 assetId) external view returns (bytes32); // hash of the latest
```

**What `submitAttestation` does:** checks the caller, `att.assetId != 0`, `envelopeHash != 0`, and
`att.seq > latest(att.assetId).seq`. Then it stores the struct and the hash and emits `AttestationSubmitted`. M9
anchors from that event.

**What it deliberately does not do:**
- **No signature check, and no "verified" flag.** Under ADR 0027 the submitter verifies the ML-DSA-65 signature
  off-chain (M2 verifier, or `pqctl` today) and refuses to submit on failure. A flag that can only ever be `true` is
  noise. `BadAttestationSig` is therefore raised by the **off-chain step** in T6.1a (`pqctl` exit code → that error →
  the §3.4 sentence), never on-chain in MS1. The ADR 0027 disclosure covers this: on-chain, clause 1 trusts the
  submitter.
- **No reserve, freshness or supply judgement.** Clauses 2–4 belong to `AssetRegistry.admit`. The source's own
  sequence check only stops a trusted-key typo from overwriting a newer pending attestation. It does not replace
  clause 2.
- **`reserve == 0` is accepted.** A custodian saying "zero" is information. The registry then blocks minting.

**`envelopeHash` is opaque here.** Its digest is M2 T3.8's call (the leaf hash M9 uses). Until T3.8 exists, T6.1a
computes `keccak256(envelopeBytes)` and says so in its receipt. The contract stores whatever 32 bytes it is given.

**Tests** (`contracts/test/registry/CustodianAttestationSource.t.sol`): submitter gating; owner gating on both
setters; `InvalidSubmitter` and `SubmitterUnchanged`; `EmptyAssetId`; `MissingEnvelopeHash`;
`SequenceNotIncreasing` for equal and lower seq; `hasAttestation` false then true; `latest` returns the stored struct
with `assetId` first; the event carries all six fields. Plus one integration test with the real `AssetRegistry`:
submit, then admit, then LIVE.

**Acceptance (Researcher checks):** the test list above passes, `forge fmt --check` is clean, and the source file
has no import of `AssetRegistry` (the seam stays one-way, ADR 0017).

Up: [[Threads/Thread - T4 AssetRegistry & Admission]] · Task: [[Tasks/T4 - AssetRegistry & Admission]]
