//! ADR 0009 Source F — the negative and malformed-input suite (S2-17).
//!
//! Source F is written by us rather than imported, and it enumerates exactly
//! what must be covered: bit-flipped signatures, bit-flipped messages, a wrong
//! public key, a wrong algorithm for the key, every length one byte short and
//! one byte long, empty inputs, all-zero keys, and a message at the 1 MiB cap
//! and one byte over.
//!
//! Two rules govern every assertion below.
//!
//! 1. **Name the outcome.** Each case asserts a specific `PqError` variant or a
//!    specific `false`. A bare "did not succeed" would pass even if the guard
//!    layer returned the wrong class, which is precisely the defect this suite
//!    exists to catch.
//! 2. **Go through the public API.** The in-crate unit tests additionally prove
//!    these rejections happen before the vendored C is entered, which needs the
//!    crate-private call counter. This file proves the same rejections are
//!    reachable — and correctly classified — for an outside caller who has only
//!    the exported surface.

use std::sync::OnceLock;

use rwa_vault_pq_core::{
    algorithm_from_wire_code, decapsulate, encapsulate, kem_keygen, keygen, metadata, sign, verify,
    Ciphertext, KemKeyPair, KeyPair, PqAlgorithm, PqError, PrivateKey, PublicKey, Signature,
    MAX_MESSAGE_BYTES,
};

const MESSAGE: &[u8] = b"RWA-Vault Source F negative-input suite";

const SIGNATURE_ALGORITHMS: [PqAlgorithm; 4] = [
    PqAlgorithm::Falcon512,
    PqAlgorithm::MlDsa44,
    PqAlgorithm::MlDsa65,
    PqAlgorithm::SlhDsaSha2_128s,
];

const KEM_ALGORITHMS: [PqAlgorithm; 2] = [PqAlgorithm::MlKem768, PqAlgorithm::MlKem1024];

/// One key pair, a second unrelated key pair, and a valid signature.
///
/// SLH-DSA-SHA2-128s signing is deliberately slow, so the fixture is built once
/// per algorithm per test binary and shared by every case below.
struct SignatureFixture {
    pair: KeyPair,
    other: KeyPair,
    signature: Signature,
}

fn signature_fixture(algorithm: PqAlgorithm) -> &'static SignatureFixture {
    static FIXTURES: [OnceLock<SignatureFixture>; 4] = [
        OnceLock::new(),
        OnceLock::new(),
        OnceLock::new(),
        OnceLock::new(),
    ];

    let index = algorithm as usize - 1;
    FIXTURES[index].get_or_init(|| {
        let pair = keygen(algorithm).expect("signature keygen");
        let other = keygen(algorithm).expect("second signature keygen");
        let signature = sign(algorithm, pair.private_key(), MESSAGE).expect("signing");
        SignatureFixture {
            pair,
            other,
            signature,
        }
    })
}

fn kem_fixture(algorithm: PqAlgorithm) -> &'static KemKeyPair {
    static FIXTURES: [OnceLock<KemKeyPair>; 2] = [OnceLock::new(), OnceLock::new()];

    let index = algorithm as usize - 5;
    FIXTURES[index].get_or_init(|| kem_keygen(algorithm).expect("KEM keygen"))
}

fn flip_first_byte(bytes: &[u8]) -> Vec<u8> {
    let mut copy = bytes.to_vec();
    copy[0] ^= 0x01;
    copy
}

// ── Bit flips and wrong keys: an outcome, never an error ────────────────────

#[test]
fn a_bit_flipped_signature_verifies_false() {
    for algorithm in SIGNATURE_ALGORITHMS {
        let fixture = signature_fixture(algorithm);
        let tampered = Signature::new(flip_first_byte(fixture.signature.as_bytes()));
        assert_eq!(
            verify(algorithm, fixture.pair.public_key(), MESSAGE, &tampered),
            Ok(false),
            "{algorithm:?}: a bit-flipped signature must verify false, not error"
        );

        // The last byte matters as much as the first: a scheme that only checks
        // a header would pass the case above and fail this one.
        let mut tail_flipped = fixture.signature.as_bytes().to_vec();
        let last = tail_flipped.len() - 1;
        tail_flipped[last] ^= 0x80;
        assert_eq!(
            verify(
                algorithm,
                fixture.pair.public_key(),
                MESSAGE,
                &Signature::new(tail_flipped),
            ),
            Ok(false),
            "{algorithm:?}: a trailing bit flip must verify false"
        );
    }
}

