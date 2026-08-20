//! RWA-Vault post-quantum cryptographic core.
//!
//! Stage 1 establishes the crate, its vendored native build, and the single
//! entropy path that build depends on. Safe algorithm wrappers are added in the
//! subsequent vertical-slice tasks; [`ffi`] is the raw surface they will wrap.

#![deny(unsafe_op_in_unsafe_fn)]

// ADR 0007: the deterministic seed-taking KAT hooks must not exist in an optimised
// build, so that no release artefact can contain a reachable non-OS entropy path.
//
// The conformance suite still needs optimised code (§8.3 forbids comparing debug
// numbers against release acceptance thresholds). It gets it from a dedicated CI
// job that acknowledges this guard explicitly:
//
//     RUSTFLAGS="-C debug-assertions=on" cargo test --release --features kat
//
// That job publishes a test report only. The release-artefact job builds without
// `kat`, and it is the only job whose binaries are checksummed and shipped
// (ADR 0008).
#[cfg(all(feature = "kat", not(debug_assertions)))]
compile_error!("the `kat` feature must not be enabled in an optimised build");

/// Entropy for the vendored PQClean C.
///
/// PQClean's `common/randombytes.h` renames the symbol every scheme calls to
/// `PQCLEAN_randombytes`. Upstream supplies an implementation in
/// `common/randombytes.c`; we do not compile it (see `build.rs`) and define the
/// symbol here instead, so that native key generation, hedged signing and
/// encapsulation draw from the same `getrandom` path as the Rust side. ADR 0007
/// requires one entropy path per target with no fallback, and two independent
/// OS-RNG implementations in one artefact is not that.
///
/// # Failing closed
///
/// This function either fills `output[..n]` from the OS CSPRNG or does not
/// return. That is stronger than the `int` return type implies, and it is
/// deliberate: PQClean's callers discard the return value — `ml-dsa/sign.c`,
/// `ml-kem/kem.c`, `ml-kem/indcpa.c` and `falcon/pqclean.c` all invoke
/// `randombytes(...)` as a bare statement. Returning `-1` would therefore let
/// key generation proceed from a zeroed seed, which is the silent, unrecoverable
/// compromise ADR 0007 exists to prevent. Aborting is the same choice BoringSSL
/// and libsodium make for an unavailable CSPRNG, and on the supported targets
/// the failure is not transient: it means the OS entropy source is gone, not
/// busy. There is no retry loop and no downgrade path.
///
/// # Safety
///
/// `output` must be valid for writes of `n` bytes.
#[no_mangle]
pub unsafe extern "C" fn PQCLEAN_randombytes(output: *mut u8, n: usize) -> core::ffi::c_int {
    if n == 0 {
        return 0;
    }

    if output.is_null() {
        entropy_failure("PQCLEAN_randombytes called with a null buffer");
    }

    // SAFETY: the caller guarantees `output` is valid for `n` writes, and the
    // null case is handled above.
    let buffer = unsafe { core::slice::from_raw_parts_mut(output, n) };

    if let Err(error) = getrandom::getrandom(buffer) {
        // Whatever the OS may have written before failing is not usable entropy
        // and must not survive into a core dump.
        buffer.fill(0);
        entropy_failure(&format!("OS CSPRNG unavailable: {error}"));
    }

    0
}

/// Terminate rather than let a caller continue without secure randomness.
fn entropy_failure(reason: &str) -> ! {
    eprintln!("rwa-vault-pq-core: fatal: {reason}");
    std::process::abort();
}

/// Raw declarations for the vendored PQClean schemes.
///
/// Every function here is `unsafe` and takes unchecked pointers and lengths; the
/// buffer-size constants are the contract that makes a call sound, transcribed
/// from each scheme's `api.h`. The safe wrappers in the next stage own the
/// checking. Nothing outside this crate should call into `ffi`.
pub mod ffi {
    use core::ffi::c_int;

    pub const FALCON_PADDED_512_PUBLIC_KEY_BYTES: usize = 897;
    pub const FALCON_PADDED_512_SECRET_KEY_BYTES: usize = 1281;
    pub const FALCON_PADDED_512_SIGNATURE_BYTES: usize = 666;

