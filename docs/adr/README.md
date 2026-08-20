# Architecture decision records

One Markdown file per named design decision, numbered sequentially, immutable once
accepted. The format and the rules that govern this log are themselves ADR 0001.

| #                                         | Title                                                                       | Status   | Module |
| ----------------------------------------- | --------------------------------------------------------------------------- | -------- | ------ |
| [0001](0001-record-format.md)             | Architecture decision record format                                         | Accepted | M0     |
| [0002](0002-pq-primitive-inventory.md)    | The PQ primitive inventory is six, and M1 owns all six                      | Proposed | M1     |
| [0003](0003-pq-implementation-sources.md) | PQ implementation sources: vendored PQClean C, plus one pure-Rust exception | Proposed | M1     |
| [0004](0004-wasm-build-target.md)         | Browser WASM target: `wasm32-unknown-unknown` with a freestanding C shim    | Proposed | M1     |
| [0005](0005-native-node-bridge.md)        | Native Node bridge: an N-API addon via napi-rs, plus a separate offline CLI | Proposed | M1     |
| [0006](0006-byte-encoding-contract.md)    | The M1 byte encoding contract                                               | Proposed | M1     |
| [0007](0007-random-source.md)             | Random source: OS CSPRNG natively, Web Crypto in WASM, fail closed          | Proposed | M1     |
| [0008](0008-target-platforms-and-ci.md)   | Supported platforms and the M1 CI matrix                                    | Proposed | M1     |
| [0009](0009-test-vector-inventory.md)     | Test-vector inventory and what "conformance" means per primitive            | Proposed | M1     |
| [0010](0010-benchmark-environments.md)    | Benchmark reference environments and measurement protocol                   | Proposed | M1     |
| [0011](0011-ethfalcon-verifier-pin.md)    | ETHFALCON: pin the commit, and use the NIST-compliant verifier              | Proposed | M1     |

ADRs 0002–0011 are the Stage 0 freeze set for Module 1 (PQ Core). Stage 1 does not
start until they are Accepted.

## Reading order for the M1 set

0002 first — it fixes the inventory every other record is scoped against. Then 0003,
which selects the implementations and is the record the rest depend on: 0004 exists
because 0003 chose C, 0006's size table comes from 0003's parameter sets, and 0009's
Falcon caveat comes from 0003's Round 3 pin. 0011 is readable on its own but its gas
argument assumes 0003's choice of a standards-conformant signer.
