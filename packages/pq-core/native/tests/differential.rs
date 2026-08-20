//! Differential oracle, consuming side (ADR 0003).
//!
//! Our `build.rs` compiles PQClean's portable C itself. The failure mode that
//! introduces — and that a round-trip test inside this crate cannot see — is a
//! build that is internally consistent but wrong: wrong flags, a wrong parameter
//! header, a miscompiled reduction. Anything of that kind still verifies under
//! our own verifier, because the same defect is on both sides of the check.
//!
//! The `oracle/` crate packages the same upstream through a different build
//! system. It cannot be a dev-dependency here: it vendors PQClean under the same
//! symbol names as our build, so linking both into one test binary fails with
//! LNK2005/LNK1169 on MSVC, and on GNU ld would silently bind every call to
//! whichever archive came first — an implementation checked against itself while
//! appearing to pass. The comparison therefore runs across a process boundary,
//! through committed vectors.
//!
//! Direction 1 (this file): the oracle's keys, signatures and ciphertexts must
//! be accepted by our build.
//!
//! Direction 2 (CI): this file writes our own artefacts to
//! `target/differential/native-vectors.txt`, and the oracle binary verifies them.
//! Both directions are needed — a signer and verifier that are wrong in matching
//! ways would pass either one alone.

use std::fmt::Write as _;
use std::path::PathBuf;

use rwa_vault_pq_core::ffi::*;

const ORACLE_VECTORS: &str = include_str!("vectors/oracle-vectors.txt");
const MESSAGE: &[u8] = b"RWA-Vault differential oracle vector";

fn from_hex(text: &str) -> Vec<u8> {
    assert!(text.len() % 2 == 0, "odd-length hex field");
    (0..text.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&text[i..i + 2], 16).expect("invalid hex"))
        .collect()
}

fn to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        let _ = write!(out, "{byte:02x}");
    }
    out
}

struct Record {
    scheme: String,
    fields: Vec<(String, Vec<u8>)>,
}

impl Record {
    fn get(&self, name: &str) -> &[u8] {
        self.fields
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.as_slice())
            .unwrap_or_else(|| panic!("{} vector is missing field `{name}`", self.scheme))
    }
}

fn oracle_records() -> Vec<Record> {
    let records: Vec<Record> = ORACLE_VECTORS
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(|line| {
            let mut parts = line.split('|');
            let scheme = parts.next().expect("record has no scheme tag").to_string();
            let fields = parts
                .map(|part| {
                    let (name, value) = part.split_once('=').expect("field is not name=value");
                    (name.to_string(), from_hex(value))
                })
                .collect();
            Record { scheme, fields }
        })
        .collect();
    assert!(
        !records.is_empty(),
        "no oracle vectors found; regenerate with `cargo run --manifest-path oracle/Cargo.toml -- generate`"
    );
    records
}

/// Verify a detached signature with our build. Returns the raw PQClean status.
fn our_verify(scheme: &str, sig: &[u8], msg: &[u8], pk: &[u8]) -> i32 {
    // SAFETY: every pointer/length pair below comes from a slice we own, and the
    // vendored verifiers treat all three inputs as read-only.
    unsafe {
        match scheme {
            "falcon-padded-512" => PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_verify(
                sig.as_ptr(),
                sig.len(),
                msg.as_ptr(),
                msg.len(),
                pk.as_ptr(),
            ),
            "ml-dsa-44" => PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify(
                sig.as_ptr(),
                sig.len(),
                msg.as_ptr(),
                msg.len(),
                pk.as_ptr(),
            ),
            "ml-dsa-65" => PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify(
                sig.as_ptr(),
                sig.len(),
                msg.as_ptr(),
                msg.len(),
                pk.as_ptr(),
            ),
            other => panic!("not a signature scheme: {other}"),
        }
    }
}

