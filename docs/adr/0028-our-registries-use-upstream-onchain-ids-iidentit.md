# ADR 0028 — Upstream `onchain-id` is copy-vendored with provenance; its `IIdentity` is the one our registries use

- **Status:** Reserved
- **Date:** 2026-11-11
- **Deciders:** Fahad Naseer
- **Answers:** M3-Q23a (decided 2026-11-12, copy-vendor) — supersedes Q23's 2026-11-11 answer of Option A
- **Note on the filename:** the slug reads "use upstream's IIdentity", written when the answer was to import it from a
  submodule. Under Q23a we copy-vendor that source instead. The number was claimed by commit for the question, and
  AGENTS.md forbids renumbering, so the slug stays stale by design rather than being renamed.

## Status note

This number is **claimed, not written**. Under AGENTS.md an ADR number exists only once its file is
committed, and three renumbers were lost on 2026-10-27 to numbers promised in conversation. The decision itself is
recorded and binding in `RWA Vault/Module 3 - Registry & Compliance/Questions/` and in the Decisions Log; this file
reserves the number and will carry the full Context / Decision / Rationale / Consequences record.

The record owed here must state two things the decision turns on: that upstream's exact `pragma solidity 0.8.17` against
our `^0.8.20` files and `0.8.26` pin makes an import impossible, since Solidity compiles an import closure as one unit;
and that `solc_version` pinned in `[profile.default]` fixes the compiler project-wide, so a `0.8.17` file cannot build
in-tree even unimported — which is what ruled out keeping our own interface and casting, because the integration test
that would have replaced the lost compile-time check needs upstream's source compiled in-tree.
