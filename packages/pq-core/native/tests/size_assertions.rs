use core::ffi::c_int;

use rwa_vault_pq_core::{ffi, metadata, AlgorithmMetadata, PqAlgorithm};
use signature::Signer;
use slh_dsa::{Sha2_128s, SigningKey};

type Keypair = unsafe extern "C" fn(*mut u8, *mut u8) -> c_int;
type Sign = unsafe extern "C" fn(*mut u8, *mut usize, *const u8, usize, *const u8) -> c_int;
type Encapsulate = unsafe extern "C" fn(*mut u8, *mut u8, *const u8) -> c_int;
type Decapsulate = unsafe extern "C" fn(*mut u8, *const u8, *const u8) -> c_int;

fn require(value: Option<usize>) -> usize {
    value.expect("operation-specific metadata length is required")
}

fn live_signature_lengths(row: &AlgorithmMetadata, keypair: Keypair, sign: Sign) {
    let mut public_key = vec![0u8; row.public_key_bytes];
    let mut private_key = vec![0u8; row.private_key_bytes];
    let mut signature = vec![0u8; require(row.signature_bytes)];
    let mut signature_len = 0usize;
    let message = b"RWA-Vault metadata size assertion";

    // SAFETY: compiling the library already proved these metadata lengths equal
    // the build-generated api.h constants, before this test binary could run.
    unsafe {
        assert_eq!(
            keypair(public_key.as_mut_ptr(), private_key.as_mut_ptr()),
            0
        );
        assert_eq!(
            sign(
                signature.as_mut_ptr(),
                &mut signature_len,
                message.as_ptr(),
                message.len(),
                private_key.as_ptr(),
            ),
            0
        );
    }

    assert_eq!(signature_len, signature.len());
}

fn live_kem_lengths(
    row: &AlgorithmMetadata,
    keypair: Keypair,
    encapsulate: Encapsulate,
    decapsulate: Decapsulate,
) {
    let mut public_key = vec![0u8; row.public_key_bytes];
    let mut private_key = vec![0u8; row.private_key_bytes];
    let mut ciphertext = vec![0u8; require(row.ciphertext_bytes)];
    let mut sender_secret = vec![0u8; require(row.shared_secret_bytes)];
    let mut receiver_secret = vec![0u8; require(row.shared_secret_bytes)];

    // SAFETY: compiling the library already proved these metadata lengths equal
    // the build-generated api.h constants, before this test binary could run.
    unsafe {
        assert_eq!(
            keypair(public_key.as_mut_ptr(), private_key.as_mut_ptr()),
            0
        );
        assert_eq!(
            encapsulate(
                ciphertext.as_mut_ptr(),
                sender_secret.as_mut_ptr(),
                public_key.as_ptr(),
            ),
            0
        );
        assert_eq!(
            decapsulate(
                receiver_secret.as_mut_ptr(),
                ciphertext.as_ptr(),
                private_key.as_ptr(),
            ),
            0
        );
    }

    assert_eq!(sender_secret, receiver_secret);
}

#[test]
fn declared_lengths_match_what_the_implementations_emit() {
    let falcon = metadata(PqAlgorithm::Falcon512);
    let ml_dsa_44 = metadata(PqAlgorithm::MlDsa44);
    let ml_dsa_65 = metadata(PqAlgorithm::MlDsa65);
    let ml_kem_768 = metadata(PqAlgorithm::MlKem768);
    let ml_kem_1024 = metadata(PqAlgorithm::MlKem1024);

    live_signature_lengths(
        falcon,
        ffi::PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_keypair,
        ffi::PQCLEAN_FALCONPADDED512_CLEAN_crypto_sign_signature,
    );
    live_signature_lengths(
        ml_dsa_44,
        ffi::PQCLEAN_MLDSA44_CLEAN_crypto_sign_keypair,
        ffi::PQCLEAN_MLDSA44_CLEAN_crypto_sign_signature,
    );
    live_signature_lengths(
        ml_dsa_65,
        ffi::PQCLEAN_MLDSA65_CLEAN_crypto_sign_keypair,
        ffi::PQCLEAN_MLDSA65_CLEAN_crypto_sign_signature,
    );
    live_kem_lengths(
        ml_kem_768,
        ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair,
        ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc,
        ffi::PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec,
    );
    live_kem_lengths(
        ml_kem_1024,
        ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_keypair,
        ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_enc,
        ffi::PQCLEAN_MLKEM1024_CLEAN_crypto_kem_dec,
    );

    let slh_row = metadata(PqAlgorithm::SlhDsaSha2_128s);
    let signing_key =
        SigningKey::<Sha2_128s>::slh_keygen_internal(&[0x11; 16], &[0x22; 16], &[0x33; 16]);
    let verifying_key = signing_key.as_ref().to_bytes();
    let signing_key_bytes = signing_key.to_bytes();
    let signature = signing_key
        .try_sign(b"RWA-Vault metadata size assertion")
        .expect("SLH-DSA signing must succeed")
        .to_bytes();

    assert_eq!(verifying_key.len(), slh_row.public_key_bytes);
    assert_eq!(signing_key_bytes.len(), slh_row.private_key_bytes);
    assert_eq!(signature.len(), require(slh_row.signature_bytes));
}
