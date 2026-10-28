---
type: decision
id: M3-Q23
module: M3
status: decided
raised_by: coder
raised_on: 2026-10-28
blocks: [T1.1]
recommendation: "A — vendor onchain-id 2.2.1 unmodified, compile that folder with its own 0.8.17; our code stays on 0.8.26"
decision: "A — vendor 2.2.1 unmodified, compiled with 0.8.17 for lib/onchain-id only"
decided_by: Fahad Naseer
decided_on: 2026-10-28
adr: "none (ADR 0012 stands; no upstream patch)"
tags: [rwa-vault, decision, m3, t1]
updated: 2026-10-28
---
# Q23 — How do we compile the vendored onchain-id, given it pins an older Solidity?

**Why it matters (plain words):** ADR 0012 vendors Tokeny's `onchain-id`, but every release pins a compiler that is not
ours. Stable `2.2.1` (`a483cda`) says `pragma solidity 0.8.17` exactly. The newest tag, `2.2.2-beta3`, needs
`^0.8.27`. So "reconcile to our 0.8.26" (the T1.1 wording) was impossible without editing upstream, and ADR 0012 says
patching upstream means superseding it.

**Blocks:** T1.1 · **Does not block:** T4, T2 (built meanwhile)

## Options
- **Option A — Vendor 2.2.1 unmodified, compile it with 0.8.17.** Our code stays on 0.8.26 and talks to it only
  through our own `IIdentity` / `IClaimIssuer`. *Cost:* a per-path compiler setting. *Risk:* identity-call gas is
  measured under 0.8.17 code, and the gas report must say so.
- **Option B — Patch the pragma to 0.8.26.** *Cost:* a fork plus a superseding ADR. *Risk:* we stop running audited
  bytes.
- **Option C — Build Identity + ClaimIssuer in-house** (ADR 0012 Option B). *Cost:* days, plus a superseding ADR.
  *Risk:* the claim-signature bugs ADR 0012 wanted to avoid.

## Recommendation
**Option A.** It keeps the audited upstream bytes unchanged, matches ADR 0012 as accepted, and needs no new ADR.

## Decision
**Option A.** Vendor `onchain-id` 2.2.1 unmodified as a submodule, compiled with 0.8.17 for `lib/onchain-id` only; all
our code stays on 0.8.26. Chosen on the Coder thread's decision card. _(Fahad Naseer, 2026-10-28)_

Build detail: [[Specs/T1 - Identity Layer Build Spec]] §1.

Up: [[Open Questions for Fahad]] · Related: [[Decisions Log]], ADR 0008, ADR 0012
