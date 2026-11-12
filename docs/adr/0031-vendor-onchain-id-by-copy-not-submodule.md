# ADR 0031 — `onchain-id` is vendored by copy with a provenance script, not as a submodule

- **Status:** Reserved
- **Date:** 2026-11-12
- **Deciders:** Fahad Naseer
- **Answers:** M3-Q26 (Q23a, decided 2026-11-12, Option D)
- **Supersedes:** the vendoring *mechanism* in ADR 0012. 0012's hybrid decision — vendor the ERC-734/735 identity
  plumbing, build the token, registries, compliance and AssetRegistry ourselves — **stands unchanged**; only its
  "as a Foundry submodule" wording is superseded.

## Status note

This number is **claimed, not written**. Under AGENTS.md a number is reserved only once its file is **committed** —
and a stub left untracked is not a claim, which is how the 0028–0030 claims briefly failed. The decision is recorded
and binding in `RWA Vault/Module 3 - Registry & Compliance/Questions/Q26 - How do we vendor onchain-id given the
pragma conflict.md` and in the Decisions Log; this file reserves the number and will carry the full record.

## Why a superseding record rather than an amendment

ADR 0012 is **Accepted**, and ADR 0001 makes an accepted record immutable. The submodule wording cannot be edited in
place, and the substance of 0012 is not in dispute, so this supersedes its mechanism only.

## The reason in one line

Upstream pins `pragma solidity 0.8.17` exactly; our pin is `0.8.26`; Solidity compiles a file together with its whole
import closure under one compiler. A submodule therefore could not satisfy both pragmas across the import edge from
our registries to upstream's `IIdentity`, so the mechanism 0012 named was unbuildable rather than merely costly.
