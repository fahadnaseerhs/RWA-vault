//! Opaque byte containers for keys, signatures, ciphertexts, and shared secrets.

use zeroize::{Zeroize, ZeroizeOnDrop};

use crate::PqAlgorithm;

macro_rules! public_bytes {
    ($name:ident, $description:literal) => {
        #[doc = $description]
        #[derive(Clone, Debug, Eq, PartialEq)]
        pub struct $name {
            algorithm: Option<PqAlgorithm>,
            bytes: Vec<u8>,
        }

        impl $name {
            /// Wrap raw implementation bytes without re-encoding them.
            pub fn new(bytes: Vec<u8>) -> Self {
                Self {
                    algorithm: None,
                    bytes,
                }
            }

            /// Wrap bytes emitted for a specific algorithm.
            pub(crate) fn for_algorithm(algorithm: PqAlgorithm, bytes: Vec<u8>) -> Self {
                Self {
                    algorithm: Some(algorithm),
                    bytes,
                }
            }

            /// Return the algorithm tag when this value came from the stable API.
            pub fn algorithm(&self) -> Option<PqAlgorithm> {
                self.algorithm
            }

            /// Borrow the exact implementation bytes.
            pub fn as_bytes(&self) -> &[u8] {
                &self.bytes
            }

            /// Return the encoded length.
            pub fn len(&self) -> usize {
                self.bytes.len()
            }

            /// Return whether the byte string is empty.
            pub fn is_empty(&self) -> bool {
                self.bytes.is_empty()
            }

            /// Consume the wrapper and return its bytes.
            pub fn into_bytes(self) -> Vec<u8> {
                self.bytes
            }
        }

        impl AsRef<[u8]> for $name {
            fn as_ref(&self) -> &[u8] {
                self.as_bytes()
            }
        }

        impl From<Vec<u8>> for $name {
            fn from(bytes: Vec<u8>) -> Self {
                Self::new(bytes)
            }
        }
    };
}

public_bytes!(PublicKey, "An implementation-emitted public key.");
public_bytes!(Signature, "An implementation-emitted signature.");
public_bytes!(Ciphertext, "An implementation-emitted KEM ciphertext.");

macro_rules! secret_bytes {
    ($name:ident, $description:literal, $drop_observation:ident) => {
        #[doc = $description]
        ///
        /// This type intentionally does not implement `Debug` or `Clone`.
        ///
        /// # Allocation-history limitation
        ///
        /// Drop zeroizes the live allocation transferred to `new`. If the caller
        /// wrote secret bytes and then caused its `Vec` to reallocate before the
        /// transfer, an older copy may remain in allocator-owned freed memory and
        /// cannot be reached by this wrapper. Build secrets in their final-capacity
        /// allocation and avoid resizing after secret material is written.
        ///
        /// ```compile_fail
        #[doc = concat!("use rwa_vault_pq_core::", stringify!($name), ";")]
        #[doc = concat!("println!(\"{:?}\", ", stringify!($name), "::new(vec![1, 2, 3]));")]
        /// ```
        pub struct $name {
            algorithm: Option<PqAlgorithm>,
            bytes: Vec<u8>,
        }

        impl $name {
            /// Wrap raw secret bytes. The backing slice is zeroed on drop.
            pub fn new(bytes: Vec<u8>) -> Self {
                Self {
                    algorithm: None,
                    bytes,
                }
            }

            /// Wrap secret bytes emitted for a specific algorithm.
            pub(crate) fn for_algorithm(algorithm: PqAlgorithm, bytes: Vec<u8>) -> Self {
                Self {
                    algorithm: Some(algorithm),
                    bytes,
                }
            }

            /// Return the algorithm tag without exposing the secret bytes.
            pub fn algorithm(&self) -> Option<PqAlgorithm> {
                self.algorithm
            }

            /// Borrow the secret only for the immediate cryptographic operation.
            pub fn as_bytes(&self) -> &[u8] {
                &self.bytes
            }

            /// Return the secret length without formatting or logging its bytes.
            pub fn len(&self) -> usize {
                self.bytes.len()
            }

            /// Return whether the secret is empty.
            pub fn is_empty(&self) -> bool {
                self.bytes.is_empty()
            }
        }

        impl AsRef<[u8]> for $name {
            fn as_ref(&self) -> &[u8] {
                self.as_bytes()
            }
        }

        impl From<Vec<u8>> for $name {
            fn from(bytes: Vec<u8>) -> Self {
                Self::new(bytes)
            }
        }

        impl Zeroize for $name {
            fn zeroize(&mut self) {
                self.bytes.as_mut_slice().zeroize();
            }
        }

        impl ZeroizeOnDrop for $name {}

        impl Drop for $name {
            fn drop(&mut self) {
                self.zeroize();
                #[cfg(test)]
                $drop_observation.with(|observation| {
                    observation.replace(self.bytes.clone());
                });
            }
        }
    };
}

#[cfg(test)]
thread_local! {
    static PRIVATE_KEY_DROP: core::cell::RefCell<Vec<u8>> = const { core::cell::RefCell::new(Vec::new()) };
    static SHARED_SECRET_DROP: core::cell::RefCell<Vec<u8>> = const { core::cell::RefCell::new(Vec::new()) };
}

secret_bytes!(
    PrivateKey,
    "An implementation-emitted private key that zeroizes on drop.",
    PRIVATE_KEY_DROP
);
secret_bytes!(
    SharedSecret,
    "An implementation-emitted KEM shared secret that zeroizes on drop.",
    SHARED_SECRET_DROP
);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn private_key_drop_zeroizes_the_backing_buffer() {
        let secret = vec![0xa5; 64];
        drop(PrivateKey::new(secret));

        PRIVATE_KEY_DROP.with(|observation| {
            assert_eq!(&*observation.borrow(), &[0u8; 64]);
        });
    }

    #[test]
    fn shared_secret_drop_zeroizes_the_backing_buffer() {
        drop(SharedSecret::new(vec![0x5a; 32]));

        SHARED_SECRET_DROP.with(|observation| {
            assert_eq!(&*observation.borrow(), &[0u8; 32]);
        });
    }

    #[test]
    fn forced_panic_does_not_format_private_key_material() {
        const SECRET_TEXT: &str = "stage2-secret-marker-7a8f";
        let private_key = PrivateKey::new(SECRET_TEXT.as_bytes().to_vec());
        let panic = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let _key_is_live = private_key.as_bytes();
            panic!("forced cryptographic-operation panic");
        }))
        .expect_err("the test must force a panic");

        let message = panic
            .downcast_ref::<&str>()
            .copied()
            .or_else(|| panic.downcast_ref::<String>().map(String::as_str))
            .expect("panic payload is text");
        assert_eq!(message, "forced cryptographic-operation panic");
        assert!(!message.contains(SECRET_TEXT));
    }
}
