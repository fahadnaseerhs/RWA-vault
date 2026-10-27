# Vault Protocol & Agent Guidelines

See `AGENTS.md` at the repository root for the Master Protocol, and `RWA Vault/_Templates/00 Vault Standard.md` for the locked note shapes and templates.

### Core Working Rules

1. **Never Invent Behavior:** When a test or boundary condition fails or is ambiguous, the Debugger must post an `ASK` in the module task thread.
2. **Quote on-disk code:** Always state on-disk line numbers and snippets in handoffs, never describe intentions.
3. **No Status Prose in Readmes:** Frontmatter in individual Question and Task files is the sole source of truth for status.
4. **ADR Claiming:** Must commit `docs/adr/00XX-<slug>.md` with `Status: Reserved` before referencing the number.
5. **No Long Changelog Essays:** Keep `Changelog.md` strictly to one line per major milestone, linking to task threads.
