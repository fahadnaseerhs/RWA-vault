# Stage 2 implementation report

Stage 2 implements the full six-primitive matrix in `packages/pq-core/native`:
four signature schemes and two KEM parameter sets. The public Rust surface is
split into signature and KEM operations, and the TypeScript contract uses the
same split.

Stage 1 proved one algorithm crosses the native/WASM boundary. Stage 2 carries
almost no new conceptual risk — it is the same proven pattern applied five more
times — so its danger is repetition without attention: a wrong length constant,
a missing mismatch check, or a negative test that accepts any failure. The
evidence below is written against that risk, and each claim names the artefact
or command that establishes it.

## Task results

| Tasks       | Result                                                                                                                                                                                                                                                                                                   |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S2-01–S2-05 | ML-DSA-44, ML-DSA-65, ML-KEM-768, ML-KEM-1024 and SLH-DSA-SHA2-128s are implemented behind the same internal signature/KEM traits. Exact output sizes are asserted against the Stage 1 metadata table, which is itself asserted against the generated `api.h` constants at compile time.                 |
| S2-06       | Interface finding recorded below.                                                                                                                                                                                                                                                                        |
| S2-07–S2-10 | Six-code dispatch, exact pre-implementation length guards on **all six** primitives, tagged-key mismatch rejection, and the exact 1 MiB message cap on all four signature schemes are implemented and tested.                                                                                            |
| S2-11       | Secret-buffer audit recorded below. Secret wrappers implement neither `Debug` nor `Clone`, which is enforced by `compile_fail` doctests, not only by review. Fixed panic/error text cannot contain key bytes.                                                                                            |
| S2-12–S2-13 | Rust and TypeScript expose separate signature and KEM API shapes. Rust rejects a wrong operation family with `UnsupportedAlgorithm`; TypeScript has a build-time assertion that a KEM selector cannot satisfy `sign`.                                                                                    |
| S2-14–S2-15 | The `kat` feature is refused by an optimised build. The seed/randomizer/message hooks exist only under that feature, proved two ways: `scripts/verify-no-kat-symbols.py` over the built artefacts, and `compile_fail` doctests showing the three names do not resolve for a consumer of a default build. |
| S2-16–S2-17 | All six primitives carry the standard positive/negative case set. The ADR 0009 Source F suite is `native/tests/negative_inputs.rs`. Every malformed case asserts an exact `PqError` variant or an exact `false`; no assertion in the crate is a bare `is_err()`.                                         |

## S2-06 interface finding

- ML-DSA-44 and ML-DSA-65 call PQClean's
  `crypto_sign_signature_ctx` / `crypto_sign_verify_ctx` external interface with
  `ctx = NULL, ctxlen = 0`. They do not use the prehash interface. This is the
  same call PQClean's own non-`_ctx` wrappers make (`sign.c:383`, `sign.c:399`),
  so the null pointer at zero length is upstream's own convention rather than
  ours. Stage 4 must select the FIPS 204 external-interface, empty-context ACVP
  groups.
- SLH-DSA-SHA2-128s calls `try_sign_with_context` and
  `try_verify_with_context` through the pinned `slh-dsa` crate's `Signer` and
  `Verifier` implementations. Both fix `ctx` to empty and therefore implement
  the FIPS 205 external interface. They do not use the prehash interface. Stage
  4 must select the FIPS 205 external-interface, empty-context ACVP groups.
- Falcon-padded-512 is the Round 3 detached-signature interface and has no FIPS
  context parameter. Its evidence remains the Round 3 KAT set from ADR 0009.

## S2-11 secret-buffer audit

The following Rust-owned values touch secret material:

| Location                       | Secret-bearing temporary                 | Disposal                                                                                                                                                                                 |
| ------------------------------ | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Falcon keygen                  | private-key output `Vec<u8>`             | Moved directly into `PrivateKey`; zeroized on failure and on wrapper drop.                                                                                                               |
| ML-DSA keygen                  | private-key output `Vec<u8>`             | Moved directly into `PrivateKey`; zeroized on failure and on wrapper drop.                                                                                                               |
| ML-KEM keygen                  | decapsulation-key output `Vec<u8>`       | Moved directly into `PrivateKey`; zeroized on failure and on wrapper drop.                                                                                                               |
| ML-KEM encapsulate/decapsulate | shared-secret output `Vec<u8>`           | Moved directly into `SharedSecret`; zeroized on failure and on wrapper drop.                                                                                                             |
| SLH-DSA keygen                 | `sk_seed`, `sk_prf`, `pk_seed`           | Explicitly zeroized immediately after key construction.                                                                                                                                  |
| SLH-DSA keygen/sign            | dependency `SigningKey<Sha2_128s>` value | Held by the internal `SecretSigningKey` guard and overwritten before scope exit; the pinned dependency does not itself implement `Zeroize`.                                              |
| SLH-DSA keygen and KAT keygen  | `SigningKey::to_bytes()` result array    | The pinned crate returns the serialized private key in a fresh `hybrid_array::Array` it never wipes. `slhdsa::encode_signing_key` copies it out and zeroizes that array before it drops. |
| KAT-only deterministic C calls | scoped entropy copy                      | Available only with `feature = "kat"`; zeroized when the scope ends.                                                                                                                     |

`PrivateKey`, `SharedSecret`, `KeyPair`, `KemKeyPair` and the Falcon key-pair
compatibility type intentionally have no `Debug` or `Clone` implementation.
`PqError` variants carry no data and render fixed static messages. Tests observe
private-key/shared-secret zeroization and force a panic while a private key is
live, then assert that the panic payload contains no marker bytes.

