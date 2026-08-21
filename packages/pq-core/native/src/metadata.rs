//! Canonical algorithm identifiers, wire codes, and ADR 0006 byte lengths.

use crate::implementation_sizes as implementation;
use hybrid_array::typenum::Unsigned;
use slh_dsa::{Sha2_128s, SignatureLen, SigningKeyLen, VerifyingKeyLen};

/// A primitive's operation family.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AlgorithmKind {
    /// Digital-signature primitive.
    Signature,
    /// Key-encapsulation mechanism.
    Kem,
}

/// The six post-quantum primitives assigned by ADR 0002.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
#[repr(u8)]
pub enum PqAlgorithm {
    /// Fixed-length padded Round 3 Falcon-512.
    Falcon512 = 0x01,
    /// FIPS 204 ML-DSA category 2 parameter set.
    MlDsa44 = 0x02,
    /// FIPS 204 ML-DSA category 3 parameter set.
    MlDsa65 = 0x03,
    /// FIPS 205 SHA2-128s parameter set.
    SlhDsaSha2_128s = 0x04,
    /// FIPS 203 ML-KEM category 3 parameter set.
    MlKem768 = 0x05,
    /// FIPS 203 ML-KEM category 5 parameter set.
    MlKem1024 = 0x06,
}

/// Exact byte contract for one algorithm.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AlgorithmMetadata {
    /// Typed algorithm selector.
    pub algorithm: PqAlgorithm,
    /// Lowercase ASCII API identifier.
    pub identifier: &'static str,
    /// Stable one-byte wire code; zero is permanently invalid.
    pub wire_code: u8,
    /// Signature or KEM operation family.
    pub kind: AlgorithmKind,
    /// Exact serialized public-key length.
    pub public_key_bytes: usize,
    /// Exact serialized private-key length.
    pub private_key_bytes: usize,
    /// Exact signature length for signature schemes.
    pub signature_bytes: Option<usize>,
    /// Exact ciphertext length for KEMs.
    pub ciphertext_bytes: Option<usize>,
    /// Exact shared-secret length for KEMs.
    pub shared_secret_bytes: Option<usize>,
}

/// The ADR 0006 table in wire-code order.
pub const ALGORITHM_METADATA: [AlgorithmMetadata; 6] = [
    AlgorithmMetadata {
        algorithm: PqAlgorithm::Falcon512,
        identifier: "falcon-512",
        wire_code: 0x01,
        kind: AlgorithmKind::Signature,
        public_key_bytes: 897,
        private_key_bytes: 1281,
        signature_bytes: Some(666),
        ciphertext_bytes: None,
        shared_secret_bytes: None,
    },
    AlgorithmMetadata {
        algorithm: PqAlgorithm::MlDsa44,
        identifier: "ml-dsa-44",
        wire_code: 0x02,
        kind: AlgorithmKind::Signature,
        public_key_bytes: 1312,
        private_key_bytes: 2560,
        signature_bytes: Some(2420),
        ciphertext_bytes: None,
        shared_secret_bytes: None,
    },
    AlgorithmMetadata {
        algorithm: PqAlgorithm::MlDsa65,
        identifier: "ml-dsa-65",
        wire_code: 0x03,
        kind: AlgorithmKind::Signature,
        public_key_bytes: 1952,
        private_key_bytes: 4032,
        signature_bytes: Some(3309),
        ciphertext_bytes: None,
        shared_secret_bytes: None,
    },
    AlgorithmMetadata {
        algorithm: PqAlgorithm::SlhDsaSha2_128s,
        identifier: "slh-dsa-sha2-128s",
        wire_code: 0x04,
        kind: AlgorithmKind::Signature,
        public_key_bytes: 32,
        private_key_bytes: 64,
        signature_bytes: Some(7856),
        ciphertext_bytes: None,
        shared_secret_bytes: None,
    },
    AlgorithmMetadata {
        algorithm: PqAlgorithm::MlKem768,
        identifier: "ml-kem-768",
        wire_code: 0x05,
        kind: AlgorithmKind::Kem,
        public_key_bytes: 1184,
        private_key_bytes: 2400,
        signature_bytes: None,
        ciphertext_bytes: Some(1088),
        shared_secret_bytes: Some(32),
    },
    AlgorithmMetadata {
        algorithm: PqAlgorithm::MlKem1024,
        identifier: "ml-kem-1024",
        wire_code: 0x06,
        kind: AlgorithmKind::Kem,
        public_key_bytes: 1568,
        private_key_bytes: 3168,
        signature_bytes: None,
        ciphertext_bytes: Some(1568),
        shared_secret_bytes: Some(32),
    },
];

/// Return the canonical metadata row for `algorithm`.
pub const fn metadata(algorithm: PqAlgorithm) -> &'static AlgorithmMetadata {
    match algorithm {
        PqAlgorithm::Falcon512 => &ALGORITHM_METADATA[0],
        PqAlgorithm::MlDsa44 => &ALGORITHM_METADATA[1],
        PqAlgorithm::MlDsa65 => &ALGORITHM_METADATA[2],
        PqAlgorithm::SlhDsaSha2_128s => &ALGORITHM_METADATA[3],
        PqAlgorithm::MlKem768 => &ALGORITHM_METADATA[4],
        PqAlgorithm::MlKem1024 => &ALGORITHM_METADATA[5],
    }
}

