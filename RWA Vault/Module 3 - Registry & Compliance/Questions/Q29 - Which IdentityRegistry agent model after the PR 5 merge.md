---
type: decision
id: M3-Q29
module: M3
status: decided
raised_by: "Claude, during the PR #2 and PR #5 merge into feat/finance-modules"
raised_on: 2026-11-22
blocks: ["contract build on feat/finance-modules", "merge to main"]
recommendation: "A — restore the agent-role model (OwnerAgentRoles and isAgent) on IdentityRegistry from PR #5"
decision: "A — PR #5 agent model (OwnerAgentRoles, multi-agent) on IdentityRegistry, plus PR #5 IdentityRegistryStorage and TrustedIssuersRegistry (Option 1). Storage and issuer tests rewritten to match. Decided by Fahad, 2026-11-22."
decided_by: "Fahad Naseer"
decided_on: "2026-11-22"
adr: none
tags: [rwa-vault, decision, m3, merge]
updated: 2026-11-22
---
# Q29 — Which IdentityRegistry agent model do we keep after the PR #5 merge?

**What broke.** The merge kept the feature branch's `IdentityRegistry.sol` (conflicts go to `feat/finance-modules`, Fahad's rule). That version has no agent roles. PR #5's `DeployM3.s.sol` and its tests call `identityRegistry.isAgent(...)` (`script/DeployM3.s.sol:164`, `test/script/DeployM3.t.sol:66-67`), so `forge build` fails with error 9582.

**Options.**
- **Option A — keep PR #5's agent model.** Take PR #5's `IdentityRegistry` with `OwnerAgentRoles` (`src/access/OwnerAgentRoles.sol`). Deploy checks stay. *Cost:* a conflict resolution that overrides the feature-branch rule for this one file. *Risk:* low; the code exists and was tested in PR #5.
- **Option B — keep the feature branch's registry.** Remove the `isAgent` checks from the deploy script and its tests. *Cost:* deploy stops checking the agent role. *Risk:* the registry's agent permissions are no longer verified at deploy time.

**Recommendation.** A. The deploy checks exist to prove the agent role is set. Removing them weakens that proof, and the code for A already exists.

**Outcome (2026-11-22).** Build passes; 285 of 285 contract tests pass. Test fixes made to match ADR 0029 (KYC topic permanent, seeded by constructor) and Q27 (topic limit 5). See the Module 3 thread, entry of 2026-11-22.

**Blocks.** A clean `forge build` on `feat/finance-modules`, and the merge to `main`.

Up: [[00 M3 Dashboard]] · Related: [[Decisions/Decisions Log]], [[Threads/Thread - T1 Identity Layer]]
