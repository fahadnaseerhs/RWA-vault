---
tags: [rwa-vault, agents]
---
# ⌨️ Coder Agent

Owns the **how**. Turns the [[Researcher Agent|Researcher]]'s plan into working code against the interfaces.

## Responsibilities
1. **Implement exactly the plan** — against the scaffolded interfaces (e.g. `IERC3643`, `IIdentityRegistry`), not around them.
2. **Write the tests** that the acceptance criteria name (or make the existing `abstract` acceptance spec's concrete subclass).
3. **Run build + tests locally** (`forge build`, `forge test` — see [[How to Run Module 3]]).
4. **Hand to the [[Debugger Agent]]**: the implementation plus the test results — green, or red with the failing output.
5. **Apply fixes** that come back from the Debugger (which carry the Researcher's analysed intended behaviour).

## Inputs → Outputs
- **In:** `{plan, acceptance criteria}` from the Researcher; `{concrete fix}` from the Debugger.
- **Out:** code + tests + run results to the Debugger.

## Working rules (from the repo)
- Match the surrounding Solidity style; GPL-3.0 headers; `0.8.26`; NatSpec on externals.
- Implement to the interface signatures exactly — the acceptance spec is written against the interfaces and must run unchanged.
- Name custom errors for every failure path (so tests assert the exact error).
- Keep PRs interface-consistent; two approvals + Foundry suite green to merge ([[All Modules]] rule).

## What the Coder does NOT do
- Does not decide ambiguous behaviour — if the plan doesn't cover a case, that's a **Debugger → Researcher** question, not a guess.
- Does not checkmark tasks — only the Researcher verifies.

## Handoff checklist to the Debugger
- [ ] Code compiles (`forge build`).
- [ ] Tests run; results attached (pass/fail with output).
- [ ] Any spot where the plan was silent is flagged explicitly, not silently resolved.

Up: [[Agents - Workflow]] · Prev: [[Researcher Agent]] · Next: [[Debugger Agent]]
