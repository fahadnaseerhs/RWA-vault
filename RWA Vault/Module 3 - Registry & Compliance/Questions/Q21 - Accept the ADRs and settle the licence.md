---
type: decision
id: M3-Q21
module: M3
status: decided
raised_by: researcher
raised_on: 2026-10-27
blocks: [T7.3]
recommendation: "Accept all 26 (0002–0027); mark 0014 partly superseded by 0019 §6; pin CI runners for 0008; GPL-3.0 for contracts, README badge fixed"
decision: "Accept all 26 (0002–0027); 0014 partly superseded by 0019 §6; CI runners pinned; GPL-3.0"
decided_by: Fahad
decided_on: 2026-10-28
adr: none
tags: [rwa-vault, decision, adr, licence]
updated: 2026-10-28
---
# Q21 — Do we accept the ADRs you have already decided, and which licence does the repo carry?

**Why it matters (plain words):** every ADR after 0001 is still `Proposed`. M1 Stages 1–3 were built on 0002–0011 even
though `docs/adr/README.md` says Stage 1 waits for them to be Accepted, and you decided Q1–Q16 but their ADRs
(0012–0026) are Proposed too. ADR 0001 only makes a record immutable once Accepted, so today any agent may "amend in place"
— which is how ADR 0020 was changed. Separately, the README badge says **Proprietary** while every contract interface is
**GPL-3.0** and the Decisions Log calls GPL-3.0 locked; GPL code cannot sit inside a proprietary repo.

**Blocks:** T7.3 ("all ADRs written, reviewed, linked")

## Options
- **Option A — Accept 0002–0016 and 0018–0026 now; hold 0017 until Q17 and Q18 are decided** (they change it).
  Licence: GPL-3.0 for `contracts/`, README badge corrected.
- **Option B — Accept everything now** and supersede 0017 later if Q17/Q18 change it.
- **Option C — Leave all Proposed until the viva.** *Risk:* nothing is ever locked.

## Recommendation
**Updated 2026-10-28:** Q17 kept 0017 as written and Q18 went to its own ADR 0027, so nothing is held back any more —
**accept all 26 (0002–0027)**, GPL-3.0. Plain-words guide: [[2026-10-28 - ADRs awaiting acceptance]].

_Original:_ **Option A.** It locks what you have actually decided and built, and leaves open only the record that Q17/Q18 will change.

## Decision
> **Accept all 26; GPL-3.0 (Fahad, 2026-10-28).** ADRs 0002–0027 are `Accepted` (0014 marked partly superseded by
> 0019 §6). Per ADR 0008, CI runners are pinned to `ubuntu-24.04` / `windows-2022`. The repo licence is GPL-3.0: a `LICENSE`
> file was added and the README badge fixed. From now on, changing an ADR takes a new superseding ADR (ADR 0001).

Up: [[Open Questions for Fahad]] · Related: [[ADR Index]], [[2026-10-27 - Decision Conflict Audit|Audit A9, A17]]