#[test]
fn a_bit_flipped_message_verifies_false() {
    for algorithm in SIGNATURE_ALGORITHMS {
        let fixture = signature_fixture(algorithm);
        let tampered = flip_first_byte(MESSAGE);
        assert_eq!(
            verify(
                algorithm,
                fixture.pair.public_key(),
                &tampered,
                &fixture.signature,
            ),
            Ok(false),
            "{algorithm:?}: a bit-flipped message must verify false"
        );
    }
}

#[test]
fn an_unrelated_public_key_verifies_false() {
    for algorithm in SIGNATURE_ALGORITHMS {
        let fixture = signature_fixture(algorithm);
        assert_eq!(
            verify(
                algorithm,
                fixture.other.public_key(),
                MESSAGE,
                &fixture.signature,
            ),
            Ok(false),
            "{algorithm:?}: an independently generated key must verify false"
        );
    }
}

#[test]
fn all_zero_keys_and_signatures_verify_false() {
    for algorithm in SIGNATURE_ALGORITHMS {
        let row = metadata(algorithm);
        let signature_bytes = row.signature_bytes.expect("signature length");
        let fixture = signature_fixture(algorithm);

        // A zeroed buffer is the shape an uninitialised or wiped allocation
        // takes. It is correctly sized, so it must reach the primitive and be
        // rejected cryptographically rather than by a length check.
        assert_eq!(
            verify(
                algorithm,
                &PublicKey::new(vec![0u8; row.public_key_bytes]),
                MESSAGE,
                &fixture.signature,
            ),
            Ok(false),
            "{algorithm:?}: an all-zero public key must verify false"
        );
        assert_eq!(
            verify(
                algorithm,
                fixture.pair.public_key(),
                MESSAGE,
                &Signature::new(vec![0u8; signature_bytes]),
            ),
            Ok(false),
            "{algorithm:?}: an all-zero signature must verify false"
        );
    }
}

// ── Wrong algorithm for the key ─────────────────────────────────────────────

#[test]
fn a_key_tagged_for_another_algorithm_is_a_mismatch() {
    for owner in SIGNATURE_ALGORITHMS {
        let fixture = signature_fixture(owner);
        for requested in SIGNATURE_ALGORITHMS {
            if requested == owner {
                continue;
            }
            assert_eq!(
                sign(requested, fixture.pair.private_key(), MESSAGE),
                Err(PqError::AlgorithmKeyMismatch),
                "{owner:?} private key accepted by {requested:?} sign"
            );
            assert_eq!(
                verify(
                    requested,
                    fixture.pair.public_key(),
                    MESSAGE,
                    &fixture.signature,
                ),
                Err(PqError::AlgorithmKeyMismatch),
                "{owner:?} public key accepted by {requested:?} verify"
            );
        }
    }

    let ml_kem_768 = kem_fixture(PqAlgorithm::MlKem768);
    assert_eq!(
        encapsulate(PqAlgorithm::MlKem1024, ml_kem_768.public_key()).err(),
        Some(PqError::AlgorithmKeyMismatch),
        "an ML-KEM-768 key was accepted by ML-KEM-1024 encapsulation"
    );

    let sender =
        encapsulate(PqAlgorithm::MlKem768, ml_kem_768.public_key()).expect("encapsulation");
    assert_eq!(
        decapsulate(
            PqAlgorithm::MlKem1024,
            ml_kem_768.private_key(),
            sender.ciphertext(),
        )
        .err(),
        Some(PqError::AlgorithmKeyMismatch),
        "an ML-KEM-768 key was accepted by ML-KEM-1024 decapsulation"
    );
}

#[test]
fn the_wrong_operation_family_is_unsupported() {
    let kem = kem_fixture(PqAlgorithm::MlKem768);
    for algorithm in KEM_ALGORITHMS {
        assert_eq!(
            sign(algorithm, kem.private_key(), MESSAGE),
            Err(PqError::UnsupportedAlgorithm),
            "{algorithm:?} reached the signature API"
        );
    }
    for algorithm in SIGNATURE_ALGORITHMS {
        assert_eq!(
            encapsulate(algorithm, kem.public_key()).err(),
            Some(PqError::UnsupportedAlgorithm),
            "{algorithm:?} reached the KEM API"
        );
    }
}