/// Decapsulate with our build.
fn our_decapsulate(scheme: &str, ct: &[u8], sk: &[u8]) -> Vec<u8> {
    let mut ss = vec![0u8; ML_KEM_768_SHARED_SECRET_BYTES];
    // SAFETY: `ss` is 32 bytes, the shared-secret size for both parameter sets;
    // `ct` and `sk` come from the oracle at the sizes its api.h documents.
    let status = unsafe {
        match scheme {
            "ml-kem-768" => {
                assert_eq!(ct.len(), ML_KEM_768_CIPHERTEXT_BYTES);
                assert_eq!(sk.len(), ML_KEM_768_SECRET_KEY_BYTES);
                PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(ss.as_mut_ptr(), ct.as_ptr(), sk.as_ptr())
            }
            "ml-kem-1024" => {
                assert_eq!(ct.len(), ML_KEM_1024_CIPHERTEXT_BYTES);
                assert_eq!(sk.len(), ML_KEM_1024_SECRET_KEY_BYTES);
                PQCLEAN_MLKEM1024_CLEAN_crypto_kem_dec(ss.as_mut_ptr(), ct.as_ptr(), sk.as_ptr())
            }
            other => panic!("not a KEM: {other}"),
        }
    };
    assert_eq!(status, 0, "{scheme}: decapsulation failed");
    ss
}

#[test]
fn oracle_artefacts_are_accepted_by_our_build() {
    let records = oracle_records();
    let mut seen = Vec::new();

    for record in &records {
        match record.scheme.as_str() {
            scheme @ ("falcon-padded-512" | "ml-dsa-44" | "ml-dsa-65") => {
                let (pk, msg, sig) = (record.get("pk"), record.get("msg"), record.get("sig"));
                assert_eq!(
                    our_verify(scheme, sig, msg, pk),
                    0,
                    "{scheme}: the oracle's signature did not verify under our build"
                );

                // The verifier must be discriminating, not merely permissive: a
                // build that returned 0 unconditionally would pass the check above.
                let mut tampered = sig.to_vec();
                tampered[0] ^= 0x01;
                assert_ne!(
                    our_verify(scheme, &tampered, msg, pk),
                    0,
                    "{scheme}: our build accepted a corrupted oracle signature"
                );
            }
            scheme @ ("ml-kem-768" | "ml-kem-1024") => {
                let ours = our_decapsulate(scheme, record.get("ct"), record.get("sk"));
                assert_eq!(
                    ours,
                    record.get("ss"),
                    "{scheme}: our decapsulation disagrees with the oracle"
                );
            }
            other => panic!("unknown scheme tag in oracle vectors: {other}"),
        }
        seen.push(record.scheme.clone());
    }

    for expected in [
        "falcon-padded-512",
        "ml-dsa-44",
        "ml-dsa-65",
        "ml-kem-768",
        "ml-kem-1024",
    ] {
        assert!(
            seen.iter().any(|scheme| scheme == expected),
            "oracle vectors do not cover {expected}"
        );
    }
}

