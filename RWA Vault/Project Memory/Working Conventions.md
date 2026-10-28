---
tags: [rwa-vault, process]
---
# Working Conventions

## Explanations
- Every explanation follows [[How to Explain Things to Me]]: the real-world scene first, then what it will be in practice, then why it must exist, **then** the mechanics, **then** the decisions. Never open at the architecture layer.

## Handoffs
- **A handoff states the ON-DISK state, not the intent.** Quote the line as it now reads, rather than describing the
  change you made, and verify it against the file before sending. Adopted 2026-10-27 after a fix was twice reported as
  done while the code still held the old value — both times the handoff described what was *done*, and both times
  another session had to find the gap. This binds the Researcher as much as the Coder.

## This vault
- Notes here are **project memory**: facts that are not obvious from the code or git history.
- Code-level detail stays in the repo (`docs/`, ADRs, READMEs). Notes here **link** to it rather than copying it.
- When a stage or module finishes, update its status and add a line to [[Changelog]].
- Claude reads and updates these notes when asked to remember something about the project.

## Repo
- Commit style: conventional commits (`feat(pq-core): …`, `fix(ci): …`, `docs: …`).
- Two approvals per PR.
- Docs are formatted with Prettier (CI checks it).
