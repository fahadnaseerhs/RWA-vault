---
type: decision
id: M3-Q28
module: M3
status: decided
raised_by: debugger
raised_on: 2026-11-12
blocks: [T3.6]
recommendation: "A — six guarantees; the seventh function is a consistency assertion, and AC-T1-4's wording is corrected to say so"
decision: "A — six guarantees. test_RegistryVerificationMatchesHolders is a consistency assertion, not a guarantee. Add NatSpec comment marking it as such. Correct AC-T1-4 verb from 'running' to 'compiling'."
decided_by: "Fahad Naseer"
decided_on: "2026-11-12"
adr: none
tags: [rwa-vault, decision, m3, task0, task3]
updated: 2026-11-12
---
# Q28 — Does `ERC3643Acceptance.t.sol` encode six guarantees or seven?

**Why it matters (plain words):** This file is the merge bar for the token. T3.6 is written as "passing all **6**
guarantees", and whoever implements the token will read that literally — they will subclass the file, see seven test
functions, and have to decide for themselves whether the seventh is part of the contract or incidental. A behavioural
contract that cannot be counted is not a contract. The fix is one line either way; the cost of leaving it is that the
bar is ambiguous at exactly the moment someone is trying to clear it.

**Why it is not already answered:** T0.5 created the file and the "6 core guarantees" wording in the same stroke, and
nothing since has recounted. T1 touched none of it — the file is byte-identical to its T0.5 state, confirmed at the
T1 Debugger gate — so this is a pre-existing discrepancy surfaced by the gate, not something T1 introduced.

**On disk now:** `contracts/test/registry/ERC3643Acceptance.t.sol` declares **seven** `test_` functions:

| # | Function | Line |
| --- | --- | --- |
| 1 | `test_VerifiedWalletCanReceiveMint` | `:47` |
| 2 | `test_MintToUnverifiedWalletReverts` | `:54` |
| 3 | `test_VerifiedToVerifiedTransferSucceeds` | `:61` |
| 4 | `test_TransferToUnverifiedWalletReverts` | `:73` |
| 5 | `test_FrozenWalletCannotTransfer` | `:83` |
| 6 | `test_PausedTokenBlocksTransfer` | `:97` |
| 7 | `test_RegistryVerificationMatchesHolders` | `:111` |

Four places say six: the T1 spec §107 and **AC-T1-4** ("its six guarantees"), `Tasks/T0 - Interface PR.md:20`
("6 core guarantees"), `Decisions/Decisions Log.md:110` ("The **six acceptance guarantees** … are the behavioural
contract"), and `Tasks/T3 - ERC-3643 Token.md:22` (T3.6, "passing all 6 guarantees").

**A second thing to settle in the same breath.** The contract is `abstract` **by design** — `:13-17` says so
explicitly: *"It is `abstract` on purpose — Forge does not run abstract test contracts, so it compiles in CI today
without any implementation present."* Forge therefore does not collect it, which the Debugger gate confirmed by
execution (`forge test --match-contract ERC3643AcceptanceTest` → "No tests found"; the 115-test run contains seven
suites, none of them this one). That is correct and intended, but it means **AC-T1-4 cannot be satisfied by
execution**: the VERIFY table's "must be confirmed by running T0.5 tests" is not achievable until T3.6 supplies the
concrete subclass. The spec's own §107 wording — "the six acceptance guarantees still **compile** unchanged" — is the
only satisfiable reading, and the gate verified it on those terms (unchanged on disk, compiles clean).

**Blocks:** T3.6, which is phrased as a count · **Does not block:** the T1 checkmark — the T1 gate passed on §107's
compile-only reading

## Options
- **Option A — six guarantees; `test_RegistryVerificationMatchesHolders` is a consistency assertion, not a
  guarantee.** It checks that the fixture's own premise holds (alice and bob verified, carol not) rather than
  asserting token behaviour, which is a different kind of claim from the other six. *Cost:* a NatSpec line in the
  file saying so, plus correcting AC-T1-4's "running" to "compiling". *Risk:* none to behaviour; a reader must still
  be told, or they will recount and land here again.
- **Option B — seven guarantees; the four "six" references are stale and get updated.** *Cost:* four one-line edits
  (T1 spec §107 and AC-T1-4, T0.5 task note, Decisions Log, T3.6). *Risk:* raises the T3.6 merge bar by one
  assertion — trivial here, since any implementation that passes the other six passes this one too.
- **Option C — leave it; the count is prose and the file is the source of truth.** *Cost:* none.
  *Risk:* T3.6 is written as a number, and the project's own precedence rule is **code → ADR → decision note →
  register**, which resolves it in favour of seven — but silently, which is exactly the drift the anti-drift
  contract exists to stop.

## Recommendation
**Option A — six**, because the seventh function is a different kind of statement from the other six. Guarantees 1–6
each say what the *token* must do; `test_RegistryVerificationMatchesHolders` says that the *test fixture* was set up
as described. Promoting it to a guarantee would mean the behavioural contract includes a clause about its own
scaffolding. Marking it in the file costs one line and makes the count self-evident to the next reader, which neither
B nor C does.

Whichever way it goes, **correct AC-T1-4's verb.** "Its six guarantees are unchanged" is right; "must be confirmed by
running T0.5 tests" is not achievable while the contract is abstract, and a criterion that cannot be met invites
either a false tick or a reopened gate later.

## Decision
**Option A — six guarantees.** `test_RegistryVerificationMatchesHolders` is a consistency assertion (it checks
the test fixture's own premise, not token behaviour) and is not counted as a guarantee. A NatSpec comment will be
added to the file marking it as such. AC-T1-4's verb is corrected from "running" to "compiling" (the contract is
abstract by design; execution happens at T3.6 when the concrete subclass is supplied).
*(Fahad Naseer, 2026-11-12)*

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[Thread - T1 Identity Layer]], [[T0 - Interface PR]], [[T3 - ERC-3643 Token]]