#[test]
fn emit_our_artefacts_for_the_oracle() {
    let mut lines = vec![
        "# Vectors produced by the vendored build in packages/pq-core/native.".to_string(),
        "# Verify with: cargo run --manifest-path oracle/Cargo.toml -- verify <this file>"
            .to_string(),
    ];

    // Signature schemes: our keypair, our signature.
    let mut falcon_pk = [0u8; FALCON_PADDED_512_PUBLIC_KEY_BYTES];
    let mut falcon_sk = [0u8; FALCON_PADDED_512_SECRET_KEY_BYTES];
    let mut falcon_sig = [0u8; FALCON_PADDED_512_SIGNATURE_BYTES];
    let mut falcon_len = 0usize;

    // SAFETY: buffers are exactly the sizes api.h documents.
    unsafe {
        assert_eq!(
            PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_keypair(
                falcon_pk.as_mut_ptr(),
                falcon_sk.as_mut_ptr()
            ),
            0
        );
        assert_eq!(
            PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_signature(
                falcon_sig.as_mut_ptr(),
                &mut falcon_len,
                MESSAGE.as_ptr(),
                MESSAGE.len(),
                falcon_sk.as_ptr()
            ),
            0
        );
    }
    lines.push(format!(
        "falcon-padded-512|pk={}|msg={}|sig={}",
        to_hex(&falcon_pk),
        to_hex(MESSAGE),
        to_hex(&falcon_sig[..falcon_len])
    ));

    macro_rules! emit_mldsa {
        ($tag:literal, $pkn:expr, $skn:expr, $sign:expr, $keypair:path, $signature:path) => {{
            let mut pk = vec![0u8; $pkn];
            let mut sk = vec![0u8; $skn];
            let mut sig = vec![0u8; $sign];
            let mut len = 0usize;
            // SAFETY: buffers are exactly the sizes api.h documents.
            unsafe {
                assert_eq!($keypair(pk.as_mut_ptr(), sk.as_mut_ptr()), 0);
                assert_eq!(
                    $signature(
                        sig.as_mut_ptr(),
                        &mut len,
                        MESSAGE.as_ptr(),
                        MESSAGE.len(),
                        sk.as_ptr()
                    ),
                    0
                );
            }
            lines.push(format!(
                "{}|pk={}|msg={}|sig={}",
                $tag,
                to_hex(&pk),
                to_hex(MESSAGE),
                to_hex(&sig[..len])
            ));
        }};
    }

    emit_mldsa!(
        "ml-dsa-44",
        ML_DSA_44_PUBLIC_KEY_BYTES,
        ML_DSA_44_SECRET_KEY_BYTES,
        ML_DSA_44_SIGNATURE_BYTES,
        PQCLEAN_MLDSA44_CLEAN_crypto_sign_keypair,
        PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature
    );
    emit_mldsa!(
        "ml-dsa-65",
        ML_DSA_65_PUBLIC_KEY_BYTES,
        ML_DSA_65_SECRET_KEY_BYTES,
        ML_DSA_65_SIGNATURE_BYTES,
        PQCLEAN_MLDSA65_CLEAN_crypto_sign_keypair,
        PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature
    );

    macro_rules! emit_mlkem {
        ($tag:literal, $pkn:expr, $skn:expr, $ctn:expr, $keypair:path, $enc:path) => {{
            let mut pk = vec![0u8; $pkn];
            let mut sk = vec![0u8; $skn];
            let mut ct = vec![0u8; $ctn];
            let mut ss = vec![0u8; 32];
            // SAFETY: buffers are exactly the sizes api.h documents.
            unsafe {
                assert_eq!($keypair(pk.as_mut_ptr(), sk.as_mut_ptr()), 0);
                assert_eq!($enc(ct.as_mut_ptr(), ss.as_mut_ptr(), pk.as_ptr()), 0);
            }
            lines.push(format!(
                "{}|pk={}|sk={}|ct={}|ss={}",
                $tag,
                to_hex(&pk),
                to_hex(&sk),
                to_hex(&ct),
                to_hex(&ss)
            ));
        }};
    }

    emit_mlkem!(
        "ml-kem-768",
        ML_KEM_768_PUBLIC_KEY_BYTES,
        ML_KEM_768_SECRET_KEY_BYTES,
        ML_KEM_768_CIPHERTEXT_BYTES,
        PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair,
        PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc
    );
    emit_mlkem!(
        "ml-kem-1024",
        ML_KEM_1024_PUBLIC_KEY_BYTES,
        ML_KEM_1024_SECRET_KEY_BYTES,
        ML_KEM_1024_CIPHERTEXT_BYTES,
        PQCLEAN_MLKEM1024_CLEAN_crypto_kem_keypair,
        PQCLEAN_MLKEM1024_CLEAN_crypto_kem_enc
    );

    let mut path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    path.push("target/differential");
    std::fs::create_dir_all(&path).expect("cannot create differential output directory");
    path.push("native-vectors.txt");
    std::fs::write(&path, lines.join("\n") + "\n").expect("cannot write native vectors");
    eprintln!("wrote {} vectors to {}", lines.len() - 2, path.display());
}
