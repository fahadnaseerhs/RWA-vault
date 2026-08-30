# Module 1 (PQ Core) — programmable task breakdown

Every code-producing task in M1, derived from the manual's §5 task list and §6 stage
sequence, constrained by the Stage 0 decisions in [ADR 0002–0011](adr/README.md).

**Scope note.** This lists tasks that produce a code or config artefact. Pure-process
items (ratifying the ADRs, the milestone dependency-status check, the two-approval
review rule) are prerequisites recorded in the manual and CONTRIBUTING.md, not rows
here. The three exceptions are S7-06, S7-07 and S6-09, which are process obligations
that CI executes and therefore have to be built.

**Reading the tables.** `Depends on` lists only hard blockers, not everything upstream.
`Done when` is the merge bar — if it is not demonstrable, the task is not finished.

Repository paths are relative to `packages/pq-core/` unless stated otherwise.

---

## Stage 0 — Decision follow-through

The ADRs are written; these are the code changes they oblige. All three are small and
all three block Stage 1, so they land first.

| ID    | Task                                                                                                                                                                                                                                      | Depends on | Done when                                                                                  |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------ |
| S0-01 | Split the algorithm union in `src/index.ts`: `PqSignatureAlgorithm` (4) + `PqKemAlgorithm` (2), `PqAlgorithm` as their union; add `ml-kem-768`, `ml-kem-1024`; split `PQ_ALGORITHMS` into `PQ_SIGNATURE_ALGORITHMS` / `PQ_KEM_ALGORITHMS` | —          | `pnpm typecheck` green; exhaustive `switch` over each union compiles with no `default` arm |
| S0-02 | Retarget `packages/envelope-codec/src/index.ts` — `PqEnvelope.algorithm` becomes `PqSignatureAlgorithm`, since an envelope is never signed by a KEM                                                                                       | S0-01      | Assigning `"ml-kem-768"` to `PqEnvelope.algorithm` is a type error                         |
| S0-03 | Set `evm_version` explicitly in `contracts/foundry.toml` (ADR 0008)                                                                                                                                                                       | —          | `forge build` succeeds; the value appears in `forge config` output                         |

---

## Stage 1 — Crate skeleton and the Falcon vertical slice

The purpose of this stage is not "Falcon works" — it is **S1-16**, proving a signature
crosses the native/WASM boundary. ADR 0004's freestanding C build is the project's
highest technical risk and this stage is the spike that settles it.

