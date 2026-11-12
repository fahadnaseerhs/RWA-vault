---
type: decision
id: M3-Q26
module: M3
status: decided
raised_by: researcher
raised_on: 2026-11-11
blocks: [T1.1, T1.2]
recommendation: "Copy-vendor with a provenance script, pragma set by us, everything compiled at 0.8.26"
decision: "Copy-vendor — the PQClean pattern, superseding ADR 0012's submodule wording"
decided_by: Fahad Naseer
decided_on: 2026-11-12
adr: "0031 (Reserved stub claimed 2026-11-12; full record owed)"
supersedes_mechanism_of: M3-Q23
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-12
---
# Q26 (Q23a) — How do we vendor `onchain-id` when no compiler satisfies both pragmas?

**Why it matters (plain words):** [[Q23 - Which IIdentity type do our registries use|Q23]] chose to delete our `IIdentity` and import upstream's. Then the pin facts came in and that turned out not to compile at all: upstream pins `pragma solidity 0.8.17` **exactly**, our pin is `0.8.26`, and Solidity compiles a file together with its whole import closure under **one** compiler. So Q23's chosen mechanism was unbuildable, and the option set had to be repriced.

**On disk at the time of deciding:** upstream `onchain-id` release 2.2.1 → `pragma solidity 0.8.17;` exact, in `Identity.sol`, `ClaimIssuer.sol` and all four interface files; main the same; 2.2.2-beta3 is `^0.8.27`. `contracts/foundry.toml:28` → `solc_version = "0.8.26"`; `:52` → `evm_version = "cancun"`. 14 of our 18 Solidity files declare `pragma solidity ^0.8.20`.

**Blocks:** T1.1, T1.2 · **Does not block:** T1.3 (built), T1.4, T1.5, T1.6 — all of which hold under any outcome because every option keeps the same ABI

## Options
- **Option A — edit the vendored pragmas in place.** A submodule cannot hold local edits cleanly, so in practice it means forking `onchain-id` to our own org and pinning that. *Cost:* our own fork to maintain plus a superseding ADR. *Risk:* the fork's divergence from upstream becomes invisible.
- **Option B — move our pin to ≥0.8.27 and use 2.2.2-beta3.** *Risk:* a **beta** dependency on the MS1 path, and it moves a pin T0.6, the T0.5 acceptance spec and every M3 contract rest on. **Rejected by the Researcher.**
- **Option C — keep our own `IIdentity`; upstream deploys as its own 0.8.17 artifact.** ABI-compatible, so runtime calls work and only the type name differs. *Cost:* two casts, both correctable via `updateIdentity` / `removeTrustedIssuer`. *Risk:* loses the compiler's check at the seam.
- **Option D — copy-vendor with a provenance script**, pragma set by us, everything compiled at `0.8.26`. *Cost:* ~1 day plus a superseding ADR, because `0012` says "submodule" and this is a copy.
- **Option E — lower our `solc_version` to 0.8.17. REJECTED, and it fails twice:** 14 of our 18 files declare `^0.8.20` and would reject that compiler, so it is a re-pin of T0.6, the acceptance spec and every M3 contract rather than a one-line change; **and** `evm_version = "cancun"` is pinned three lines away in the same file, which solc 0.8.17 cannot target at all (Cancun arrives around 0.8.24). *Named by the custody session; neither the Researcher nor the Coder had spotted it.*

## Recommendation
The Researcher recommended **C**, on the grounds that Q23's benefit had been overstated — the original argument against casting claimed a wrong identity address was unrecoverable under ADR `0025`, and that was **wrong**: `updateIdentity`, `removeTrustedIssuer` and `updateIssuerClaimTopics` all exist, so a mis-wiring is correctable by an agent or owner call. **D was recommended as the better choice if the type safety was wanted anyway.**

## Decision
**Option D — copy-vendor.** Copy upstream's source into the repo with a provenance script, set the pragma ourselves, and compile everything at `0.8.26`. _(Fahad Naseer, 2026-11-12)_

The reasons given, recorded because they are the argument a viva would test:

1. **We already do exactly this.** `scripts/vendor-pqclean.py` and `scripts/verify-vendor.py` vendor PQClean the same
   way — pinned to an immutable upstream commit, with content digests. This is an **established pattern in this
   repository**, not new machinery invented for one dependency.
2. **The licences line up.** `onchain-id` is GPL-3.0 and so are we, so copying the source carries no licence problem.
3. **It keeps the compiler's check** at the one seam where a wrong address is otherwise silent — which is what Q23 was
   protecting, now obtainable without the unbuildable mechanism.
4. **The integration test compiles in-tree under one pinned compiler**, so "the ABI is compatible" becomes a **tested
   property** rather than an assumption carried across two compilation units.
5. **About a day**, plus the superseding ADR.

**Consequences, both accepted:**

- **ADR `0012` says "as a Foundry submodule".** `0012` is **Accepted** and therefore immutable under ADR `0001`, so
  this needs a **superseding record** rather than an amendment — **ADR `0031`**, stub claimed 2026-11-12.
- **A copy has no `git submodule update`,** so upstream drift is invisible unless something checks. The provenance
  script must pin an immutable commit and record content digests, exactly as the PQClean one does, and
  `verify-vendor`-style checking must run in CI. A copy nobody verifies is a fork pretending to be a dependency.

**Q23 stands as decided** — our registries use upstream's `IIdentity` and ours is deleted. Only the *mechanism* of
getting upstream's source into the build has changed, from a submodule to a copy-vendor. Q23's own `decision` field is
unchanged and correct.

Up: [[Decisions Log]] · Related: [[Q23 - Which IIdentity type do our registries use]], [[T1 - Identity Layer]]
