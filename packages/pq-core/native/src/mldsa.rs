//! Safe ML-DSA wrappers over PQClean's external, empty-context interface.

use crate::traits::{RawKeyPair, SignatureScheme};
use crate::{ffi, PqAlgorithm, PqError, PrivateKey, PublicKey, Signature, MAX_MESSAGE_BYTES};
use zeroize::Zeroize;

macro_rules! mldsa_scheme {
    (
        $type:ident,
        $algorithm:expr,
        $pk_bytes:expr,
        $sk_bytes:expr,
        $sig_bytes:expr,
        $keypair:path,
        $sign:path,
        $verify:path
    ) => {
        pub(crate) struct $type;

        impl SignatureScheme for $type {
            fn keygen(&self) -> Result<RawKeyPair, PqError> {
                let mut public_key = vec![0u8; $pk_bytes];
                let mut private_key = vec![0u8; $sk_bytes];

                crate::rng::begin_operation();
                crate::ffi_guard::entered();
                // SAFETY: output buffers have the build-generated api.h sizes.
                let status = unsafe { $keypair(public_key.as_mut_ptr(), private_key.as_mut_ptr()) };
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

                Ok(RawKeyPair {
                    public_key: PublicKey::for_algorithm($algorithm, public_key),
                    private_key: PrivateKey::for_algorithm($algorithm, private_key),
                })
            }

            fn sign(&self, private_key: &PrivateKey, message: &[u8]) -> Result<Signature, PqError> {
                if private_key.len() != $sk_bytes {
                    return Err(PqError::MalformedKey);
                }
                if message.len() > MAX_MESSAGE_BYTES {
                    return Err(PqError::MessageTooLong);
                }

                let mut signature = vec![0u8; $sig_bytes];
                let mut signature_len = 0usize;
                crate::rng::begin_operation();
                crate::ffi_guard::entered();
                // SAFETY: every fixed-size input was checked. A null context is
                // valid because its declared length is zero.
                let status = unsafe {
                    $sign(
                        signature.as_mut_ptr(),
                        &mut signature_len,
                        message.as_ptr(),
                        message.len(),
                        core::ptr::null(),
                        0,
                        private_key.as_bytes().as_ptr(),
                    )
                };
                let rng_failed = crate::rng::take_operation_failure();
                if rng_failed || status != 0 || signature_len != $sig_bytes {
                    signature.zeroize();
                    return Err(if rng_failed {
                        PqError::RngFailure
                    } else {
                        PqError::InternalError
                    });
                }

                Ok(Signature::for_algorithm($algorithm, signature))
            }

            fn verify(
                &self,
                public_key: &PublicKey,
                message: &[u8],
                signature: &Signature,
            ) -> Result<bool, PqError> {
                if public_key.len() != $pk_bytes {
                    return Err(PqError::MalformedKey);
                }
                if signature.len() != $sig_bytes {
                    return Err(PqError::MalformedSignature);
                }
                if message.len() > MAX_MESSAGE_BYTES {
                    return Err(PqError::MessageTooLong);
                }

                crate::ffi_guard::entered();
                // SAFETY: fixed lengths were checked and the context has length zero.
                let status = unsafe {
                    $verify(
                        signature.as_bytes().as_ptr(),
                        signature.len(),
                        message.as_ptr(),
                        message.len(),
                        core::ptr::null(),
                        0,
                        public_key.as_bytes().as_ptr(),
                    )
                };
                Ok(status == 0)
            }
        }
    };
}

mldsa_scheme!(
    MlDsa44Scheme,
    PqAlgorithm::MlDsa44,
    ffi::ML_DSA_44_PUBLIC_KEY_BYTES,
    ffi::ML_DSA_44_SECRET_KEY_BYTES,
    ffi::ML_DSA_44_SIGNATURE_BYTES,
    ffi::PQCLEAN_MLDSA44_CLEAN_crypto_sign_keypair,
    ffi::PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature_ctx,
    ffi::PQCLEAN_MLDSA44_CLEAN_crypto_sign_verify_ctx
);

mldsa_scheme!(
    MlDsa65Scheme,
    PqAlgorithm::MlDsa65,
    ffi::ML_DSA_65_PUBLIC_KEY_BYTES,
    ffi::ML_DSA_65_SECRET_KEY_BYTES,
    ffi::ML_DSA_65_SIGNATURE_BYTES,
    ffi::PQCLEAN_MLDSA65_CLEAN_crypto_sign_keypair,
    ffi::PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature_ctx,
    ffi::PQCLEAN_MLDSA65_CLEAN_crypto_sign_verify_ctx
);
