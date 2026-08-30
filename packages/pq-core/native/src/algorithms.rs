//! Stable dispatch and guard layer for all six algorithm identifiers.

use crate::falcon::FalconScheme;
use crate::mldsa::{MlDsa44Scheme, MlDsa65Scheme};
use crate::mlkem::{MlKem1024Scheme, MlKem768Scheme};
use crate::slhdsa::SlhDsaSha2_128sScheme;
use crate::traits::{KemScheme, RawEncapsulation, RawKeyPair, SignatureScheme};
use crate::{
    metadata, AlgorithmKind, AlgorithmMetadata, Ciphertext, PqAlgorithm, PqError, PrivateKey,
    PublicKey, SharedSecret, Signature,
};

static FALCON: FalconScheme = FalconScheme;
static ML_DSA_44: MlDsa44Scheme = MlDsa44Scheme;
static ML_DSA_65: MlDsa65Scheme = MlDsa65Scheme;
static SLH_DSA_SHA2_128S: SlhDsaSha2_128sScheme = SlhDsaSha2_128sScheme;
static ML_KEM_768: MlKem768Scheme = MlKem768Scheme;
static ML_KEM_1024: MlKem1024Scheme = MlKem1024Scheme;

/// A generated signature key pair.
///
/// This type intentionally does not implement `Debug` or `Clone` because it
/// owns private key material.
pub struct KeyPair {
    public_key: PublicKey,
    private_key: PrivateKey,
}

impl KeyPair {
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    pub fn private_key(&self) -> &PrivateKey {
        &self.private_key
    }

    #[cfg(feature = "kat")]
    pub(crate) fn into_parts(self) -> (PublicKey, PrivateKey) {
        (self.public_key, self.private_key)
    }
}

/// A generated KEM key pair.
///
/// Kept distinct from [`KeyPair`] so callers cannot accidentally pass a KEM
/// key pair to a signature-only API.
pub struct KemKeyPair {
    public_key: PublicKey,
    private_key: PrivateKey,
}

impl KemKeyPair {
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    pub fn private_key(&self) -> &PrivateKey {
        &self.private_key
    }

    #[cfg(feature = "kat")]
    pub(crate) fn into_parts(self) -> (PublicKey, PrivateKey) {
        (self.public_key, self.private_key)
    }
}

/// The sender outputs of KEM encapsulation.
pub struct Encapsulation {
    ciphertext: Ciphertext,
    shared_secret: SharedSecret,
}

impl Encapsulation {
    pub fn ciphertext(&self) -> &Ciphertext {
        &self.ciphertext
    }

    pub fn shared_secret(&self) -> &SharedSecret {
        &self.shared_secret
    }
}

/// Decode the canonical ADR 0006 wire code.
pub fn algorithm_from_wire_code(wire_code: u8) -> Result<PqAlgorithm, PqError> {
    match wire_code {
        0x01 => Ok(PqAlgorithm::Falcon512),
        0x02 => Ok(PqAlgorithm::MlDsa44),
        0x03 => Ok(PqAlgorithm::MlDsa65),
        0x04 => Ok(PqAlgorithm::SlhDsaSha2_128s),
        0x05 => Ok(PqAlgorithm::MlKem768),
        0x06 => Ok(PqAlgorithm::MlKem1024),
        _ => Err(PqError::UnsupportedAlgorithm),
    }
}

fn signature_scheme(algorithm: PqAlgorithm) -> Result<&'static dyn SignatureScheme, PqError> {
    match algorithm {
        PqAlgorithm::Falcon512 => Ok(&FALCON),
        PqAlgorithm::MlDsa44 => Ok(&ML_DSA_44),
        PqAlgorithm::MlDsa65 => Ok(&ML_DSA_65),
        PqAlgorithm::SlhDsaSha2_128s => Ok(&SLH_DSA_SHA2_128S),
        PqAlgorithm::MlKem768 | PqAlgorithm::MlKem1024 => Err(PqError::UnsupportedAlgorithm),
    }
}

