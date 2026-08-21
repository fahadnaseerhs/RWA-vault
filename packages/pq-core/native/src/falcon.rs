//! Safe Falcon-512 operations over PQClean's fixed-length padded variant.

use crate::{ffi, PqError, PrivateKey, PublicKey, Signature};
use zeroize::Zeroize;

/// Maximum message size fixed by ADR 0006.
pub const MAX_MESSAGE_BYTES: usize = 1_048_576;

/// A generated Falcon-512 public/private key pair.
///
/// This type intentionally has no `Debug` or `Clone` implementation because it
/// owns a [`PrivateKey`].
pub struct FalconKeyPair {
    public_key: PublicKey,
    private_key: PrivateKey,
}

impl FalconKeyPair {
    /// Borrow the encoded Falcon public key.
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Borrow the private key only for an immediate cryptographic operation.
    pub fn private_key(&self) -> &PrivateKey {
        &self.private_key
    }
}

/// Generate a Falcon-padded-512 key pair from the platform CSPRNG.
pub fn falcon_keygen() -> Result<FalconKeyPair, PqError> {
    let mut public_key = vec![0u8; ffi::FALCON_PADDED_512_PUBLIC_KEY_BYTES];
    let mut private_key = vec![0u8; ffi::FALCON_PADDED_512_SECRET_KEY_BYTES];

    crate::rng::begin_operation();
    // SAFETY: both output allocations have exactly the generated api.h sizes.
    let status = unsafe {
        ffi::PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_keypair(
            public_key.as_mut_ptr(),
            private_key.as_mut_ptr(),
        )
    };
    let rng_failed = crate::rng::take_operation_failure();

    if rng_failed || status != 0 {
        public_key.zeroize();
        private_key.zeroize();
        return Err(if rng_failed {
            PqError::RngFailure
        } else {
            PqError::InternalError
        });
    }

    Ok(FalconKeyPair {
        public_key: PublicKey::new(public_key),
        private_key: PrivateKey::new(private_key),
    })
}

/// Sign one message with a Falcon-padded-512 private key.
pub fn falcon_sign(private_key: &PrivateKey, message: &[u8]) -> Result<Signature, PqError> {
    if private_key.len() != ffi::FALCON_PADDED_512_SECRET_KEY_BYTES {
        return Err(PqError::MalformedKey);
    }
    if message.len() > MAX_MESSAGE_BYTES {
        return Err(PqError::MessageTooLong);
    }

    let mut signature = vec![0u8; ffi::FALCON_PADDED_512_SIGNATURE_BYTES];
    let mut signature_len = 0usize;

    crate::rng::begin_operation();
    // SAFETY: the key length was checked, the signature allocation has the
    // generated api.h size, and both message pointers are valid for their lengths.
    let status = unsafe {
        ffi::PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_signature(
            signature.as_mut_ptr(),
            &mut signature_len,
            message.as_ptr(),
            message.len(),
            private_key.as_bytes().as_ptr(),
        )
    };
    let rng_failed = crate::rng::take_operation_failure();

    if rng_failed || status != 0 || signature_len != ffi::FALCON_PADDED_512_SIGNATURE_BYTES {
        signature.zeroize();
        return Err(if rng_failed {
            PqError::RngFailure
        } else {
            PqError::InternalError
        });
    }

    Ok(Signature::new(signature))
}

/// Verify a Falcon-padded-512 signature.
///
/// A well-formed but invalid signature is an ordinary `Ok(false)` result.
pub fn falcon_verify(
    public_key: &PublicKey,
    message: &[u8],
    signature: &Signature,
) -> Result<bool, PqError> {
    if public_key.len() != ffi::FALCON_PADDED_512_PUBLIC_KEY_BYTES {
        return Err(PqError::MalformedKey);
    }
    if signature.len() != ffi::FALCON_PADDED_512_SIGNATURE_BYTES {
        return Err(PqError::MalformedSignature);
    }
    if message.len() > MAX_MESSAGE_BYTES {
        return Err(PqError::MessageTooLong);
    }

    // SAFETY: all fixed-length inputs were checked and the message pointer is
    // valid for its declared length.
    let status = unsafe {
        ffi::PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_verify(
            signature.as_bytes().as_ptr(),
            signature.len(),
            message.as_ptr(),
            message.len(),
            public_key.as_bytes().as_ptr(),
        )
    };

    Ok(status == 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    const MESSAGE: &[u8] = b"RWA-Vault Falcon safe-wrapper acceptance";

    #[test]
    fn round_trip_is_fixed_length_and_tampering_is_false() {
        let key_pair = falcon_keygen().expect("key generation");
        let signature = falcon_sign(key_pair.private_key(), MESSAGE).expect("signing");

        assert_eq!(signature.len(), 666);
        assert!(falcon_verify(key_pair.public_key(), MESSAGE, &signature).expect("verification"));

        let mut tampered = signature.into_bytes();
        tampered[0] ^= 0x01;
        assert_eq!(
            falcon_verify(key_pair.public_key(), MESSAGE, &Signature::new(tampered)),
            Ok(false)
        );
    }

    #[test]
    fn rng_failure_is_returned_without_a_partial_key() {
        crate::rng::fail_next_draw();
        assert!(matches!(falcon_keygen(), Err(PqError::RngFailure)));
    }

    #[test]
    fn rng_failure_is_returned_without_a_partial_signature() {
        let key_pair = falcon_keygen().expect("key generation");
        crate::rng::fail_next_draw();
        assert!(matches!(
            falcon_sign(key_pair.private_key(), MESSAGE),
            Err(PqError::RngFailure)
        ));
    }

    #[test]
    fn malformed_lengths_are_errors() {
        let key_pair = falcon_keygen().expect("key generation");
        let signature = falcon_sign(key_pair.private_key(), MESSAGE).expect("signing");

        assert_eq!(
            falcon_sign(&PrivateKey::new(vec![0u8; 1]), MESSAGE),
            Err(PqError::MalformedKey)
        );
        assert_eq!(
            falcon_verify(&PublicKey::new(vec![0u8; 1]), MESSAGE, &signature),
            Err(PqError::MalformedKey)
        );
        assert_eq!(
            falcon_verify(
                key_pair.public_key(),
                MESSAGE,
                &Signature::new(vec![0u8; 1])
            ),
            Err(PqError::MalformedSignature)
        );
    }
}