    pub const ML_DSA_44_PUBLIC_KEY_BYTES: usize = 1312;
    pub const ML_DSA_44_SECRET_KEY_BYTES: usize = 2560;
    pub const ML_DSA_44_SIGNATURE_BYTES: usize = 2420;

    pub const ML_DSA_65_PUBLIC_KEY_BYTES: usize = 1952;
    pub const ML_DSA_65_SECRET_KEY_BYTES: usize = 4032;
    pub const ML_DSA_65_SIGNATURE_BYTES: usize = 3309;

    pub const ML_KEM_768_PUBLIC_KEY_BYTES: usize = 1184;
    pub const ML_KEM_768_SECRET_KEY_BYTES: usize = 2400;
    pub const ML_KEM_768_CIPHERTEXT_BYTES: usize = 1088;
    pub const ML_KEM_768_SHARED_SECRET_BYTES: usize = 32;

    pub const ML_KEM_1024_PUBLIC_KEY_BYTES: usize = 1568;
    pub const ML_KEM_1024_SECRET_KEY_BYTES: usize = 3168;
    pub const ML_KEM_1024_CIPHERTEXT_BYTES: usize = 1568;
    pub const ML_KEM_1024_SHARED_SECRET_BYTES: usize = 32;

    extern "C" {
        // Falcon-padded-512 — fixed 666-byte signatures (ADR 0003).
        pub fn PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_keypair(pk: *mut u8, sk: *mut u8)
            -> c_int;
        pub fn PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_signature(
            sig: *mut u8,
            siglen: *mut usize,
            m: *const u8,
            mlen: usize,
            sk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_verify(
            sig: *const u8,
            siglen: usize,
            m: *const u8,
            mlen: usize,
            pk: *const u8,
        ) -> c_int;

        // ML-DSA-44. The `_ctx` variants carry the FIPS 204 context string; the
        // plain ones are the empty-context case.
        pub fn PQCLEAN_MLDSA44_CLEAN_crypto_sign_keypair(pk: *mut u8, sk: *mut u8) -> c_int;
        pub fn PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature(
            sig: *mut u8,
            siglen: *mut usize,
            m: *const u8,
            mlen: usize,
            sk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify(
            sig: *const u8,
            siglen: usize,
            m: *const u8,
            mlen: usize,
            pk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature_ctx(
            sig: *mut u8,
            siglen: *mut usize,
            m: *const u8,
            mlen: usize,
            ctx: *const u8,
            ctxlen: usize,
            sk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify_ctx(
            sig: *const u8,
            siglen: usize,
            m: *const u8,
            mlen: usize,
            ctx: *const u8,
            ctxlen: usize,
            pk: *const u8,
        ) -> c_int;

        // ML-DSA-65.
        pub fn PQCLEAN_MLDSA65_CLEAN_crypto_sign_keypair(pk: *mut u8, sk: *mut u8) -> c_int;
        pub fn PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature(
            sig: *mut u8,
            siglen: *mut usize,
            m: *const u8,
            mlen: usize,
            sk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify(
            sig: *const u8,
            siglen: usize,
            m: *const u8,
            mlen: usize,
            pk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature_ctx(
            sig: *mut u8,
            siglen: *mut usize,
            m: *const u8,
            mlen: usize,
            ctx: *const u8,
            ctxlen: usize,
            sk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify_ctx(
            sig: *const u8,
            siglen: usize,
            m: *const u8,
            mlen: usize,
            ctx: *const u8,
            ctxlen: usize,
            pk: *const u8,
        ) -> c_int;

        // ML-KEM-768.
        pub fn PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair(pk: *mut u8, sk: *mut u8) -> c_int;
        pub fn PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc(
            ct: *mut u8,
            ss: *mut u8,
            pk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(
            ss: *mut u8,
            ct: *const u8,
            sk: *const u8,
        ) -> c_int;

        // ML-KEM-1024.
        pub fn PQCLEAN_MLKEM1024_CLEAN_crypto_kem_keypair(pk: *mut u8, sk: *mut u8) -> c_int;
        pub fn PQCLEAN_MLKEM1024_CLEAN_crypto_kem_enc(
            ct: *mut u8,
            ss: *mut u8,
            pk: *const u8,
        ) -> c_int;
        pub fn PQCLEAN_MLKEM1024_CLEAN_crypto_kem_dec(
            ss: *mut u8,
            ct: *const u8,
            sk: *const u8,
        ) -> c_int;
    }
}

#[cfg(test)]
mod tests {
    use super::ffi::*;

    // These tests exist to force the linker to resolve the vendored C, not to
    // establish conformance — that is ADR 0009's KAT and ACVP work. Compiling the
    // C proves nothing on its own: until something references these symbols, the
    // linker discards every object in the six static libraries, and a build that
    // would fail to link still reports success.

    const MESSAGE: &[u8] = b"RWA-Vault module 1 native linkage probe";

    #[test]
    fn entropy_reaches_the_c_side() {
        // If `PQCLEAN_randombytes` were missing, nothing below would link. If it
        // were stubbed, the draws would be constant.
        let mut first = [0u8; 64];
        let mut second = [0u8; 64];

        // SAFETY: both buffers are valid for 64 writes.
        unsafe {
            assert_eq!(
                super::PQCLEAN_randombytes(first.as_mut_ptr(), first.len()),
                0
            );
            assert_eq!(
                super::PQCLEAN_randombytes(second.as_mut_ptr(), second.len()),
                0
            );
        }

        assert_ne!(first, [0u8; 64], "entropy draw returned an all-zero buffer");
        assert_ne!(first, second, "two entropy draws were identical");
    }

    #[test]
    fn falcon_padded_512_round_trip() {
        let mut pk = [0u8; FALCON_PADDED_512_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; FALCON_PADDED_512_SECRET_KEY_BYTES];
        let mut sig = [0u8; FALCON_PADDED_512_SIGNATURE_BYTES];
        let mut siglen = 0usize;

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_signature(
                    sig.as_mut_ptr(),
                    &mut siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    sk.as_ptr()
                ),
                0
            );
        }

        // The padded parameter set is chosen so this is an equality, not a bound
        // (ADR 0003, ADR 0006).
        assert_eq!(siglen, FALCON_PADDED_512_SIGNATURE_BYTES);

        // SAFETY: as above.
        unsafe {
            assert_eq!(
                PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_verify(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    pk.as_ptr()
                ),
                0
            );
        }

        sig[0] ^= 0x01;

        // SAFETY: as above.
        unsafe {
            assert_ne!(
                PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_verify(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    pk.as_ptr()
                ),
                0,
                "a tampered signature verified"
            );
        }
    }

    #[test]
    fn ml_dsa_44_round_trip() {
        let mut pk = [0u8; ML_DSA_44_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; ML_DSA_44_SECRET_KEY_BYTES];
        let mut sig = [0u8; ML_DSA_44_SIGNATURE_BYTES];
        let mut siglen = 0usize;

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_MLDSA44_CLEAN_crypto_sign_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature(
                    sig.as_mut_ptr(),
                    &mut siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    sk.as_ptr()
                ),
                0
            );
            assert_eq!(siglen, ML_DSA_44_SIGNATURE_BYTES);
            assert_eq!(
                PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    pk.as_ptr()
                ),
                0
            );

            sig[0] ^= 0x01;
            assert_ne!(
                PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    pk.as_ptr()
                ),
                0,
                "a tampered signature verified"
            );
        }
    }

    #[test]
    fn ml_dsa_65_round_trip_with_context() {
        let context = b"rwa-vault/m1";
        let mut pk = [0u8; ML_DSA_65_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; ML_DSA_65_SECRET_KEY_BYTES];
        let mut sig = [0u8; ML_DSA_65_SIGNATURE_BYTES];
        let mut siglen = 0usize;

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_MLDSA65_CLEAN_crypto_sign_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature_ctx(
                    sig.as_mut_ptr(),
                    &mut siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    context.as_ptr(),
                    context.len(),
                    sk.as_ptr()
                ),
                0
            );
            assert_eq!(siglen, ML_DSA_65_SIGNATURE_BYTES);
            assert_eq!(
                PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify_ctx(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    context.as_ptr(),
                    context.len(),
                    pk.as_ptr()
                ),
                0
            );

            // A signature is bound to its context string: the same bytes must not
            // verify under the empty context.
            assert_ne!(
                PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify(
                    sig.as_ptr(),
                    siglen,
                    MESSAGE.as_ptr(),
                    MESSAGE.len(),
                    pk.as_ptr()
                ),
                0,
                "a context-bound signature verified under the empty context"
            );
        }
    }

