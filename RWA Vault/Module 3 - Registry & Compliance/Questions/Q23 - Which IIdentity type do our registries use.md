---
type: decision
id: M3-Q23
module: M3
status: decided
raised_by: researcher
raised_on: 2026-11-11
blocks: [T1.1, T1.2, T1.5]
recommendation: "A — delete ours, import upstream's IIdentity, so one type exists in the system"
decision: "Q23a = copy-vendor (supersedes the 2026-11-11 answer of Option A)"
decided_by: Fahad Naseer
decided_on: 2026-11-11; superseded 2026-11-12
adr: "0028 (Reserved, stale slug — see note); 0031 supersedes ADR 0012's submodule wording (Reserved, claimed+committed 2026-11-12)"
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-12
---
# Q23 — When we vendor `onchain-id`, which `IIdentity` type do our registries use?

**Why it matters (plain words):** We wrote our own `IIdentity` interface, and Tokeny's vendored code implements *its*
`IIdentity`. To Solidity those are two **different types** even though they look identical, so our `registerIdentity`
will not accept a vendored identity contract without a cast or an adapter. Choose badly and either our T0 interface
suite stops being ours, or we silently throw away type checking at the one seam where a wrong address cannot be undone
— ADR `0025` means no proxies, so a bad wiring is a redeploy.

**On disk now:** `contracts/src/registry/interfaces/IIdentityRegistry.sol:7` → `import "../../identity/interfaces/IIdentity.sol";`
and line 46 → `function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external;`.
`contracts/src/identity/interfaces/IIdentity.sol:14` → `interface IIdentity is IERC734, IERC735` — **our own
declaration**, not a re-export. `onchain-id` is **not yet a submodule**: `.gitmodules` has only `forge-std` and
`openzeppelin-contracts`.

**Blocks:** T1.1 (vendoring), T1.2 (adapter tests), T1.5 (`IdentityRegistry`) · **Does not block:** T1.3, T1.4, and
every task outside T1

## Options
- **Option A — Delete ours; import upstream's `IIdentity`.** Our four registry interfaces import from the submodule.
  *Cost:* under a day, but it edits T0's interface surface and the T0.5 acceptance spec was written against our type.
  *Risk:* part of our "interface-first" suite becomes upstream's, which weakens ADR `0012`'s "we implemented the
  standard" claim slightly; and an upstream bump can move the type under us.
- **Option B — Keep ours; cast at the boundary** (`IIdentity(address(identityContract))`). *Cost:* one line.
  *Risk:* the cast compiles whatever address it is given, so it removes the compiler's only check at the exact seam
  where a wrong identity address is unrecoverable under ADR `0025`. This is the cheap option that fails silently.
- **Option C — A thin adapter contract** wrapping an upstream identity behind our `IIdentity`. *Cost:* 1–2 days plus
  tests. *Risk:* a second contract per investor identity, more gas on every `isVerified`, and a new thing to audit —
  for type tidiness rather than behaviour.

## Recommendation
**Option A**, because one `IIdentity` should exist in the system and the vendored contracts are the ones that actually
have to be callable. Option B's cast is the kind of guard-removal that looks free and is discovered years later; Option
C buys type purity with runtime cost and an extra audit surface. If A is taken, the T0.5 acceptance spec must be
re-run to confirm nothing it asserts depended on our declaration.

## Decision — superseded, then retaken as Q23a

### Q23, 2026-11-11 — Option A (SUPERSEDED, and one of its stated reasons was false)
**Option A — delete our `IIdentity`, import upstream's.** Taken on the Researcher's recommendation.

**Why it did not survive.** Two separate findings, one external and one internal:
1. **Option A cannot compile.** Upstream `onchain-id` 2.2.1 declares `pragma solidity 0.8.17;` — an **exact** pin,
   verified by fetching `raw.githubusercontent.com/onchain-id/solidity/2.2.1/contracts/interface/IIdentity.sol`
   directly rather than relying on a relay. All ten of our registry and identity interfaces declare
   `pragma solidity ^0.8.20`, and `contracts/foundry.toml:28` pins `solc_version = "0.8.26"`. Solidity compiles a file
   together with its whole import closure under one compiler, so an import edge needs a version that is simultaneously
   exactly 0.8.17 and at least 0.8.20. There is none.
