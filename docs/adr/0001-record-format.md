# ADR 0001 — Architecture decision record format

- **Status:** Accepted
- **Date:** 2026-08-17
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

The proposal commits to an architecture decision record accompanying each design
decision, so that the thesis is assembled from artefacts rather than reconstructed at
the end. That only works if the records are written as decisions are made and share a
format that a reader — supervisor, examiner, or a developer joining mid-project — can
scan without re-reading the whole log.

We need a format that is cheap enough to write that it actually gets written, and
structured enough that §V and §VIII of the thesis can be assembled from it directly.

## Decision

Every non-obvious design decision gets one Markdown file in `docs/adr/`, numbered
sequentially: `NNNN-short-kebab-title.md`. Each record carries the headings below.

An ADR is **immutable once accepted**. A decision that is later reversed is not edited;
a new ADR is written that supersedes it, and the old record's status becomes
`Superseded by ADR NNNN`. The log is append-only for the same reason the anchor is:
a record that can be rewritten is not evidence.

### Required sections

| Section      | What it holds                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------- |
| Front matter | Status, date, deciders                                                                          |
| Context      | The forces in play — constraints, requirements, what made this a decision rather than a default |
| Decision     | What was chosen, stated in the active voice                                                     |
| Consequences | What follows, **including** what gets harder                                                    |
| Alternatives | What was rejected and the specific reason                                                       |

### Status values

`Proposed` → `Accepted` → `Superseded by ADR NNNN` (or `Rejected`)

## Consequences

**Good.** The thesis's design-rationale sections are assembled from artefacts written at
decision time, not reconstructed from memory months later. A new reader can reconstruct
why the system looks the way it does without interviewing the team.

**Costly.** Every non-obvious decision now carries a writing step before merge. We accept
this because the alternative — reconstructing rationale at week 24 — is both slower and
less honest, since by then the reasoning has been retrofitted to the outcome.

**Requires judgement.** "Non-obvious" is not a bright line. The working rule: if a
reviewer would reasonably ask "why this way?", it needs an ADR. Choosing a variable name
does not. Choosing Arbitrum over an L1 does.

## Alternatives considered

**Rationale in code comments only.** Rejected: comments explain what the code does now,
not what was rejected and why. The alternatives are the part that has thesis value, and
they leave no trace in the code that implements the winner.

**A single running decisions document.** Rejected: it produces merge conflicts on every
decision with three developers on one file, and it has no stable identifier to cite from
the thesis or from another decision.

**Wiki or issue tracker.** Rejected: the rationale should be versioned with the code it
explains, and should survive the project outliving any particular hosting account.

## Template

```markdown
# ADR NNNN — Title

- **Status:** Proposed
- **Date:** YYYY-MM-DD
- **Deciders:** …

## Context

What forces are in play? What makes this a decision rather than a default?

## Decision

What we chose, in the active voice.

## Consequences

What follows — including what this makes harder.

## Alternatives considered

What was rejected, and the specific reason.
```