#[test]
fn only_the_six_assigned_wire_codes_decode() {
    assert_eq!(
        algorithm_from_wire_code(0x00),
        Err(PqError::UnsupportedAlgorithm),
        "the reserved zero code decoded to an algorithm"
    );
    for value in u8::MIN..=u8::MAX {
        let decoded = algorithm_from_wire_code(value);
        if (0x01..=0x06).contains(&value) {
            assert_eq!(decoded.map(|algorithm| algorithm as u8), Ok(value));
        } else {
            assert_eq!(
                decoded,
                Err(PqError::UnsupportedAlgorithm),
                "wire code {value:#04x} decoded to an algorithm"
            );
        }
    }
}

// ── Exact lengths: one byte short, one byte long, and empty ─────────────────

#[test]
fn every_signature_input_length_is_exact() {
    for algorithm in SIGNATURE_ALGORITHMS {
        let row = metadata(algorithm);
        let signature_bytes = row.signature_bytes.expect("signature length");

        for length in [
            0,
            row.private_key_bytes - 1,
            row.private_key_bytes + 1,
            row.private_key_bytes * 2,
        ] {
            assert_eq!(
                sign(algorithm, &PrivateKey::new(vec![0u8; length]), MESSAGE),
                Err(PqError::MalformedKey),
                "{algorithm:?}: a {length}-byte private key was not rejected"
            );
        }

        for length in [
            0,
            row.public_key_bytes - 1,
            row.public_key_bytes + 1,
            row.public_key_bytes * 2,
        ] {
            assert_eq!(
                verify(
                    algorithm,
                    &PublicKey::new(vec![0u8; length]),
                    MESSAGE,
                    &Signature::new(vec![0u8; signature_bytes]),
                ),
                Err(PqError::MalformedKey),
                "{algorithm:?}: a {length}-byte public key was not rejected"
            );
        }

        for length in [
            0,
            signature_bytes - 1,
            signature_bytes + 1,
            signature_bytes * 2,
        ] {
            assert_eq!(
                verify(
                    algorithm,
                    &PublicKey::new(vec![0u8; row.public_key_bytes]),
                    MESSAGE,
                    &Signature::new(vec![0u8; length]),
                ),
                Err(PqError::MalformedSignature),
                "{algorithm:?}: a {length}-byte signature was not rejected"
            );
        }
    }
}

#[test]
fn every_kem_input_length_is_exact() {
    for algorithm in KEM_ALGORITHMS {
        let row = metadata(algorithm);
        let ciphertext_bytes = row.ciphertext_bytes.expect("ciphertext length");

        for length in [
            0,
            row.public_key_bytes - 1,
            row.public_key_bytes + 1,
            row.public_key_bytes * 2,
        ] {
            assert_eq!(
                encapsulate(algorithm, &PublicKey::new(vec![0u8; length])).err(),
                Some(PqError::MalformedKey),
                "{algorithm:?}: a {length}-byte encapsulation key was not rejected"
            );
        }

        for length in [
            0,
            row.private_key_bytes - 1,
            row.private_key_bytes + 1,
            row.private_key_bytes * 2,
        ] {
            assert_eq!(
                decapsulate(
                    algorithm,
                    &PrivateKey::new(vec![0u8; length]),
                    &Ciphertext::new(vec![0u8; ciphertext_bytes]),
                )
                .err(),
                Some(PqError::MalformedKey),
                "{algorithm:?}: a {length}-byte decapsulation key was not rejected"
            );
        }

        for length in [
            0,
            ciphertext_bytes - 1,
            ciphertext_bytes + 1,
            ciphertext_bytes * 2,
        ] {
            assert_eq!(
                decapsulate(
                    algorithm,
                    &PrivateKey::new(vec![0u8; row.private_key_bytes]),
                    &Ciphertext::new(vec![0u8; length]),
                )
                .err(),
                Some(PqError::MalformedCiphertext),
                "{algorithm:?}: a {length}-byte ciphertext was not rejected"
            );
        }
    }
}

// ── ML-KEM rejects implicitly, and must never leak which case it took ───────