| ID    | Task                                                                                                                                        | Depends on   | Done when                                                                                          |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------- |
| S1-01 | `native/Cargo.toml` — crate metadata, `[lib] crate-type = ["cdylib","rlib"]`, deps (`getrandom`, `zeroize`, `slh-dsa`), `[features] kat`    | S0-01        | `cargo metadata` resolves; `cargo build` compiles an empty lib on Linux and Windows                |
| S1-02 | `scripts/vendor-pqclean.(sh\|ps1)` — fetch PQClean at the pinned commit, extract the 5 schemes + `common/`, copy `LICENSE` files            | —            | Script is idempotent; a second run produces a zero-byte `git diff`                                 |
| S1-03 | `vendor/pqclean/PROVENANCE.md` generator — upstream URL, commit SHA, per-file SHA-256 manifest                                              | S1-02        | A tampered vendored file fails `scripts/verify-vendor`                                             |
| S1-04 | `native/build.rs` — native compile path via `cc`, exactly the 6 vendored scheme dirs, no globbing                                           | S1-02        | `cargo build --release` links on `x86_64-unknown-linux-gnu` and `x86_64-pc-windows-msvc`           |
| S1-05 | `native/build.rs` — freestanding WASM C path and emitted audit manifest for its exact compiler/flags/includes/sources                       | S1-04        | Strict WASM build succeeds; auditing the emitted config finds zero headers outside reviewed roots  |
| S1-06 | `native/src/wasm_shim.rs` — aligned `std::alloc`-backed `malloc`/`free`; trapping `exit`; target builtins provide the four `mem*` functions | S1-05        | Every PQClean operation is retained; wasm32 links with no unresolved symbols; allocator tests pass |
| S1-07 | `native/src/error.rs` — `PqError` with ADR 0006's nine variants; no variant carries bytes or secret lengths                                 | S1-01        | Unit-variant assignments plus `size_of::<PqError>() == 1` compile; `Display` output is fixed       |
| S1-08 | `native/src/types.rs` — byte newtypes (`PublicKey`, `PrivateKey`, `Signature`, `Ciphertext`, `SharedSecret`) with `Zeroize` on secrets      | S1-01        | `PrivateKey` has no `Debug`/`Display`/`Serialize`; `Drop` zeroes the buffer (verified by test)     |
| S1-09 | `native/src/metadata.rs` — the ADR 0006 size table + `metadata(algorithm)`                                                                  | S1-08        | Wire/index order and selector identity hold at compile time; table matches ADR 0006                |
| S1-10 | Build-generated C `api.h` sizes + compile-time metadata equality assertions, followed by live implementation checks                         | S1-09, S1-11 | A one-byte table mismatch is a compile error; correctly sized live operations pass                 |
| S1-11 | Falcon-512 (`falcon-padded-512`) FFI + safe wrapper: keygen, sign, verify                                                                   | S1-04, S1-08 | Round-trips natively; signatures are exactly 666 bytes; a bit flip returns `false`, not an error   |
| S1-12 | `native/src/rng.rs` — `getrandom` wiring, native OS CSPRNG path, `RngFailure` on error, no retry loop                                       | S1-07        | Fault-injected RNG failure surfaces as `RngFailure` with no partial buffer written                 |
| S1-13 | RNG wiring for `wasm32` — Web Crypto backend enabled via the pinned crate's documented feature/cfg                                          | S1-12, S1-05 | Browser test draws 1,000 times: no error, no all-zero draw                                         |
| S1-14 | `native/src/wasm.rs` — `wasm-bindgen` boundary for the slice, `Uint8Array` in/out, no string conversion of key material                     | S1-11, S1-13 | `wasm-pack build --target web` emits `pkg/`; no key path crosses as a JS string                    |
| S1-15 | `init()` with fail-closed entropy probe (ADR 0007)                                                                                          | S1-13        | With `crypto.getRandomValues` stubbed absent, `init()` rejects and no API is exposed               |
| S1-16 | **Cross-runtime slice test** — native-signed Falcon verifies in WASM and WASM-signed verifies in native                                     | S1-11, S1-14 | Both directions pass. **This is the Stage 1 exit criterion**                                       |
| S1-17 | CI job `pq-native` (matrix Linux + Windows): fmt, clippy `-D warnings`, build, test                                                         | S1-04        | Both platforms green as required checks                                                            |
| S1-18 | CI job `pq-wasm`: `wasm-pack build`, headless Chromium runner, `tsc --build`                                                                | S1-14        | Job green; S1-16 runs inside it                                                                    |

> **Fallback trigger.** If S1-05/S1-06 cannot be made to link within the Stage 1
> timebox, switch to `wasm32-wasip1` + browser WASI shim per ADR 0004 and record it in
> the Stage 1 report. No new ADR required — the byte contract is unchanged.

---

## Stage 2 — Full algorithm matrix

Implementation evidence and the S2-06/S2-11 findings are recorded in
[`stage2-report.md`](stage2-report.md).

