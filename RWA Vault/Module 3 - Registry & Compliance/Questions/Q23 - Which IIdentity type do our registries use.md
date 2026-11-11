---
type: decision
id: M3-Q23
module: M3
status: decided
raised_by: researcher
raised_on: 2026-11-11
blocks: [T1.1, T1.2, T1.5]
recommendation: "A — delete ours, import upstream's IIdentity, so one type exists in the system"
decision: "A"
decided_by: Fahad Naseer
decided_on: 2026-11-11
adr: "0028 (Reserved stub claimed 2026-11-11; full record owed)"
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-11
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

## Decision
**Option A — delete our `IIdentity`, import upstream's.** One `IIdentity` exists in the system. _(Fahad Naseer, 2026-11-11)_

The deciding argument against Option B, recorded because it is the one that would be forgotten: **a cast compiles whatever address you hand it.** It removes the compiler's only check at the exact seam where a wrong identity address cannot be undone — ADR `0025` means no proxies, so a bad wiring is a redeploy and a holder migration. The cheap option that fails silently.

**Carried:** re-run the T0.5 acceptance spec after the swap, since it was written against our declaration.

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[T0 - Interface PR]]