2. **The argument used against Option B was wrong.** It claimed a mis-wired identity could not be undone, because
   ADR `0025` forbids proxies. But `contracts/src/registry/interfaces/IIdentityRegistry.sol:64` declares
   `function updateIdentity(address _userAddress, IIdentity _identity) external;`, and
   `ITrustedIssuersRegistry.sol:31` and `:34` declare `removeTrustedIssuer` and `updateIssuerClaimTopics`. A wrong
   address is corrected by one owner or agent call — no redeploy, no holder migration. The Researcher specified that
   interface itself and then argued against B without re-reading it; it raised and owned the error unprompted.

### Q23a, 2026-11-12 — COPY-VENDOR UPSTREAM WITH PROVENANCE
**Decision: copy upstream's `onchain-id` source into the repository with a provenance script, set the pragma
ourselves, and compile everything under our existing `0.8.26` pin.** _(Fahad Naseer, 2026-11-12)_

**Why this rather than Option B (keep ours, cast at the boundary).** B is genuinely cheaper now that A's benefit is
priced honestly, and the Researcher recommended it on schedule grounds — MS1 is week 6 with M4 at 0%. It was rejected
on a build finding that B's "one line" framing hides: `contracts/foundry.toml:28` sets `solc_version` explicitly in
`[profile.default]`, which pins the compiler for the **whole project** and stops Foundry resolving a version per file.
A file declaring `pragma solidity 0.8.17;` therefore fails to build **whether or not anything imports it** — so under
B, upstream's Solidity cannot live in the Foundry project at all. That is fatal to B's own safety net, because the
replacement check B relies on is an integration test that registers a **real** upstream `Identity` and asserts
`isVerified` goes true end to end, and that test needs upstream's source in-tree to compile. The ways out are to drop
the `solc_version` pin — re-opening a decision T0.6, the T0.5 acceptance spec and every M3 contract rest on — or to
commit upstream's **prebuilt bytecode** and deploy it via `vm.deployCode`. The second is the deciding point:
**committing prebuilt bytecode is vendoring too, in a form nobody can read, review or recompile.** If we are vendoring
either way, we vendor source.

**What makes this cheap here rather than exotic.** The pattern already exists in this repository:
`scripts/vendor-pqclean.py` and `scripts/verify-vendor.py` copy-vendor PQClean with a verifiable link upstream. This
is the same machinery pointed at a second dependency, not new machinery. Licences align — `onchain-id` is GPL-3.0 and
so are we, and the GPL-3.0 headers have been in place since `0b2dd0e`.

**Rejected, with reasons:** forking `onchain-id` to our own org — heaviest, and we then maintain a fork. Moving our pin
to `>=0.8.27` for beta3 — a beta dependency on the MS1 path, and it moves a pin the whole module rests on; the
Researcher rejected it firmly and that stands. Lowering our pin to 0.8.17 — dead twice over, because our ten files
declare `^0.8.20` and would reject a 0.8.17 compiler, and because `contracts/foundry.toml:52` pins
`evm_version = "cancun"`, which solc 0.8.17 cannot target at all. Named here explicitly because it is the first thing
a reader will propose.

**Carried requirements:**
- Re-run the **T0.5 acceptance spec** after the swap — it was written against our own declaration.
- A **superseding ADR for 0012**, whose Costly paragraph says "A third submodule enters the build": this is a
  copy-vendor, not a submodule. 0012 is Accepted and therefore immutable, so it cannot be edited.
- The provenance script must pin an upstream **commit or tag** and be verifiable by re-running it, matching what
  `verify-vendor.py` does for PQClean.
- ADR `0028` keeps its number and its filename slug, which now reads as historical: the slug says "use upstream's
  IIdentity", and under Q23a we vendor that source rather than importing it from a submodule. The number was claimed
  by commit for the *question*, and AGENTS.md forbids renumbering, so the slug stays stale by design.

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[T0 - Interface PR]]
