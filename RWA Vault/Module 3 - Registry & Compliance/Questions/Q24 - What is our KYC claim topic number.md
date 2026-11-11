---
type: decision
id: M3-Q24
module: M3
status: decided
raised_by: researcher
raised_on: 2026-11-11
blocks: [T1.3, T1.4, T1.6]
recommendation: "A — 1, chosen by us and fixed for the life of the project"
decision: "A"
decided_by: Fahad Naseer
decided_on: 2026-11-11
adr: "0029 (Reserved stub claimed 2026-11-11; full record owed)"
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-11
---
# Q24 — What number is our `KYC` claim topic, and is it fixed forever?

**Why it matters (plain words):** A claim topic is just a number, and **the issuer picks it** — there is no canonical
registry of topic numbers. Every investor's KYC claim is signed *against that number*, so changing it later invalidates
every claim already issued and every investor has to be re-KYC'd. It is a one-line choice that can never be revisited,
which is exactly the kind of thing that gets picked by accident.

**Why it is not already answered:** Q02 = A decided *how many* topics we require (one, KYC only). It never fixed *which
number* that topic is. The T-REX documentation uses `42` in examples, and examples are not standards.

**On disk now:** `contracts/src/registry/interfaces/IClaimTopicsRegistry.sol:22` → `function addClaimTopic(uint256 _claimTopic) external;`
and line 31 → `function getClaimTopics() external view returns (uint256[] memory);`. No implementation yet, so no number
has been committed anywhere.

**Blocks:** T1.3 (`ClaimTopicsRegistry` seeding), T1.4 (binding the issuer to the topic), T1.6 (the test matrix) ·
**Does not block:** T1.1, T1.2, T1.5's `isVerified` logic, which is topic-agnostic by design

## Options
- **Option A — `1`.** Plain, obviously ours, and reads as "the first topic we require". *Cost:* none.
  *Risk:* collides with another project's `1` if an investor identity is ever shared across platforms — harmless,
  because trust is scoped per issuer *and* topic by `TrustedIssuersRegistry`, so another platform's `1` is not ours.
- **Option B — `42`, following T-REX's example.** *Cost:* none. *Risk:* it *looks* canonical and is not, so a future
  reader may believe it is fixed by the standard and reason from that.
- **Option C — `uint256(keccak256("QORA.KYC.V1"))`.** Collision-proof and self-describing. *Cost:* none.
  *Risk:* unreadable in logs and explorers, and awkward to type in a `cast` command during a demo.

## Recommendation
**Option A — `1`** — with the number recorded in an ADR and in the `ClaimTopicsRegistry` NatSpec as **permanent**.
The collision argument for C does not apply to us: trust is already scoped per issuer *and* topic, so two platforms
using `1` never confuse each other. Readability during the MS1 demo is worth more than theoretical collision-proofing,
and B's only merit is imitation of an example.

**Carried requirement either way:** `getClaimTopics()` must never return an empty array. An empty topic set makes
`isVerified` vacuously true and **silently disables the entire permissioning gate** — it should be impossible by
construction, not merely avoided by convention.

## Decision
**Option A — the `KYC` topic is `1`, fixed for the life of the project.** _(Fahad Naseer, 2026-11-11)_

Recorded as **permanent** in ADR `0029` and in the `ClaimTopicsRegistry` NatSpec. The collision worry about `1` does not bite: trust is already scoped per issuer **and** topic by `TrustedIssuersRegistry`, so another platform's `1` is never ours. `42` was rejected because it looks canonical and is not — a future reader would reason from a false premise.

**Carried:** `getClaimTopics()` must never return an empty array. An empty topic set makes `isVerified` vacuously true and silently disables the whole permissioning gate, so it must be impossible by construction rather than avoided by convention.

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[Q02 - Which claim topics make a wallet verified, an]]