    #[test]
    fn ml_kem_768_round_trip() {
        let mut pk = [0u8; ML_KEM_768_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; ML_KEM_768_SECRET_KEY_BYTES];
        let mut ct = [0u8; ML_KEM_768_CIPHERTEXT_BYTES];
        let mut sender = [0u8; ML_KEM_768_SHARED_SECRET_BYTES];
        let mut receiver = [0u8; ML_KEM_768_SHARED_SECRET_BYTES];

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc(
                    ct.as_mut_ptr(),
                    sender.as_mut_ptr(),
                    pk.as_ptr()
                ),
                0
            );
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(
                    receiver.as_mut_ptr(),
                    ct.as_ptr(),
                    sk.as_ptr()
                ),
                0
            );
        }

        assert_eq!(sender, receiver);
        assert_ne!(sender, [0u8; ML_KEM_768_SHARED_SECRET_BYTES]);

        // ML-KEM rejects implicitly: decapsulation still succeeds on a corrupted
        // ciphertext but yields an unrelated shared secret.
        ct[0] ^= 0x01;
        let mut rejected = [0u8; ML_KEM_768_SHARED_SECRET_BYTES];

        // SAFETY: as above.
        unsafe {
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(
                    rejected.as_mut_ptr(),
                    ct.as_ptr(),
                    sk.as_ptr()
                ),
                0
            );
        }

        assert_ne!(rejected, receiver, "a corrupted ciphertext decapsulated");
    }

    #[test]
    fn ml_kem_1024_round_trip() {
        let mut pk = [0u8; ML_KEM_1024_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; ML_KEM_1024_SECRET_KEY_BYTES];
        let mut ct = [0u8; ML_KEM_1024_CIPHERTEXT_BYTES];
        let mut sender = [0u8; ML_KEM_1024_SHARED_SECRET_BYTES];
        let mut receiver = [0u8; ML_KEM_1024_SHARED_SECRET_BYTES];

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_MLKEM1024_CLEAN_crypto_kem_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_MLKEM1024_CLEAN_crypto_kem_enc(
                    ct.as_mut_ptr(),
                    sender.as_mut_ptr(),
                    pk.as_ptr()
                ),
                0
            );
            assert_eq!(
                PQCLEAN_MLKEM1024_CLEAN_crypto_kem_dec(
                    receiver.as_mut_ptr(),
                    ct.as_ptr(),
                    sk.as_ptr()
                ),
                0
            );
        }

        assert_eq!(sender, receiver);
        assert_ne!(sender, [0u8; ML_KEM_1024_SHARED_SECRET_BYTES]);
    }

    #[test]
    fn distinct_key_generations_differ() {
        // Two keypairs drawn in the same process must differ. A stubbed or
        // constant entropy source is the failure this catches, and it is the one
        // that is silent and unrecoverable (ADR 0007).
        let mut first = [0u8; ML_KEM_768_PUBLIC_KEY_BYTES];
        let mut second = [0u8; ML_KEM_768_PUBLIC_KEY_BYTES];
        let mut sk = [0u8; ML_KEM_768_SECRET_KEY_BYTES];

        // SAFETY: every buffer is exactly the size api.h documents.
        unsafe {
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair(first.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
            assert_eq!(
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair(second.as_mut_ptr(), sk.as_mut_ptr()),
                0
            );
        }

        assert_ne!(first, second, "two key generations produced the same key");
    }
}
