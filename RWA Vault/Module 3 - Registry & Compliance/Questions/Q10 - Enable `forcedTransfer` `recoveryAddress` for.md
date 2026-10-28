---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q10
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q10 — Enable `forcedTransfer` / `recoveryAddress` for the demo, or defer?
**Why it matters:** the interface includes agent recovery and forced transfer. They are powerful and need extra tests; the acceptance spec does not exercise them.
- **Recommendation:** **implement them** (they're cheap given the freeze machinery) but keep them **out of the MS1 demo path**; add targeted unit tests. Defer only if time-pressed.
- **Blocks:** token implementation scope, test count.
- `Decision:` **Implement them — not optional.** EIP-3643 *mandates* a key-recovery system and agent forced transfer, so dropping them would forfeit conformance (and with it Q1 and Q8). Keep them out of the MS1 demo path, unit-test them directly, and govern `forcedTransfer` by multisig + timelock per Q7. Non-custodiality is delivered by C2/C4 in [[Open Questions - Custody & Tokenisation]], not by removing agent powers. ADR `0015`. _(Fahad Naseer, 2026-10-27)_