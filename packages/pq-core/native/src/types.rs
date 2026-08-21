//! Opaque byte containers for keys, signatures, ciphertexts, and shared secrets.

use zeroize::{Zeroize, ZeroizeOnDrop};

macro_rules! public_bytes {
    ($name:ident, $description:literal) => {
        #[doc = $description]
        #[derive(Clone, Debug, Eq, PartialEq)]
        pub struct $name(Vec<u8>);

        impl $name {
            /// Wrap raw implementation bytes without re-encoding them.
            pub fn new(bytes: Vec<u8>) -> Self {
                Self(bytes)
            }

            /// Borrow the exact implementation bytes.
            pub fn as_bytes(&self) -> &[u8] {
                &self.0
            }

            /// Return the encoded length.
            pub fn len(&self) -> usize {
                self.0.len()
            }

            /// Return whether the byte string is empty.
            pub fn is_empty(&self) -> bool {
                self.0.is_empty()
            }

            /// Consume the wrapper and return its bytes.
            pub fn into_bytes(self) -> Vec<u8> {
                self.0
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
        pub struct $name(Vec<u8>);

        impl $name {
            /// Wrap raw secret bytes. The backing slice is zeroed on drop.
            pub fn new(bytes: Vec<u8>) -> Self {
                Self(bytes)
            }

            /// Borrow the secret only for the immediate cryptographic operation.
            pub fn as_bytes(&self) -> &[u8] {
                &self.0
            }

            /// Return the secret length without formatting or logging its bytes.
            pub fn len(&self) -> usize {
                self.0.len()
            }

            /// Return whether the secret is empty.
            pub fn is_empty(&self) -> bool {
                self.0.is_empty()
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
                self.0.as_mut_slice().zeroize();
            }
        }

        impl ZeroizeOnDrop for $name {}

        impl Drop for $name {
            fn drop(&mut self) {
                self.zeroize();
                #[cfg(test)]
                $drop_observation.with(|observation| {
                    observation.replace(self.0.clone());
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
}
