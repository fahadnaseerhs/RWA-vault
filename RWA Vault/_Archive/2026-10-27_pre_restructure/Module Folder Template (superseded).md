---
tags: [rwa-vault, template]
---
# Module Folder Template

The standard layout every module folder should follow, so the vault is consistent and anyone can find the same thing in the same place. [[Module 3 - Registry & Compliance]] is the reference implementation of this template.

## Folder shape
```
Module N - <Name>/
├── Module N - <Name>.md            ← hub note: what it is, status, links to everything below
├── Understanding/                   ← the "what & why", from intuition to technical detail
│   ├── 00 - What is Module N.md
│   ├── 01 - <core concept>.md
│   ├── ...
│   └── 0x - What's Been Built.md     ← current state vs. not-built
├── Decisions/
│   ├── Open Questions for Fahad.md   ← ⭐ open-ended decisions to unblock the build
│   └── Decisions Log.md              ← decisions actually made (mirrors docs/adr/)
├── Tasks/
│   └── M<N> Task Board and Todo.md   ← every task, checkboxes, agent-state markers
├── Research/                        ← one note per researched task: the Researcher→Coder handoff
│   └── T<n> - <Task name>.md         ← plan + acceptance criteria + risks (no implementation)
├── Algorithms/
│   ├── Mathematics - <...>.md        ← formal predicates, invariants, proofs-of-intent
│   └── Decision Algorithms - for Fahad.md  ← runnable decision trees / flows
└── Running/
    └── How to Run Module N.md        ← build / test / demo commands
```

## What each piece is for
| Piece | Answers | Audience |
| ----- | ------- | -------- |
| Hub note | "what is this module, where does it sit, what's its status?" | everyone |
| **Understanding** | "what & why, from intuition to detail" | anyone onboarding |
| **Decisions/Open Questions** | "what must we decide before coding?" | Fahad (decision owner) |
| **Decisions/Log** | "what did we decide and why?" | future us + examiners |
| **Tasks** | "what's left, and where is it in the [[Agents - Workflow|loop]]?" | the builders |
| **Research** | "for this task: what's the plan, and what exactly counts as done?" | Coder + Debugger |
| **Algorithms/Mathematics** | "the formal spec the tests assert" | Coder + Debugger |
| **Algorithms/Decision for Fahad** | "the step-by-step flows to follow / demo" | Fahad + operator |
| **Running** | "how do I build, test and demo it?" | anyone |

## Conventions
- Frontmatter: `tags`, `status`, `updated`. Hub note carries `phase` and `sprint`.
- Every note ends with `Prev/Next/Up` links and a `Related:` line.
- Status emoji: ⬜ not started · 🟠 skeleton · 🔵 in progress · 🟡 mostly done · ✅ done.
- Tasks carry agent-state markers 🧭/⌨️/🐞/✅ (see [[Agents - Workflow]]); only the Researcher checkmarks.
- Non-obvious decisions get an ADR in `docs/adr/`; the Decisions Log mirrors it.

## Applying to existing modules
- [[Module 1 - PQ Core]] predates this template and uses `Explainer/` + `Running/` + stage files — leave it as-is (it works); add `Decisions/`, `Tasks/`, `Algorithms/` only if you need them.
- [[Module 2 - PQ-PKI & Envelope]] is a single hub note with an inline task list — promote to this folder shape when M2 implementation starts.
- M0, M4–M11 live as single notes in `Modules/`; promote each to a full folder when its sprint begins. Don't pre-build empty folders for modules that haven't started.

Up: [[Project Memory]] · Related: [[Module 3 - Registry & Compliance]], [[Agents - Workflow]], [[All Modules]]
