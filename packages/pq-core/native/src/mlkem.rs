//! Safe ML-KEM wrappers over PQClean.

use crate::traits::{KemScheme, RawEncapsulation, RawKeyPair};
use crate::{Ciphertext, PqAlgorithm, PqError, PrivateKey, PublicKey, SharedSecret};
use zeroize::Zeroize;

macro_rules! mlkem_scheme {
    (
        $type:ident,
        $algorithm:expr,
        $pk_bytes:expr,
        $sk_bytes:expr,
        $ct_bytes:expr,
        $ss_bytes:expr,
        $keypair:path,
        $encapsulate:path,
        $decapsulate:path
    ) => {
        pub(crate) struct $type;

        impl KemScheme for $type {
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

            fn encapsulate(&self, public_key: &PublicKey) -> Result<RawEncapsulation, PqError> {
                if public_key.len() != $pk_bytes {
                    return Err(PqError::MalformedKey);
                }

                let mut ciphertext = vec![0u8; $ct_bytes];
                let mut shared_secret = vec![0u8; $ss_bytes];
                crate::rng::begin_operation();
                crate::ffi_guard::entered();
                // SAFETY: the public-key length was checked and both outputs have
                // the build-generated api.h sizes.
                let status = unsafe {
                    $encapsulate(
                        ciphertext.as_mut_ptr(),
                        shared_secret.as_mut_ptr(),
                        public_key.as_bytes().as_ptr(),
                    )
                };
                let rng_failed = crate::rng::take_operation_failure();
                if rng_failed || status != 0 {
                    ciphertext.zeroize();
                    shared_secret.zeroize();
                    return Err(if rng_failed {
                        PqError::RngFailure
                    } else {
                        PqError::InternalError
                    });
                }

                Ok(RawEncapsulation {
                    ciphertext: Ciphertext::for_algorithm($algorithm, ciphertext),
                    shared_secret: SharedSecret::for_algorithm($algorithm, shared_secret),
                })
            }

            fn decapsulate(
                &self,
                private_key: &PrivateKey,
                ciphertext: &Ciphertext,
            ) -> Result<SharedSecret, PqError> {
                if private_key.len() != $sk_bytes {
                    return Err(PqError::MalformedKey);
                }
                if ciphertext.len() != $ct_bytes {
                    return Err(PqError::MalformedCiphertext);
                }

                let mut shared_secret = vec![0u8; $ss_bytes];
                crate::ffi_guard::entered();
                // SAFETY: both fixed-length inputs were checked and the output
                // has the build-generated api.h size.
                let status = unsafe {
                    $decapsulate(
                        shared_secret.as_mut_ptr(),
                        ciphertext.as_bytes().as_ptr(),
                        private_key.as_bytes().as_ptr(),
                    )
                };
                if status != 0 {
                    shared_secret.zeroize();
                    return Err(PqError::InternalError);
                }

                Ok(SharedSecret::for_algorithm($algorithm, shared_secret))
            }
        }
    };
}

mlkem_scheme!(
    MlKem768Scheme,
    PqAlgorithm::MlKem768,
    crate::ffi::ML_KEM_768_PUBLIC_KEY_BYTES,
    crate::ffi::ML_KEM_768_SECRET_KEY_BYTES,
    crate::ffi::ML_KEM_768_CIPHERTEXT_BYTES,
    crate::ffi::ML_KEM_768_SHARED_SECRET_BYTES,
    crate::ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair,
    crate::ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc,
    crate::ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec
);

mlkem_scheme!(
    MlKem1024Scheme,
    PqAlgorithm::MlKem1024,
    crate::ffi::ML_KEM_1024_PUBLIC_KEY_BYTES,
    crate::ffi::ML_KEM_1024_SECRET_KEY_BYTES,
    crate::ffi::ML_KEM_1024_CIPHERTEXT_BYTES,
    crate::ffi::ML_KEM_1024_SHARED_SECRET_BYTES,
    crate::ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_keypair,
    crate::ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_enc,
    crate::ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_dec
);
