---
tags: [rwa-vault, agents, workflow]
updated: 2026-10-09
---
# Agents — Workflow

How work actually gets done in RWA-Vault: a three-agent loop that turns a task on a board (like [[M3 Task Board and Todo]]) into a checkmarked, verified result. The three roles are **[[Researcher Agent|Researcher]]**, **[[Coder Agent|Coder]]**, and **[[Debugger Agent|Debugger]]**.

> "Agent" here is a **role in the workflow**, whether played by a teammate (Fahad/Hassan/Fawaz) or by an AI assistant acting in that role. The handoffs and the done-rule are the same either way.

## The loop
```
                ┌──────────────────────────────────────────────────┐
                │                                                    │
   TASK ──►  🧭 RESEARCHER ──plan + criteria──►  ⌨️ CODER ──build──► 🐞 DEBUGGER
   (board)     ▲   ▲                                                   │
               │   │                                                   │ tests fail /
               │   └──────────── "here's a problem, what's the ────────┘ unclear
               │                  intended behaviour?"
               │                        │
               │                 analyse answer
               │                        │
               │                        ▼
               │                   ⌨️ CODER (apply fix)
               │                        │
               └──── criteria met? ◄────┘
                  yes → ✅ CHECKMARK the task
                  no  → back to Researcher with the gap
```

## Who does what (one line each)
- **🧭 [[Researcher Agent|Researcher]]** — owns the *what* and the *why*. Takes a task off the board, researches it (interfaces, ADRs, the maths note, the standard), writes a **plan** and explicit **acceptance criteria**, hands to the Coder. Later, **verifies** against those criteria and is the **only** role that checkmarks a task.
- **⌨️ [[Coder Agent|Coder]]** — owns the *how*. Implements exactly the plan against the interfaces, writes the code and its tests, runs them, hands a working-or-failing build to the Debugger.
- **🐞 [[Debugger Agent|Debugger]]** — owns *closing the gap to green*. Diagnoses failures. When a failure is a **behaviour question** ("should an under-reserve re-attestation freeze or reject?"), it does **not** guess — it goes back to the Researcher, asks for the intended behaviour, **analyses** the answer, and routes the concrete fix back to the Coder.

## The three handoffs (what crosses each arrow)
1. **Researcher → Coder:** a plan (files to touch, interfaces to implement, approach) **+ acceptance criteria** (the exact tests/predicates that define "done"). From M3 these criteria come straight from [[Mathematics - Admission Predicate and Invariants]] and the acceptance spec.
2. **Coder → Debugger:** the implementation + test results (green, or red with the failing output).
3. **Debugger ↔ Researcher:** a *problem statement* ("behaviour X is ambiguous / the spec and the test disagree") → an *analysed solution* ("intended behaviour is Y because ADR Z"). The Debugger converts that into a concrete fix for the Coder.

## The done-rule (non-negotiable)
> A task is **checkmarked only when the Researcher confirms its acceptance criteria are met.** The Coder saying "it compiles" or "tests pass locally" is *not* done. Verification is the Researcher's job and no one else's.

This is why every task on the board carries an agent-state marker (🧭 / ⌨️ / 🐞 / ✅) — it shows exactly where in the loop the task is.

## Why this shape
- The Debugger **never invents behaviour** — ambiguity always routes back to the Researcher, so the spec stays the source of truth (matches the project rule "the acceptance test must be runnable by a third party").
- The Researcher **verifies**, so "done" means "meets the criteria," not "someone's tired of it."
- It mirrors the repo rules in [[All Modules]]: interface-first, acceptance test as the bar, ADRs for non-obvious calls.

## Mapping to the team
The roles rotate; suggested default for M3: **Fahad** carries the Researcher role on decisions (he owns [[Open Questions for Fahad]]), with Coder/Debugger shared across Hassan & Fawaz. Confirm per task on the board.

Up: [[Project Memory]] · Related: [[Researcher Agent]], [[Coder Agent]], [[Debugger Agent]], [[M3 Task Board and Todo]], [[Working Conventions]]