#[test]
fn ml_kem_rejects_bad_ciphertexts_and_keys_implicitly() {
    for algorithm in KEM_ALGORITHMS {
        let pair = kem_fixture(algorithm);
        let row = metadata(algorithm);
        let sender = encapsulate(algorithm, pair.public_key()).expect("encapsulation");

        // A corrupted ciphertext is not an error: FIPS 203 requires
        // decapsulation to succeed and return an unrelated secret.
        let corrupted = Ciphertext::new(flip_first_byte(sender.ciphertext().as_bytes()));
        let rejected = decapsulate(algorithm, pair.private_key(), &corrupted)
            .expect("implicit rejection must not error");
        assert_ne!(
            rejected.as_bytes(),
            sender.shared_secret().as_bytes(),
            "{algorithm:?}: a corrupted ciphertext produced the sender's secret"
        );

        let zero_key = decapsulate(
            algorithm,
            &PrivateKey::new(vec![0u8; row.private_key_bytes]),
            sender.ciphertext(),
        )
        .expect("an all-zero decapsulation key must not error");
        assert_ne!(
            zero_key.as_bytes(),
            sender.shared_secret().as_bytes(),
            "{algorithm:?}: an all-zero key produced the sender's secret"
        );
        assert_eq!(
            zero_key.len(),
            row.shared_secret_bytes.expect("shared-secret length"),
            "{algorithm:?}: implicit rejection returned a short secret"
        );
    }
}

// ── The message cap: exactly at it, and one byte over ───────────────────────

#[test]
fn a_message_one_byte_over_the_cap_is_rejected_by_every_scheme() {
    let over_cap = vec![0x5a; MAX_MESSAGE_BYTES + 1];
    for algorithm in SIGNATURE_ALGORITHMS {
        let row = metadata(algorithm);
        assert_eq!(
            sign(
                algorithm,
                &PrivateKey::new(vec![0u8; row.private_key_bytes]),
                &over_cap,
            ),
            Err(PqError::MessageTooLong),
            "{algorithm:?}: signing accepted a message one byte over the cap"
        );
        assert_eq!(
            verify(
                algorithm,
                &PublicKey::new(vec![0u8; row.public_key_bytes]),
                &over_cap,
                &Signature::new(vec![0u8; row.signature_bytes.expect("signature length")]),
            ),
            Err(PqError::MessageTooLong),
            "{algorithm:?}: verification accepted a message one byte over the cap"
        );
    }
}

#[test]
fn a_message_exactly_at_the_cap_is_accepted() {
    let at_cap = vec![0x5a; MAX_MESSAGE_BYTES];

    // The boundary is inclusive. Proving that needs a real operation on a
    // 1 MiB message, so the three fast schemes carry the round trip.
    for algorithm in [
        PqAlgorithm::Falcon512,
        PqAlgorithm::MlDsa44,
        PqAlgorithm::MlDsa65,
    ] {
        let fixture = signature_fixture(algorithm);
        let signature =
            sign(algorithm, fixture.pair.private_key(), &at_cap).expect("signing at the cap");
        assert_eq!(
            verify(algorithm, fixture.pair.public_key(), &at_cap, &signature),
            Ok(true),
            "{algorithm:?}: a signature over a 1 MiB message did not verify"
        );
    }

    // SLH-DSA-SHA2-128s signing is orders of magnitude slower than the others,
    // so its inclusive boundary is proved on the verification path: a 1 MiB
    // message must reach the primitive and be answered `false`, not rejected as
    // over-length.
    let fixture = signature_fixture(PqAlgorithm::SlhDsaSha2_128s);
    assert_eq!(
        verify(
            PqAlgorithm::SlhDsaSha2_128s,
            fixture.pair.public_key(),
            &at_cap,
            &fixture.signature,
        ),
        Ok(false),
        "SLH-DSA rejected a message at the cap instead of verifying it"
    );
}

// ── Empty messages are ordinary input, not an error ─────────────────────────

#[test]
fn an_empty_message_round_trips() {
    for algorithm in [
        PqAlgorithm::Falcon512,
        PqAlgorithm::MlDsa44,
        PqAlgorithm::MlDsa65,
    ] {
        let fixture = signature_fixture(algorithm);
        let signature = sign(algorithm, fixture.pair.private_key(), b"").expect("empty signing");
        assert_eq!(
            verify(algorithm, fixture.pair.public_key(), b"", &signature),
            Ok(true),
            "{algorithm:?}: an empty message did not round-trip"
        );
        assert_eq!(
            verify(algorithm, fixture.pair.public_key(), MESSAGE, &signature),
            Ok(false),
            "{algorithm:?}: an empty-message signature verified a non-empty message"
        );
    }
}