| ID    | Task                                                                                                                             | Depends on   | Done when                                                                                       |
| ----- | -------------------------------------------------------------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------- |
| S2-01 | ML-DSA-44 FFI + wrapper                                                                                                          | S1-11        | Keygen/sign/verify round-trip; sizes match S1-09                                                |
| S2-02 | ML-DSA-65 FFI + wrapper                                                                                                          | S1-11        | As above                                                                                        |
| S2-03 | ML-KEM-768 FFI + wrapper (keygen/encaps/decaps)                                                                                  | S1-11        | Encaps/decaps agree on the 32-byte shared secret                                                |
| S2-04 | ML-KEM-1024 FFI + wrapper                                                                                                        | S1-11        | As above                                                                                        |
| S2-05 | SLH-DSA-SHA2-128s via the `slh-dsa` crate (`Sha2_128s`), wrapped behind the same internal trait as the C schemes                 | S1-08        | Round-trips; caller cannot tell it is a different source                                        |
| S2-06 | Confirm the ML-DSA/SLH-DSA external (`ctx`-taking) interface with empty `ctx`; record which interface the implementation exposes | S2-01, S2-05 | Finding written into the Stage 2 report — this gates which ACVP vector set S4 selects           |
| S2-07 | `native/src/algorithms.rs` — dispatch over the 6 identifiers, wire codes per ADR 0006                                            | S2-01…S2-05  | Wire code `0x00` and any unknown code return `UnsupportedAlgorithm`                             |
| S2-08 | Exact-length validation on every key/signature/ciphertext input, before any FFI call                                             | S2-07, S1-09 | Every input one byte short and one byte long returns the right `Malformed*`; C is never entered |
| S2-09 | Algorithm/key-type mismatch rejection                                                                                            | S2-07        | ML-DSA-65 key + `ml-dsa-44` returns `AlgorithmKeyMismatch` before any FFI call                  |
| S2-10 | 1 MiB message cap                                                                                                                | S2-07        | Cap passes, cap+1 returns `MessageTooLong`                                                      |
| S2-11 | Secret-buffer hygiene sweep: zeroize temporaries, no secrets in `Debug`, no secrets in panic messages                            | S1-08        | `grep`-able audit note + test that a forced panic emits no key bytes                            |
| S2-12 | Signature API surface (`keygen`/`sign`/`verify`/`metadata`) over the 4 signature IDs                                             | S2-07        | Matches the manual §5.2 contract exactly                                                        |
| S2-13 | KEM API surface (`kem_keygen`/`encapsulate`/`decapsulate`/`kem_metadata`) over the 2 KEM IDs                                     | S2-07        | A KEM ID passed to `sign` is a compile error in TS and `UnsupportedAlgorithm` in Rust           |
| S2-14 | `kat` feature + `compile_error!` guard against optimised builds (ADR 0007)                                                       | S1-01        | `cargo build --release --features kat` fails to compile without the explicit override           |
| S2-15 | Seed-taking KAT entry points: `keygen_from_seed`, `sign_deterministic`, `encapsulate_with_m` — `cfg(feature = "kat")` only       | S2-14        | Symbols absent from a default release build (verified by symbol dump)                           |
| S2-16 | Per-algorithm unit tests (round-trip, wrong key, wrong message, empty inputs)                                                    | S2-01…S2-05  | All 6 primitives covered; no algorithm has fewer than the standard case set                     |
| S2-17 | Negative + malformed-input suite (ADR 0009 Source F)                                                                             | S2-08, S2-10 | Each case asserts a **specific** error class or `false`, never "did not succeed"                |

---

## Stage 3 — Runtime adapters

