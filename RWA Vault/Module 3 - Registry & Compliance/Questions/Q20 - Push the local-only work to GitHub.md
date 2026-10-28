---
type: decision
id: M3-Q20
module: M3
status: decided
raised_by: researcher
raised_on: 2026-10-27
blocks: [T0.6 consumer sign-off, T0.8, T6.0 review]
recommendation: "A — merge the vault PR, then commit and push the local code work on its own branch; restore the deleted PDF and images unless you meant to delete them"
decision: "A — push everything; restore the deleted PDF and PNGs"
decided_by: Fahad
decided_on: 2026-10-28
adr: none
tags: [rwa-vault, decision, m3, task6, repo]
updated: 2026-10-28
---
# Q20 — Should the local-only work be committed and pushed, and were the deleted files meant to go?

**Why it matters (plain words):** on 2026-10-27 the local clone held work nobody else can see: commit `bbc4eb0`
(unpushed), ADRs 0018/0025/0026, `IAssetRegistry.sol`, `IReserveAttestationSource.sol`, `AssetRegistryInterface.t.sol`,
the T6.0 schema and tests, and every new vault note. One disk failure loses T0.6 and T6.0. The working tree also deletes
`docs/RWA-Vault_proposal_v2.pdf` and three `docs/linkedin-assets/*.png` without committing that, and renames the
manuals to `QORA_*`.

**Blocks:** T0.8 (consumers cannot review an interface they cannot see), T6.0 review

## Options
- **Option A — Push everything, restore the deletions.** Merge the vault PR; commit the code (T0.6, T6.0) on its own branch
  and open a PR; `git restore` the PDF and images.
- **Option B — Push everything, keep the deletions** (if the QORA rename replaced them).
- **Option C — Keep it local for now.**

## Recommendation
**Option A**, unless the QORA rename was meant to replace those files — then B.

## Decision
> **Option A (Fahad, 2026-10-28).** All local-only code and docs (T0.6 interfaces and test, T6.0 schema/validator/tests,
> the `docs/manuals` and `docs/reports` moves, architecture diagrams, QORA deliverables) are committed on the vault PR branch;
> the vault notes were already there. `docs/RWA-Vault_proposal_v2.pdf` and the three LinkedIn PNGs were restored in the local
> clone and stay in the repo. The local commit `bbc4eb0` is superseded by the PR — once it merges, reset the local
> `feat/finance-modules` to `origin/feat/finance-modules`.

Up: [[Open Questions for Fahad]] · Related: [[2026-10-27 - Decision Conflict Audit|Audit B5]]