**Correction against the first draft of this report.** The `to_bytes()` row
above was previously recorded as "moved directly into `PrivateKey`". That was
wrong: `to_bytes()` materialises the private key in an intermediate array, and
the copy into the `Vec` left that array live until it dropped unwiped. The
`encode_signing_key` helper now makes the recorded disposal true.

## S2-15 evidence, and what a symbol scan can and cannot show

`scripts/verify-no-kat-symbols.py` reads built artefacts and fails if any of
`keygen_from_seed`, `sign_deterministic`, `encapsulate_with_m` or
`with_kat_entropy` appears in compiled output. Three findings shaped it:

1. **The linked cdylib is a weak witness on its own.** Scanning
   `rwa_vault_pq_core.dll` from a build with `--features kat` reports _clean_ —
   the hooks are ordinary Rust functions, not exported symbols, so the linker
   strips them from the shared library even when they were compiled. A scan
   restricted to the DLL would pass on exactly the build it is meant to catch.
   The `.rlib` is the artefact with the evidence: its object members and archive
   symbol index carry the mangled names.
2. **`lib.rmeta` names the hooks even in a default build, and this is benign.**
   rustc interns identifiers in the parser, before `#[cfg]` stripping removes the
   items, so the crate metadata lists the three names next to `fail_next_draw` (a
   `#[cfg(test)]` function) and the string `wasm32` (a cfg value) — names with no
   item, no MIR and no code. The scan excludes `lib.rmeta` and **prints each
   exclusion it applied**, because a check that silently skips the one place a
   hit occurs is not evidence.
3. **A scanner that matches nothing passes any scan.** `--self-test` runs the
   matcher over a buffer containing all four names, in both plain and mangled
   form, and fails if it does not find them. CI runs the self-test immediately
   before the scan.

The scan was confirmed to discriminate: run against a real
`cargo build --features kat` tree it fails, naming the object members and the
archive symbol index that carry each hook.

The source-level half of the proof is in `native/src/lib.rs`: three
`compile_fail` doctests naming the hooks, preceded by a passing doctest that
resolves `keygen` and `encapsulate` so a mistyped crate path cannot make the
three pass vacuously.

## Verification record

Every command below was run on this workstation at the pinned toolchain
(Rust 1.81.0, clang 22.1.8, Python 3.12.10).

| Check                                                                 | Result                                                                     |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `cargo fmt --check`                                                   | clean                                                                      |
| `cargo clippy --all-targets -- -D warnings`                           | clean                                                                      |
| `cargo clippy --features kat --all-targets -- -D warnings`            | clean                                                                      |
| `cargo clippy --target wasm32-unknown-unknown -- -D warnings`         | clean                                                                      |
| `cargo test` (debug)                                                  | 56 passed — 34 unit, 2 differential, 13 negative-input, 1 live-size, 6 doc |
| `cargo test --release`                                                | 56 passed                                                                  |
| `cargo test --features kat`                                           | 54 passed, including the 2 deterministic-hook tests                        |
| `cargo build --release --features kat`                                | fails at the intended `compile_error!` guard                               |
| `verify-no-kat-symbols.py --self-test`                                | matcher detects all four names, plain and mangled                          |
| `verify-no-kat-symbols.py target/release`                             | rlib, `.so` and `.dll` clean; the one `lib.rmeta` exclusion is printed     |
| `verify-no-kat-symbols.py` against a `--features kat` build           | fails as intended, naming each object member that carries a hook           |
| `cargo build --release --target wasm32-unknown-unknown` (strict link) | links with no unresolved symbols                                           |
| `verify-wasm-preprocessor.py`                                         | groups=6, files=44, host_header_hits=0, ndebug_assert=trap                 |
| `verify-wasm-imports.py`                                              | forbidden=0, native_diagnostics=0                                          |
| `verify-no-kat-symbols.py` over the release `.wasm`                   | clean                                                                      |
| `pnpm --filter @rwa-vault/pq-core typecheck` and `lint`               | pass, including the S2-13 compile-time selector assertion                  |

The WASM caveat in the first draft of this report is withdrawn: the Clang WASM
backend is now installed locally, and the strict WASM build and both C-audit
scripts were run here rather than deferred to CI. CI remains the authoritative
gate, and the browser suite (headless Chromium) still runs only there.

## Known limits of the Stage 2 evidence

Recorded so Stage 3 and Stage 4 do not mistake these for settled:

- **"C is never entered" is vacuous for SLH-DSA.** It is a pure-Rust scheme, so
  the FFI call counter cannot fail for it. Its inclusion in the exact-length
  sweep proves the API-surface rule, not a property of the backing code.
- **The 1 MiB cap is proved inclusive by a real operation for Falcon, ML-DSA-44
  and ML-DSA-65 only.** SLH-DSA-SHA2-128s signing is orders of magnitude slower,
  so its inclusive boundary is proved on the verification path — a 1 MiB message
  reaches the primitive and is answered `false` rather than rejected as
  over-length. The over-cap rejection is proved for all four.
- **Algorithm/key mismatch is detected from the wrapper's tag.** A caller who
  rebuilds a key through `PublicKey::new` discards the tag, and such a key is
  then caught by length alone. No two primitives in ADR 0006's table share a
  public-key, private-key, signature or ciphertext length, so length is currently
  sufficient — but that is a property of the current table, not an invariant, and
  a seventh primitive could break it.
- **Correctness evidence is still Stage 4's.** Everything here shows the matrix
  round-trips and rejects correctly against itself. Standards conformance comes
  from the ACVP and KAT work in Stage 4; the differential oracle is the only
  independent implementation checked against so far.