| ID    | Task                                                                                        | Depends on   | Done when                                                                              |
| ----- | ------------------------------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------- |
| S3-01 | `native/napi/` addon crate — `#[napi]` wrappers, stateless, Node-API v8                     | S2-12, S2-13 | `require()` loads on Node 22.16.0; no global mutable state in the crate                |
| S3-02 | Async variants via `AsyncTask` for every operation; async is the default export             | S3-01        | SLH-DSA signing does not block the event loop (measured in test)                       |
| S3-03 | `PqError` → JS `Error` mapping with stable `code` strings                                   | S3-01, S1-07 | Every variant has a distinct `code`; no error message contains byte data               |
| S3-04 | **Exclude SLH-DSA signing from the addon** — verification only (ADR 0005)                   | S3-01        | Symbol dump of the built addon contains no SLH-DSA signing entry point                 |
| S3-05 | napi-rs prebuild CI for `x86_64-unknown-linux-gnu` + `x86_64-pc-windows-msvc`               | S3-01        | Both prebuilts published as artefacts; a Rust-free checkout can run the services       |
| S3-06 | `src/types.ts` — byte-oriented types, metadata types, the two algorithm unions              | S0-01        | No `any`; declaration output checked in                                                |
| S3-07 | `src/errors.ts` — TS error classes mirroring S3-03's codes                                  | S3-03        | Code strings identical across Rust, addon and TS (asserted by a shared fixture)        |
| S3-08 | `src/native.ts` — typed adapter over the addon                                              | S3-01, S3-06 | Implements the shared contract interface                                               |
| S3-09 | `src/wasm.ts` — typed adapter + loader over `pkg/`                                          | S1-14, S3-06 | Implements the _same_ interface as S3-08                                               |
| S3-10 | Contract-equivalence test — one test suite executed against both adapters                   | S3-08, S3-09 | Identical assertions pass for native and WASM                                          |
| S3-11 | `src/index.ts` — public exports, `init()`, metadata, errors; no liboqs/PQClean detail leaks | S3-08, S3-09 | Nothing implementation-specific is exported (reviewed against DoD's last item)         |
| S3-12 | `pqctl` CLI crate — offline root ceremony: SLH-DSA keygen, sign, verify over files          | S2-05        | Runs air-gapped; never linked into any service binary                                  |
| S3-13 | Replace the `"no tests yet"` placeholder in `package.json` with a real test script          | S3-10        | `pnpm test` runs the suite and fails on a broken build                                 |
| S3-14 | Package exports map, generated `.d.ts` check, ESLint over new TS                            | S3-11        | `pnpm lint` + `pnpm build` green; `dist/` declarations resolve from a consumer package |
| S3-15 | Wire `build:wasm` / `build:native` / `test:cavp` scripts to real, CI-backed commands        | S3-13        | Each declared script in `package.json` executes successfully                           |

---

## Stage 4 — Conformance

| ID    | Task                                                                                                                                           | Depends on   | Done when                                                                           |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------- |
| S4-01 | `vectors/manifest.json` + `scripts/fetch-vectors` — pinned tags, per-file SHA-256, checksum-verified fetch                                     | —            | A modified upstream file fails the fetch; no vector bytes committed                 |
| S4-02 | ACVP parser: ML-DSA `keyGen` / `sigGen` / `sigVer` (FIPS 204)                                                                                  | S4-01, S2-15 | Only the `-44`/`-65` groups extracted; skipped-group count reported                 |
| S4-03 | ACVP parser: ML-KEM `keyGen` / `encapDecap` (FIPS 203)                                                                                         | S4-01, S2-15 | `-768`/`-1024` groups pass                                                          |
| S4-04 | ACVP parser: SLH-DSA `keyGen` / `sigGen` / `sigVer` (FIPS 205)                                                                                 | S4-01, S2-15 | `SHA2-128s` groups pass                                                             |
| S4-05 | NIST AES-CTR-DRBG — **test tree only**, never in the library crate                                                                             | —            | Reproduces a known DRBG output sequence; absent from `cargo tree` for the lib       |
| S4-06 | Falcon Round 3 KAT parser (`.req`/`.rsp`)                                                                                                      | S4-01, S4-05 | Parses the official KAT file without hand-editing it                                |
| S4-07 | Attached (`sm`) → detached 666-byte signature adapter, separately tested                                                                       | S4-06        | Adapter has its own unit tests independent of the KAT runner                        |
| S4-08 | PQClean upstream-KAT runner (ADR 0009 Source C)                                                                                                | S4-01        | Reported as build-correctness evidence, labelled distinctly from standards evidence |
| S4-09 | Differential-oracle tests against `pqcrypto-falcon` / `-mldsa` / `-mlkem` dev-deps                                                             | S2-15        | Byte-identical on keygen-from-seed, sign and verify for all 5 C-sourced primitives  |
| S4-10 | Golden-vector generator → `vectors/project/v1/` (seed, keypair, message, signature/ciphertext, hex JSON)                                       | S2-15        | Regenerating produces byte-identical output; `v1` frozen on merge                   |
| S4-11 | Golden-vector consumer: Rust tests                                                                                                             | S4-10        | Passes                                                                              |
| S4-12 | Golden-vector consumer: TypeScript tests                                                                                                       | S4-10, S3-08 | Passes                                                                              |
| S4-13 | Golden-vector consumer: browser/WASM tests                                                                                                     | S4-10, S3-09 | Passes                                                                              |
| S4-14 | Golden-vector consumer: Foundry tests (Falcon only)                                                                                            | S4-10        | Passes; same fixture file as S4-11..13                                              |
| S4-15 | Bidirectional cross-runtime suite over all 6 primitives × Sources A/B/E                                                                        | S1-16, S2-07 | Every primitive passes native→WASM and WASM→native                                  |
| S4-16 | Report emitter — machine-readable JSON + human Markdown: source, pinned version, vendored commit, algorithm, operation, target, pass/fail/skip | S4-02…S4-09  | Report carries ADR 0009's per-primitive evidence-grade table verbatim               |
| S4-17 | Zero-case guard                                                                                                                                | S4-16        | A primitive with zero executed cases fails the run                                  |
| S4-18 | CI job `pq-conformance` — release + `kat`, **reports only, never binaries**                                                                    | S4-16        | Job cannot publish an artefact (enforced, not documented)                           |

---

## Stage 5 — Benchmarks

| ID    | Task                                                                                                            | Depends on   | Done when                                                                             |
| ----- | --------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------- |
| S5-01 | `benches/pq_bench.rs` — criterion harness, ADR 0010 warm-up/iteration counts per operation class                | S3-15        | Fast ops 100/1,000; SLH-DSA + Falcon keygen 5/50                                      |
| S5-02 | Browser benchmark harness using `performance.now()`                                                             | S3-09        | Same operation set and payload as S5-01                                               |
| S5-03 | Native spec scanner — CPU model, cores, RAM, OS build, target triple, `rustc`, feature set                      | —            | Correct on Linux (`/proc`) and Windows (WMI)                                          |
| S5-04 | Browser spec scanner — UA-CH high-entropy hints, `hardwareConcurrency`, `deviceMemory`, screen, DPR             | —            | Returns the handset `model` on Chrome for Android over HTTPS                          |
| S5-05 | Hard error on missing `model` for a mobile user agent (non-secure-context guard)                                | S5-04        | Plain-HTTP LAN run fails loudly instead of recording an unknown                       |
| S5-06 | Fingerprint function — SHA-256 over non-volatile fields only                                                    | S5-03, S5-04 | A browser patch bump does not change the fingerprint; a CPU swap does                 |
| S5-07 | `environments.json` registration-on-first-run                                                                   | S5-06        | First run in an empty slot writes spec + fingerprint + commit + date                  |
| S5-08 | Drift detection — mismatch writes `"environment": "unregistered"`, `"comparable": false`, prints spec diff      | S5-07        | Mismatch neither fails the run nor overwrites the registration                        |
| S5-09 | A1 profile warning at registration (`deviceMemory` > 8, flagship-looking core count)                            | S5-07        | Warns without refusing                                                                |
| S5-10 | Benchmark report emitter — median, p95, min, max, **iteration count beside every statistic**                    | S5-01, S5-02 | Portable-C lower-bound caveat printed in every report                                 |
| S5-11 | WASM package size (raw + gzipped), instantiation time, peak JS heap during a signing loop                       | S5-02        | All three in the report; satisfies §5.3 memory behaviour + §5.6 artefact size         |
| S5-12 | Threshold checks: Falcon sign p95 < 500 ms on A1; gzipped package < 2 MB; >25% D1 regression fails release gate | S5-10, S5-11 | Breach produces a labelled finding, not a silent pass; discarded runs record a reason |

---

## Stage 6 — ETHFALCON dispute verifier

| ID    | Task                                                                                                                           | Depends on   | Done when                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------------------------------ | ------------ | -------------------------------------------------------------------------------------- |
| S6-01 | Vendor ETHFALCON at `7d5ecd41ce1e0346afc835d20a9014e5a076843e` into `contracts/lib/ethfalcon/` + PROVENANCE + MIT licence text | S0-03        | `forge build` compiles it; checksums verified by `scripts/verify-vendor`               |
| S6-02 | `falcon_to_evm(pk, sig) -> (salt, s2_coefficients, pk_ntt)` adapter in Rust, 16 coefficients per word, NTT-domain key          | S1-11, S6-01 | Pure function with its own unit tests; field layout transcribed into the doc comment   |
| S6-03 | TS/script path to produce verifier calldata from a golden vector                                                               | S6-02, S3-08 | Produces calldata `ZKNOX_falcon` accepts                                               |
| S6-04 | Foundry positive tests using ADR 0009 Sources B + E                                                                            | S6-02, S4-14 | Every KAT and golden vector verifies on-chain                                          |
| S6-05 | Negative tests — bit-flipped signature, bit-flipped message, wrong public key                                                  | S6-04        | Each asserts the specific revert or `false`                                            |
| S6-06 | Malformed + boundary tests — wrong-length inputs, out-of-range coefficients                                                    | S6-04        | No case reverts with a generic panic                                                   |
| S6-07 | Gas measurement: deployment gas and per-verification gas, reported separately                                                  | S6-04        | Numbers reproducible under the pinned solc/optimizer/EVM settings                      |
| S6-08 | `forge snapshot` gas regression check with an explicit threshold, wired into the `contracts` job                               | S6-07        | A gas increase past the threshold fails CI                                             |
| S6-09 | Verify the pinned `evm_version` deploys and executes on Arbitrum Sepolia; drop to `shanghai` and record if not                 | S0-03, S6-07 | Result recorded in the RQ3 report before publication                                   |
| S6-10 | RQ3 report — gas figures, the dispute-only policy conclusion, and the δ-sensitivity restated from ADR 0011                     | S6-07, S6-09 | Report states measurement chain, pinned settings, and the upstream "unaudited" warning |

---

## Stage 7 — Release gate

| ID    | Task                                                                                                                       | Depends on                 | Done when                                                                     |
| ----- | -------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ----------------------------------------------------------------------------- |
| S7-01 | `deny.toml` + `cargo deny` in CI (licences + advisories)                                                                   | S1-17                      | Fails on a disallowed licence or a known advisory                             |
| S7-02 | SBOM generation — CycloneDX via `cargo cyclonedx` and `pnpm licenses`                                                      | S3-14                      | SBOM covers vendored C, Rust deps and npm deps                                |
| S7-03 | `metadata.json` + `SHA256SUMS` emitter with every field ADR 0008 lists                                                     | S3-05, S1-14               | Metadata present on every published artefact                                  |
| S7-04 | CI job `pq-artifacts` (tags only) — builds without `kat`, publishes addon prebuilts, WASM package, `pqctl`                 | S7-03                      | Runs only on tags                                                             |
| S7-05 | `kat`-absence assertion in the release job                                                                                 | S7-04, S2-14               | **Hard failure**, not a warning, if `kat` appears in the resolved feature set |
| S7-06 | Weekly scheduled `cargo deny` / `pnpm audit` workflow                                                                      | S7-01                      | Runs on schedule and on every PR                                              |
| S7-07 | Path filters on the four M1 CI jobs                                                                                        | S1-17, S1-18, S4-18, S7-04 | M1 jobs skip on PRs touching neither `packages/pq-core/**` nor `contracts/**` |
| S7-08 | `packages/pq-core/README.md` — build, test, release, supported platforms, security boundaries, dependency-update procedure | S7-04                      | Covers all six items the manual §9 requires                                   |
| S7-09 | Tag the library and generated artefacts together with one source commit                                                    | S7-04, S4-18, S5-12, S6-10 | Tag carries conformance, benchmark and gas reports plus checksummed artefacts |

---

## Totals and shape

| Stage     | Tasks   | Character                                           |
| --------- | ------- | --------------------------------------------------- |
| S0        | 3       | Small, unblocks everything                          |
| S1        | 18      | Highest risk; S1-05/06/16 are the spike             |
| S2        | 17      | Mostly repetition of a proven pattern once S1 lands |
| S3        | 15      | Two adapters + the bridge; parallelisable           |
| S4        | 18      | Largest stage; parser-heavy, low conceptual risk    |
| S5        | 12      | Independent of S4, can run in parallel              |
| S6        | 10      | Only stage touching Solidity                        |
| S7        | 9       | Packaging and gates                                 |
| **Total** | **102** |                                                     |

### Critical path

`S0-01 → S1-01 → S1-02 → S1-04 → S1-05 → S1-06 → S1-11 → S1-14 → S1-16`

Nine tasks. Everything else in M1 is downstream of S1-16 or parallel to it. If the
freestanding WASM link fails, the fallback fires here and nowhere else.

### Suggested parallel lanes after S1-16

Three lanes that touch mostly disjoint files, so three developers do not contend on
one surface:

- **Lane A — core:** S2-01…S2-17, then S4-02…S4-09 (the Rust and vector work)
- **Lane B — adapters:** S3-01…S3-15, then S5-01…S5-12 (the bridge, TS, benchmarks)
- **Lane C — chain:** S0-03, S6-01…S6-10, then S7-01…S7-09 (Solidity, packaging, CI)

Lane C is the lightest and its owner should also take S4-16…S4-18, the report
emitters, which depend on Lane A's output but not on its internals.

### Definition-of-Done coverage

Every M1 DoD item maps to at least one task above, with the two amendments the ADRs
made: the algorithm count is six (ADR 0002, S2-03/S2-04/S2-13), and the CAVP claim is
replaced by ADR 0009's per-primitive evidence grades (S4-16). No DoD item is
unaddressed.