// These assertions are part of crate compilation, not a later test binary. The
// C values come from build.rs parsing the pinned api.h files, while the SLH-DSA
// values come from the Rust implementation's associated serialization lengths.
// An incorrect ADR row therefore cannot compile into an undersized FFI buffer.
const _: () = {
    let mut index = 0;
    while index < ALGORITHM_METADATA.len() {
        let row = &ALGORITHM_METADATA[index];
        let expected_wire_code = index as u8 + 1;
        assert!(row.wire_code == expected_wire_code);
        assert!(row.algorithm as u8 == expected_wire_code);
        assert!(metadata(row.algorithm).algorithm as u8 == row.algorithm as u8);
        index += 1;
    }

    let falcon = metadata(PqAlgorithm::Falcon512);
    assert!(falcon.public_key_bytes == implementation::FALCON_PADDED_512_PUBLIC_KEY_BYTES);
    assert!(falcon.private_key_bytes == implementation::FALCON_PADDED_512_SECRET_KEY_BYTES);
    assert!(matches!(
        falcon.signature_bytes,
        Some(value) if value == implementation::FALCON_PADDED_512_SIGNATURE_BYTES
    ));

    let ml_dsa_44 = metadata(PqAlgorithm::MlDsa44);
    assert!(ml_dsa_44.public_key_bytes == implementation::ML_DSA_44_PUBLIC_KEY_BYTES);
    assert!(ml_dsa_44.private_key_bytes == implementation::ML_DSA_44_SECRET_KEY_BYTES);
    assert!(matches!(
        ml_dsa_44.signature_bytes,
        Some(value) if value == implementation::ML_DSA_44_SIGNATURE_BYTES
    ));

    let ml_dsa_65 = metadata(PqAlgorithm::MlDsa65);
    assert!(ml_dsa_65.public_key_bytes == implementation::ML_DSA_65_PUBLIC_KEY_BYTES);
    assert!(ml_dsa_65.private_key_bytes == implementation::ML_DSA_65_SECRET_KEY_BYTES);
    assert!(matches!(
        ml_dsa_65.signature_bytes,
        Some(value) if value == implementation::ML_DSA_65_SIGNATURE_BYTES
    ));

    let slh_dsa = metadata(PqAlgorithm::SlhDsaSha2_128s);
    assert!(slh_dsa.public_key_bytes == <<Sha2_128s as VerifyingKeyLen>::VkLen as Unsigned>::USIZE);
    assert!(slh_dsa.private_key_bytes == <<Sha2_128s as SigningKeyLen>::SkLen as Unsigned>::USIZE);
    assert!(matches!(
        slh_dsa.signature_bytes,
        Some(value) if value == <<Sha2_128s as SignatureLen>::SigLen as Unsigned>::USIZE
    ));

    let ml_kem_768 = metadata(PqAlgorithm::MlKem768);
    assert!(ml_kem_768.public_key_bytes == implementation::ML_KEM_768_PUBLIC_KEY_BYTES);
    assert!(ml_kem_768.private_key_bytes == implementation::ML_KEM_768_SECRET_KEY_BYTES);
    assert!(matches!(
        ml_kem_768.ciphertext_bytes,
        Some(value) if value == implementation::ML_KEM_768_CIPHERTEXT_BYTES
    ));
    assert!(matches!(
        ml_kem_768.shared_secret_bytes,
        Some(value) if value == implementation::ML_KEM_768_SHARED_SECRET_BYTES
    ));

    let ml_kem_1024 = metadata(PqAlgorithm::MlKem1024);
    assert!(ml_kem_1024.public_key_bytes == implementation::ML_KEM_1024_PUBLIC_KEY_BYTES);
    assert!(ml_kem_1024.private_key_bytes == implementation::ML_KEM_1024_SECRET_KEY_BYTES);
    assert!(matches!(
        ml_kem_1024.ciphertext_bytes,
        Some(value) if value == implementation::ML_KEM_1024_CIPHERTEXT_BYTES
    ));
    assert!(matches!(
        ml_kem_1024.shared_secret_bytes,
        Some(value) if value == implementation::ML_KEM_1024_SHARED_SECRET_BYTES
    ));
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn table_matches_adr_0006() {
        let expected = [
            (PqAlgorithm::Falcon512, 897, 1281, Some(666), None, None),
            (PqAlgorithm::MlDsa44, 1312, 2560, Some(2420), None, None),
            (PqAlgorithm::MlDsa65, 1952, 4032, Some(3309), None, None),
            (PqAlgorithm::SlhDsaSha2_128s, 32, 64, Some(7856), None, None),
            (
                PqAlgorithm::MlKem768,
                1184,
                2400,
                None,
                Some(1088),
                Some(32),
            ),
            (
                PqAlgorithm::MlKem1024,
                1568,
                3168,
                None,
                Some(1568),
                Some(32),
            ),
        ];

        for (algorithm, public, private, signature, ciphertext, shared_secret) in expected {
            let row = metadata(algorithm);
            assert_eq!(row.public_key_bytes, public);
            assert_eq!(row.private_key_bytes, private);
            assert_eq!(row.signature_bytes, signature);
            assert_eq!(row.ciphertext_bytes, ciphertext);
            assert_eq!(row.shared_secret_bytes, shared_secret);
            assert_eq!(row.wire_code, algorithm as u8);
        }
    }
}
