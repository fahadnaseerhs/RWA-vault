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

## Thread files are append-only in practice, not just in principle

Adopted 2026-10-28 after **three lost appends in two days**, whose single common factor was a whole-file
read-modify-write on a file another session was appending to.

1. **Append to a thread with a true shell append (`>>`). Never read-modify-write a thread.** A whole-file rewrite
   cannot be made safe by being careful: the read and the write are separate operations with a gap, and another
   session's append lands in that gap. `>>` has no gap. *This binds the Researcher — my own 23:05 re-append of the
   lost T0.7 handoff used a Python whole-file rewrite, which is the very practice that destroyed it.*
2. **Targeted string edits stay fine for Questions, ADRs and task notes**, where the point is to change existing
   text and the editor fails loudly when the surrounding text has moved.
3. **An append-only file cannot hold a living table.** The T0.7 thread's "Log of decisions" table sat at the end, so
   appending in time order pushed entries *after* it — and maintaining the table in place would require the rewrite
   rule 1 forbids. A table that gets revised belongs in the task note or the spec; a thread holds only entries.
4. **Never run a revert script across shared notes.** That, combined with a rewrite, is what destroyed Q13 and Q14.

Related: [[Agents - Workflow]], [[How to Explain Things to Me]]

## Assertions must name what broke, and must be able to fail

Adopted 2026-10-29, after three assertions that could never fail were found in two tasks.

1. **An assertion is decoration when no single edit to the production code can make it the only failing line.** It is
   *not* decoration merely because sibling assertions in the same test logically entail it while the test's own
   constants are held fixed — **the constants move with the edit.** A rename plus the literal update that rename
   invites can leave an "entailed" line as the only guard that fires.
2. **Reading a test establishes what it says; only mutation establishes what it catches.** Before approving an
   assertion, ask: *what single edit to the production code makes this line fail?* If there is no answer, it is
   decoration. Prove the answer on a scratch copy rather than by reading.
3. **Every `assertTrue` / `assertFalse` carries a message.** `assertEq` may rely on its printed values, which explain
   themselves. A bare `assertTrue` prints "assertion failed" and nothing else, so the next person identifies the line
   by elimination — under time pressure, on the one failure that means something specific.
4. These bind the Researcher first. The mutation standard was set after the first pair of dead assertions and then not
   applied to a test the Researcher praised by reading; rule 1's refinement came from the Coder applying rule 2 to a
   line the Researcher had specified.

Related: [[Agents - Workflow]]
