---
type: concept
module: M1
tags: [rwa-vault, m1, algorithms, index]
updated: 2026-11-22
---
# 🔢 Byte Contract and Sizes — where the maths lives

> Index only. The size table and the encoding rules are owned by ADR 0006 and the code. This note links to them.

- **Encoding contract:** ADR `0006` — the M1 byte encoding contract ([[ADR Index]]).
- **Size table in code:** `packages/pq-core/native/src/metadata.rs` (asserted against the C `api.h` at compile time, [[Tasks/T1 - Crate skeleton and Falcon slice|T1 · S1-10]]).
- **Conformance evidence grade:** ADR `0009` ([[Tasks/T4 - Conformance|T4]]).
- **Benchmark protocol:** ADR `0010` ([[Tasks/T5 - Benchmarks|T5]]).

Up: [[Module 1 - PQ Core]]