fn kem_scheme(algorithm: PqAlgorithm) -> Result<&'static dyn KemScheme, PqError> {
    match algorithm {
        PqAlgorithm::MlKem768 => Ok(&ML_KEM_768),
        PqAlgorithm::MlKem1024 => Ok(&ML_KEM_1024),
        PqAlgorithm::Falcon512
        | PqAlgorithm::MlDsa44
        | PqAlgorithm::MlDsa65
        | PqAlgorithm::SlhDsaSha2_128s => Err(PqError::UnsupportedAlgorithm),
    }
}

fn require_tag(actual: Option<PqAlgorithm>, expected: PqAlgorithm) -> Result<(), PqError> {
    if actual.is_some_and(|algorithm| algorithm != expected) {
        Err(PqError::AlgorithmKeyMismatch)
    } else {
        Ok(())
    }
}

fn key_pair(raw: RawKeyPair) -> KeyPair {
    KeyPair {
        public_key: raw.public_key,
        private_key: raw.private_key,
    }
}

fn kem_key_pair(raw: RawKeyPair) -> KemKeyPair {
    KemKeyPair {
        public_key: raw.public_key,
        private_key: raw.private_key,
    }
}

fn encapsulation(raw: RawEncapsulation) -> Encapsulation {
    Encapsulation {
        ciphertext: raw.ciphertext,
        shared_secret: raw.shared_secret,
    }
}

/// Generate a key pair for one of the four signature schemes.
pub fn keygen(algorithm: PqAlgorithm) -> Result<KeyPair, PqError> {
    signature_scheme(algorithm)?.keygen().map(key_pair)
}

/// Sign exactly the caller-provided message bytes.
pub fn sign(
    algorithm: PqAlgorithm,
    private_key: &PrivateKey,
    message: &[u8],
) -> Result<Signature, PqError> {
    let scheme = signature_scheme(algorithm)?;
    require_tag(private_key.algorithm(), algorithm)?;
    scheme.sign(private_key, message)
}

/// Verify exactly the caller-provided message bytes.
pub fn verify(
    algorithm: PqAlgorithm,
    public_key: &PublicKey,
    message: &[u8],
    signature: &Signature,
) -> Result<bool, PqError> {
    let scheme = signature_scheme(algorithm)?;
    require_tag(public_key.algorithm(), algorithm)?;
    require_tag(signature.algorithm(), algorithm)?;
    scheme.verify(public_key, message, signature)
}

/// Metadata for a signature scheme. KEM selectors are rejected.
pub fn signature_metadata(algorithm: PqAlgorithm) -> Result<&'static AlgorithmMetadata, PqError> {
    let row = metadata(algorithm);
    if row.kind == AlgorithmKind::Signature {
        Ok(row)
    } else {
        Err(PqError::UnsupportedAlgorithm)
    }
}

/// Generate a key pair for one of the two KEM parameter sets.
pub fn kem_keygen(algorithm: PqAlgorithm) -> Result<KemKeyPair, PqError> {
    kem_scheme(algorithm)?.keygen().map(kem_key_pair)
}

/// Encapsulate to a KEM public key.
pub fn encapsulate(
    algorithm: PqAlgorithm,
    public_key: &PublicKey,
) -> Result<Encapsulation, PqError> {
    let scheme = kem_scheme(algorithm)?;
    require_tag(public_key.algorithm(), algorithm)?;
    scheme.encapsulate(public_key).map(encapsulation)
}

/// Decapsulate a KEM ciphertext.
pub fn decapsulate(
    algorithm: PqAlgorithm,
    private_key: &PrivateKey,
    ciphertext: &Ciphertext,
) -> Result<SharedSecret, PqError> {
    let scheme = kem_scheme(algorithm)?;
    require_tag(private_key.algorithm(), algorithm)?;
    require_tag(ciphertext.algorithm(), algorithm)?;
    scheme.decapsulate(private_key, ciphertext)
}

