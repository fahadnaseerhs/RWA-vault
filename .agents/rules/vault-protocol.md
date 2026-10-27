# Vault Protocol & Agent Guidelines

See [AGENTS.md](file:///c:/Users/USER/OneDrive/Desktop/RWA%20vault/AGENTS.md) at repository root for the full authoritative Master Protocol.

### Core Working Rules
1. **Never Invent Behavior:** When a test or boundary condition fails or is ambiguous, the Debugger must post an `ASK` in the module task thread.
2. **Quote on-disk code:** Always state on-disk line numbers and snippets in handoffs, never describe intentions.
3. **No Status Prose in Readmes:** Frontmatter in individual Question and Task files is the sole source of truth for status.
4. **ADR Claiming:** Must commit `docs/adr/00XX-<slug>.md` with `Status: Reserved` before referencing the number.
5. **No Long Changelog Essays:** Keep `Changelog.md` strictly to one line per major milestone, linking to task threads.
