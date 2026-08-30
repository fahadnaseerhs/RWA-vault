//! Deterministic conformance hooks, compiled only with `feature = "kat"`.

use crate::slhdsa::{encode_signing_key, SecretSigningKey};
use crate::{
    encapsulate, kem_keygen, keygen, sign, Encapsulation, PqAlgorithm, PqError, PrivateKey,
    PublicKey, Signature, MAX_MESSAGE_BYTES,
};
use slh_dsa::{Sha2_128s, SigningKey};

const ML_DSA_SEED_BYTES: usize = 32;
const ML_DSA_RND_BYTES: usize = 32;
const ML_KEM_KEYGEN_SEED_BYTES: usize = 64;
const ML_KEM_M_BYTES: usize = 32;
const SLH_DSA_COMPONENT_BYTES: usize = 16;
const SLH_DSA_SEED_BYTES: usize = 3 * SLH_DSA_COMPONENT_BYTES;

/// Deterministically generate a conformance key pair.
///
/// Falcon is intentionally excluded: its Round 3 KAT uses the AES-CTR-DRBG
/// adapter that ADR 0007 confines to the test tree.
pub fn keygen_from_seed(
    algorithm: PqAlgorithm,
    seed: &[u8],
) -> Result<(PublicKey, PrivateKey), PqError> {
    match algorithm {
        PqAlgorithm::MlDsa44 | PqAlgorithm::MlDsa65 => {
            if seed.len() != ML_DSA_SEED_BYTES {
                return Err(PqError::MalformedKey);
            }
            crate::rng::with_kat_entropy(seed, || keygen(algorithm))?.map(|pair| pair.into_parts())
        }
        PqAlgorithm::MlKem768 | PqAlgorithm::MlKem1024 => {
            if seed.len() != ML_KEM_KEYGEN_SEED_BYTES {
                return Err(PqError::MalformedKey);
            }
            crate::rng::with_kat_entropy(seed, || kem_keygen(algorithm))?
                .map(|pair| pair.into_parts())
        }
        PqAlgorithm::SlhDsaSha2_128s => {
            if seed.len() != SLH_DSA_SEED_BYTES {
                return Err(PqError::MalformedKey);
            }
            let signing_key = SecretSigningKey::new(SigningKey::<Sha2_128s>::slh_keygen_internal(
                &seed[..SLH_DSA_COMPONENT_BYTES],
                &seed[SLH_DSA_COMPONENT_BYTES..2 * SLH_DSA_COMPONENT_BYTES],
                &seed[2 * SLH_DSA_COMPONENT_BYTES..],
            ));
            Ok((
                PublicKey::for_algorithm(algorithm, signing_key.as_ref().to_bytes().to_vec()),
                PrivateKey::for_algorithm(algorithm, encode_signing_key(&signing_key)),
            ))
        }
        PqAlgorithm::Falcon512 => Err(PqError::UnsupportedAlgorithm),
    }
}

/// Deterministically sign with the ACVP-provided randomizer.
pub fn sign_deterministic(
    algorithm: PqAlgorithm,
    private_key: &PrivateKey,
    message: &[u8],
    randomizer: &[u8],
) -> Result<Signature, PqError> {
    if message.len() > MAX_MESSAGE_BYTES {
        return Err(PqError::MessageTooLong);
    }
    if private_key.algorithm().is_some_and(|tag| tag != algorithm) {
        return Err(PqError::AlgorithmKeyMismatch);
    }

    match algorithm {
        PqAlgorithm::MlDsa44 | PqAlgorithm::MlDsa65 => {
            if randomizer.len() != ML_DSA_RND_BYTES {
                return Err(PqError::MalformedSignature);
            }
            crate::rng::with_kat_entropy(randomizer, || sign(algorithm, private_key, message))?
        }
        PqAlgorithm::SlhDsaSha2_128s => {
            if private_key.len() != 64 {
                return Err(PqError::MalformedKey);
            }
            if randomizer.len() != SLH_DSA_COMPONENT_BYTES {
                return Err(PqError::MalformedSignature);
            }
            let signing_key = SecretSigningKey::new(
                SigningKey::<Sha2_128s>::try_from(private_key.as_bytes())
                    .map_err(|_| PqError::MalformedKey)?,
            );
            let signature = signing_key
                .try_sign_with_context(message, &[], Some(randomizer))
                .map_err(|_| PqError::InternalError)?;
            Ok(Signature::for_algorithm(
                algorithm,
                signature.to_bytes().to_vec(),
            ))
        }
        PqAlgorithm::Falcon512 | PqAlgorithm::MlKem768 | PqAlgorithm::MlKem1024 => {
            Err(PqError::UnsupportedAlgorithm)
        }
    }
}

/// Deterministically encapsulate with the ACVP-provided `m` value.
pub fn encapsulate_with_m(
    algorithm: PqAlgorithm,
    public_key: &PublicKey,
    message: &[u8],
) -> Result<Encapsulation, PqError> {
    if !matches!(algorithm, PqAlgorithm::MlKem768 | PqAlgorithm::MlKem1024) {
        return Err(PqError::UnsupportedAlgorithm);
    }
    if message.len() != ML_KEM_M_BYTES {
        return Err(PqError::MalformedCiphertext);
    }
    crate::rng::with_kat_entropy(message, || encapsulate(algorithm, public_key))?
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{decapsulate, verify};

    #[test]
    fn ml_dsa_hooks_are_repeatable() {
        let seed = [0x11; ML_DSA_SEED_BYTES];
        let rnd = [0x22; ML_DSA_RND_BYTES];
        let (pk1, sk1) = keygen_from_seed(PqAlgorithm::MlDsa44, &seed).expect("first keygen");
        let (pk2, sk2) = keygen_from_seed(PqAlgorithm::MlDsa44, &seed).expect("second keygen");
        assert_eq!(pk1, pk2);
        assert_eq!(sk1.as_bytes(), sk2.as_bytes());

        let sig1 =
            sign_deterministic(PqAlgorithm::MlDsa44, &sk1, b"kat", &rnd).expect("first signature");
        let sig2 =
            sign_deterministic(PqAlgorithm::MlDsa44, &sk2, b"kat", &rnd).expect("second signature");
        assert_eq!(sig1, sig2);
        assert_eq!(verify(PqAlgorithm::MlDsa44, &pk1, b"kat", &sig1), Ok(true));
    }

    #[test]
    fn ml_kem_hooks_are_repeatable() {
        let seed = [0x33; ML_KEM_KEYGEN_SEED_BYTES];
        let message = [0x44; ML_KEM_M_BYTES];
        let (pk, sk) = keygen_from_seed(PqAlgorithm::MlKem768, &seed).expect("keygen");
        let first =
            encapsulate_with_m(PqAlgorithm::MlKem768, &pk, &message).expect("first encapsulation");
        let second =
            encapsulate_with_m(PqAlgorithm::MlKem768, &pk, &message).expect("second encapsulation");
        assert_eq!(first.ciphertext(), second.ciphertext());
        assert_eq!(
            first.shared_secret().as_bytes(),
            second.shared_secret().as_bytes()
        );
        let receiver =
            decapsulate(PqAlgorithm::MlKem768, &sk, first.ciphertext()).expect("decapsulation");
        assert_eq!(receiver.as_bytes(), first.shared_secret().as_bytes());
    }
}
