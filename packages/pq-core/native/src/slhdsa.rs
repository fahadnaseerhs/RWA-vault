//! SLH-DSA-SHA2-128s behind the same internal trait as the C schemes.

use crate::traits::{RawKeyPair, SignatureScheme};
use crate::{PqAlgorithm, PqError, PrivateKey, PublicKey, Signature, MAX_MESSAGE_BYTES};
use signature::{Signer, Verifier};
use slh_dsa::{Sha2_128s, SigningKey, VerifyingKey};
use std::mem::ManuallyDrop;
use std::ops::Deref;
use zeroize::Zeroize;

const SEED_BYTES: usize = 16;
const PUBLIC_KEY_BYTES: usize = 32;
const PRIVATE_KEY_BYTES: usize = 64;
const SIGNATURE_BYTES: usize = 7_856;

pub(crate) struct SlhDsaSha2_128sScheme;

/// Wipes the pinned crate's in-memory signing-key representation after use.
///
/// `slh-dsa` 0.1.0 does not implement `Zeroize` for `SigningKey`. Its pinned
/// representation consists entirely of byte arrays, so all-zero is valid. The
/// `ManuallyDrop` prevents drop glue from reading the overwritten value.
pub(crate) struct SecretSigningKey(ManuallyDrop<SigningKey<Sha2_128s>>);

impl SecretSigningKey {
    pub(crate) fn new(value: SigningKey<Sha2_128s>) -> Self {
        Self(ManuallyDrop::new(value))
    }
}

impl Deref for SecretSigningKey {
    type Target = SigningKey<Sha2_128s>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for SecretSigningKey {
    fn drop(&mut self) {
        // SAFETY: the pinned `SigningKey<Sha2_128s>` contains byte arrays only,
        // all-zero is valid for those fields, and `ManuallyDrop` ensures the
        // overwritten value is never subsequently inspected by drop glue.
        unsafe {
            core::ptr::write_bytes(
                (&mut self.0 as *mut ManuallyDrop<SigningKey<Sha2_128s>>).cast::<u8>(),
                0,
                core::mem::size_of::<SigningKey<Sha2_128s>>(),
            );
        }
    }
}

/// Serialize a signing key into an owned `Vec`, wiping the pinned crate's
/// intermediate array.
///
/// `SigningKey::to_bytes` materialises the private key in a fresh
/// `hybrid_array::Array` that the pinned crate neither zeroizes nor drops with
/// zeroizing glue. Copying out and clearing that array here is what makes the
/// S2-11 audit line true rather than aspirational.
pub(crate) fn encode_signing_key(signing_key: &SigningKey<Sha2_128s>) -> Vec<u8> {
    let mut encoded = signing_key.to_bytes();
    let owned = encoded.to_vec();
    encoded.as_mut_slice().zeroize();
    owned
}

impl SignatureScheme for SlhDsaSha2_128sScheme {
    fn keygen(&self) -> Result<RawKeyPair, PqError> {
        let mut sk_seed = [0u8; SEED_BYTES];
        let mut sk_prf = [0u8; SEED_BYTES];
        let mut pk_seed = [0u8; SEED_BYTES];
        if let Err(error) = crate::rng::fill(&mut sk_seed)
            .and_then(|()| crate::rng::fill(&mut sk_prf))
            .and_then(|()| crate::rng::fill(&mut pk_seed))
        {
            sk_seed.zeroize();
            sk_prf.zeroize();
            pk_seed.zeroize();
            return Err(error);
        }

        let signing_key = SecretSigningKey::new(SigningKey::<Sha2_128s>::slh_keygen_internal(
            &sk_seed, &sk_prf, &pk_seed,
        ));
        sk_seed.zeroize();
        sk_prf.zeroize();
        pk_seed.zeroize();

        let public_key = signing_key.as_ref().to_bytes().to_vec();
        let private_key = encode_signing_key(&signing_key);
        debug_assert_eq!(public_key.len(), PUBLIC_KEY_BYTES);
        debug_assert_eq!(private_key.len(), PRIVATE_KEY_BYTES);

        Ok(RawKeyPair {
            public_key: PublicKey::for_algorithm(PqAlgorithm::SlhDsaSha2_128s, public_key),
            private_key: PrivateKey::for_algorithm(PqAlgorithm::SlhDsaSha2_128s, private_key),
        })
    }

    fn sign(&self, private_key: &PrivateKey, message: &[u8]) -> Result<Signature, PqError> {
        if private_key.len() != PRIVATE_KEY_BYTES {
            return Err(PqError::MalformedKey);
        }
        if message.len() > MAX_MESSAGE_BYTES {
            return Err(PqError::MessageTooLong);
        }

        let signing_key = SecretSigningKey::new(
            SigningKey::<Sha2_128s>::try_from(private_key.as_bytes())
                .map_err(|_| PqError::MalformedKey)?,
        );
        // `Signer::try_sign` is FIPS 205's external interface with empty ctx.
        let signature = signing_key
            .try_sign(message)
            .map_err(|_| PqError::InternalError)?
            .to_bytes()
            .to_vec();
        debug_assert_eq!(signature.len(), SIGNATURE_BYTES);
        Ok(Signature::for_algorithm(
            PqAlgorithm::SlhDsaSha2_128s,
            signature,
        ))
    }

    fn verify(
        &self,
        public_key: &PublicKey,
        message: &[u8],
        signature: &Signature,
    ) -> Result<bool, PqError> {
        if public_key.len() != PUBLIC_KEY_BYTES {
            return Err(PqError::MalformedKey);
        }
        if signature.len() != SIGNATURE_BYTES {
            return Err(PqError::MalformedSignature);
        }
        if message.len() > MAX_MESSAGE_BYTES {
            return Err(PqError::MessageTooLong);
        }

        let verifying_key = VerifyingKey::<Sha2_128s>::try_from(public_key.as_bytes())
            .map_err(|_| PqError::MalformedKey)?;
        let parsed_signature = slh_dsa::Signature::<Sha2_128s>::try_from(signature.as_bytes())
            .map_err(|_| PqError::MalformedSignature)?;
        Ok(verifying_key.verify(message, &parsed_signature).is_ok())
    }
}