/// Metadata for a KEM. Signature selectors are rejected.
pub fn kem_metadata(algorithm: PqAlgorithm) -> Result<&'static AlgorithmMetadata, PqError> {
    let row = metadata(algorithm);
    if row.kind == AlgorithmKind::Kem {
        Ok(row)
    } else {
        Err(PqError::UnsupportedAlgorithm)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MESSAGE: &[u8] = b"RWA-Vault Stage 2 matrix";

    #[test]
    fn only_six_wire_codes_dispatch() {
        for value in u8::MIN..=u8::MAX {
            let result = algorithm_from_wire_code(value);
            if (1..=6).contains(&value) {
                assert_eq!(result.map(|algorithm| algorithm as u8), Ok(value));
            } else {
                assert_eq!(result, Err(PqError::UnsupportedAlgorithm));
            }
        }
    }

    #[test]
    fn wrong_kind_is_unsupported() {
        let kem = kem_keygen(PqAlgorithm::MlKem768).expect("KEM keygen");
        assert!(matches!(
            sign(PqAlgorithm::MlKem768, kem.private_key(), b"message"),
            Err(PqError::UnsupportedAlgorithm)
        ));
        assert!(matches!(
            encapsulate(PqAlgorithm::Falcon512, kem.public_key()),
            Err(PqError::UnsupportedAlgorithm)
        ));
    }

    #[test]
    fn tagged_algorithm_mismatch_precedes_ffi() {
        let pair = keygen(PqAlgorithm::MlDsa65).expect("ML-DSA-65 keygen");
        let before = crate::ffi_guard::count();
        assert!(matches!(
            sign(PqAlgorithm::MlDsa44, pair.private_key(), b"message"),
            Err(PqError::AlgorithmKeyMismatch)
        ));
        assert_eq!(crate::ffi_guard::count(), before);
    }

    #[test]
    fn malformed_length_precedes_ffi() {
        let before = crate::ffi_guard::count();
        assert_eq!(
            sign(
                PqAlgorithm::MlDsa44,
                &PrivateKey::new(vec![0u8; 2_559]),
                b"message",
            ),
            Err(PqError::MalformedKey)
        );
        assert_eq!(crate::ffi_guard::count(), before);
    }

    #[test]
    fn every_input_rejects_short_and_long_lengths_before_ffi() {
        // SLH-DSA is included even though it never enters C: the exact-length
        // rule in ADR 0006 is a property of the API surface, not of the backing
        // implementation, and a caller cannot tell the two apart.
        for algorithm in [
            PqAlgorithm::Falcon512,
            PqAlgorithm::MlDsa44,
            PqAlgorithm::MlDsa65,
            PqAlgorithm::SlhDsaSha2_128s,
        ] {
            let row = metadata(algorithm);
            let signature_bytes = row.signature_bytes.expect("signature length");
            for length in [row.private_key_bytes - 1, row.private_key_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert_eq!(
                    sign(algorithm, &PrivateKey::new(vec![0u8; length]), MESSAGE),
                    Err(PqError::MalformedKey)
                );
                assert_eq!(crate::ffi_guard::count(), before);
            }
            for length in [row.public_key_bytes - 1, row.public_key_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert_eq!(
                    verify(
                        algorithm,
                        &PublicKey::new(vec![0u8; length]),
                        MESSAGE,
                        &Signature::new(vec![0u8; signature_bytes]),
                    ),
                    Err(PqError::MalformedKey)
                );
                assert_eq!(crate::ffi_guard::count(), before);
            }
            for length in [signature_bytes - 1, signature_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert_eq!(
                    verify(
                        algorithm,
                        &PublicKey::new(vec![0u8; row.public_key_bytes]),
                        MESSAGE,
                        &Signature::new(vec![0u8; length]),
                    ),
                    Err(PqError::MalformedSignature)
                );
                assert_eq!(crate::ffi_guard::count(), before);
            }
        }

        for algorithm in [PqAlgorithm::MlKem768, PqAlgorithm::MlKem1024] {
            let row = metadata(algorithm);
            let ciphertext_bytes = row.ciphertext_bytes.expect("ciphertext length");
            for length in [row.public_key_bytes - 1, row.public_key_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert!(matches!(
                    encapsulate(algorithm, &PublicKey::new(vec![0u8; length])),
                    Err(PqError::MalformedKey)
                ));
                assert_eq!(crate::ffi_guard::count(), before);
            }
            for length in [row.private_key_bytes - 1, row.private_key_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert!(matches!(
                    decapsulate(
                        algorithm,
                        &PrivateKey::new(vec![0u8; length]),
                        &Ciphertext::new(vec![0u8; ciphertext_bytes]),
                    ),
                    Err(PqError::MalformedKey)
                ));
                assert_eq!(crate::ffi_guard::count(), before);
            }
            for length in [ciphertext_bytes - 1, ciphertext_bytes + 1] {
                let before = crate::ffi_guard::count();
                assert!(matches!(
                    decapsulate(
                        algorithm,
                        &PrivateKey::new(vec![0u8; row.private_key_bytes]),
                        &Ciphertext::new(vec![0u8; length]),
                    ),
                    Err(PqError::MalformedCiphertext)
                ));
                assert_eq!(crate::ffi_guard::count(), before);
            }
        }
    }

    fn signature_standard_cases(algorithm: PqAlgorithm) {
        let pair = keygen(algorithm).expect("signature keygen");
        let signature = sign(algorithm, pair.private_key(), MESSAGE).expect("signature");
        let row = signature_metadata(algorithm).expect("signature metadata");
        assert_eq!(pair.public_key().len(), row.public_key_bytes);
        assert_eq!(pair.private_key().len(), row.private_key_bytes);
        assert_eq!(
            signature.len(),
            row.signature_bytes.expect("signature bytes")
        );
        assert_eq!(
            verify(algorithm, pair.public_key(), MESSAGE, &signature),
            Ok(true)
        );
        assert_eq!(
            verify(algorithm, pair.public_key(), b"wrong message", &signature),
            Ok(false)
        );

        let mut wrong_key = pair.public_key().as_bytes().to_vec();
        wrong_key[0] ^= 1;
        assert_eq!(
            verify(
                algorithm,
                &PublicKey::for_algorithm(algorithm, wrong_key),
                MESSAGE,
                &signature,
            ),
            Ok(false)
        );

        let empty_signature = sign(algorithm, pair.private_key(), b"").expect("empty signing");
        assert_eq!(
            verify(algorithm, pair.public_key(), b"", &empty_signature),
            Ok(true)
        );
        assert_eq!(
            sign(algorithm, &PrivateKey::new(Vec::new()), MESSAGE),
            Err(PqError::MalformedKey)
        );
        assert_eq!(
            verify(
                algorithm,
                pair.public_key(),
                MESSAGE,
                &Signature::new(Vec::new()),
            ),
            Err(PqError::MalformedSignature)
        );
    }

    fn kem_standard_cases(algorithm: PqAlgorithm) {
        let pair = kem_keygen(algorithm).expect("KEM keygen");
        let sender = encapsulate(algorithm, pair.public_key()).expect("encapsulation");
        let receiver =
            decapsulate(algorithm, pair.private_key(), sender.ciphertext()).expect("decapsulation");
        let row = kem_metadata(algorithm).expect("KEM metadata");
        assert_eq!(pair.public_key().len(), row.public_key_bytes);
        assert_eq!(pair.private_key().len(), row.private_key_bytes);
        assert_eq!(
            sender.ciphertext().len(),
            row.ciphertext_bytes.expect("ciphertext bytes")
        );
        assert_eq!(sender.shared_secret().as_bytes(), receiver.as_bytes());

        let mut wrong_private_key = pair.private_key().as_bytes().to_vec();
        wrong_private_key[0] ^= 1;
        let rejected = decapsulate(
            algorithm,
            &PrivateKey::for_algorithm(algorithm, wrong_private_key),
            sender.ciphertext(),
        )
        .expect("ML-KEM implicit rejection");
        assert_ne!(rejected.as_bytes(), sender.shared_secret().as_bytes());
        assert!(matches!(
            encapsulate(algorithm, &PublicKey::new(Vec::new())),
            Err(PqError::MalformedKey)
        ));
        assert!(matches!(
            decapsulate(algorithm, pair.private_key(), &Ciphertext::new(Vec::new()),),
            Err(PqError::MalformedCiphertext)
        ));
    }

    #[test]
    fn falcon_512_standard_cases() {
        signature_standard_cases(PqAlgorithm::Falcon512);
    }

    #[test]
    fn ml_dsa_44_standard_cases() {
        signature_standard_cases(PqAlgorithm::MlDsa44);
    }

    #[test]
    fn ml_dsa_65_standard_cases() {
        signature_standard_cases(PqAlgorithm::MlDsa65);
    }

    #[test]
    fn slh_dsa_sha2_128s_standard_cases() {
        signature_standard_cases(PqAlgorithm::SlhDsaSha2_128s);
    }

    #[test]
    fn ml_kem_768_standard_cases() {
        kem_standard_cases(PqAlgorithm::MlKem768);
    }

    #[test]
    fn ml_kem_1024_standard_cases() {
        kem_standard_cases(PqAlgorithm::MlKem1024);
    }

    #[test]
    fn message_cap_is_exact_and_checked_before_ffi() {
        let pair = keygen(PqAlgorithm::MlDsa44).expect("keygen");
        let at_cap = vec![0x5a; crate::MAX_MESSAGE_BYTES];
        let signature =
            sign(PqAlgorithm::MlDsa44, pair.private_key(), &at_cap).expect("signing at the cap");
        assert_eq!(
            verify(PqAlgorithm::MlDsa44, pair.public_key(), &at_cap, &signature),
            Ok(true)
        );

        let over_cap = vec![0x5a; crate::MAX_MESSAGE_BYTES + 1];
        let before = crate::ffi_guard::count();
        assert_eq!(
            sign(PqAlgorithm::MlDsa44, pair.private_key(), &over_cap),
            Err(PqError::MessageTooLong)
        );
        assert_eq!(
            verify(
                PqAlgorithm::MlDsa44,
                pair.public_key(),
                &over_cap,
                &signature
            ),
            Err(PqError::MessageTooLong)
        );
        assert_eq!(crate::ffi_guard::count(), before);
    }

    #[test]
    fn every_signature_scheme_rejects_an_over_cap_message_before_ffi() {
        // The cap is a property of every signature identifier, so the rejection
        // is proved for all four. It costs no cryptographic work: the check runs
        // before any key material is touched.
        let over_cap = vec![0x5a; crate::MAX_MESSAGE_BYTES + 1];
        for algorithm in [
            PqAlgorithm::Falcon512,
            PqAlgorithm::MlDsa44,
            PqAlgorithm::MlDsa65,
            PqAlgorithm::SlhDsaSha2_128s,
        ] {
            let row = metadata(algorithm);
            let before = crate::ffi_guard::count();
            assert_eq!(
                sign(
                    algorithm,
                    &PrivateKey::new(vec![0u8; row.private_key_bytes]),
                    &over_cap,
                ),
                Err(PqError::MessageTooLong)
            );
            assert_eq!(
                verify(
                    algorithm,
                    &PublicKey::new(vec![0u8; row.public_key_bytes]),
                    &over_cap,
                    &Signature::new(vec![0u8; row.signature_bytes.expect("signature length")]),
                ),
                Err(PqError::MessageTooLong)
            );
            assert_eq!(crate::ffi_guard::count(), before);
        }
    }
}
