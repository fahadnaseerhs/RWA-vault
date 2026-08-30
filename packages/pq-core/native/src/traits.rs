//! Internal operation traits shared by C-backed and pure-Rust schemes.

use crate::{Ciphertext, PqError, PrivateKey, PublicKey, SharedSecret, Signature};

pub(crate) struct RawKeyPair {
    pub public_key: PublicKey,
    pub private_key: PrivateKey,
}

pub(crate) struct RawEncapsulation {
    pub ciphertext: Ciphertext,
    pub shared_secret: SharedSecret,
}

pub(crate) trait SignatureScheme {
    fn keygen(&self) -> Result<RawKeyPair, PqError>;
    fn sign(&self, private_key: &PrivateKey, message: &[u8]) -> Result<Signature, PqError>;
    fn verify(
        &self,
        public_key: &PublicKey,
        message: &[u8],
        signature: &Signature,
    ) -> Result<bool, PqError>;
}

pub(crate) trait KemScheme {
    fn keygen(&self) -> Result<RawKeyPair, PqError>;
    fn encapsulate(&self, public_key: &PublicKey) -> Result<RawEncapsulation, PqError>;
    fn decapsulate(
        &self,
        private_key: &PrivateKey,
        ciphertext: &Ciphertext,
    ) -> Result<SharedSecret, PqError>;
}
