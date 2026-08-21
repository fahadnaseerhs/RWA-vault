//! Browser boundary for the Falcon device-signing slice.

use crate::{
    falcon_keygen, falcon_sign, falcon_verify, FalconKeyPair as NativeFalconKeyPair, PqError,
    PrivateKey,
};
use core::sync::atomic::{AtomicBool, Ordering};
use wasm_bindgen::prelude::*;

const ENTROPY_PROBE_BYTES: usize = 32;
static INITIALISED: AtomicBool = AtomicBool::new(false);

fn js_error(error: PqError) -> JsValue {
    let js_error = js_sys::Error::new(&error.to_string());
    let _ = js_sys::Reflect::set(
        js_error.as_ref(),
        &JsValue::from_str("code"),
        &JsValue::from_str(error.code()),
    );
    js_error.into()
}

fn require_initialised() -> Result<(), JsValue> {
    if INITIALISED.load(Ordering::SeqCst) {
        Ok(())
    } else {
        Err(js_error(PqError::NotInitialised))
    }
}

/// Probe Web Crypto and unlock cryptographic operations only after success.
///
/// Every call performs a fresh draw. This makes the runtime health check
/// repeatable and lets the browser acceptance test exercise 1,000 real draws.
#[wasm_bindgen]
pub fn init() -> Result<(), JsValue> {
    INITIALISED.store(false, Ordering::SeqCst);
    let mut probe = [0u8; ENTROPY_PROBE_BYTES];
    crate::rng::fill(&mut probe).map_err(js_error)?;

    if probe.iter().all(|byte| *byte == 0) {
        return Err(js_error(PqError::RngFailure));
    }

    INITIALISED.store(true, Ordering::SeqCst);
    Ok(())
}

/// Browser-owned Falcon key pair represented only as byte arrays.
#[wasm_bindgen]
pub struct FalconKeyPair {
    inner: NativeFalconKeyPair,
}

#[wasm_bindgen]
impl FalconKeyPair {
    /// Copy the encoded public key into a JavaScript `Uint8Array`.
    #[wasm_bindgen(getter, js_name = publicKey)]
    pub fn public_key(&self) -> Vec<u8> {
        self.inner.public_key().as_bytes().to_vec()
    }

    /// Copy the encoded private key into a JavaScript `Uint8Array`.
    #[wasm_bindgen(getter, js_name = privateKey)]
    pub fn private_key(&self) -> Vec<u8> {
        self.inner.private_key().as_bytes().to_vec()
    }
}

/// Generate one Falcon-padded-512 key pair after secure initialisation.
#[wasm_bindgen(js_name = falconKeygen)]
pub fn falcon_keygen_wasm() -> Result<FalconKeyPair, JsValue> {
    require_initialised()?;
    falcon_keygen()
        .map(|inner| FalconKeyPair { inner })
        .map_err(js_error)
}

/// Sign bytes with a Falcon-padded-512 private key.
#[wasm_bindgen(js_name = falconSign)]
pub fn falcon_sign_wasm(private_key: &[u8], message: &[u8]) -> Result<Vec<u8>, JsValue> {
    require_initialised()?;
    let private_key = PrivateKey::new(private_key.to_vec());
    falcon_sign(&private_key, message)
        .map(|signature| signature.into_bytes())
        .map_err(js_error)
}

/// Verify bytes with a Falcon-padded-512 public key.
#[wasm_bindgen(js_name = falconVerify)]
pub fn falcon_verify_wasm(
    public_key: &[u8],
    message: &[u8],
    signature: &[u8],
) -> Result<bool, JsValue> {
    require_initialised()?;
    falcon_verify(
        &crate::PublicKey::new(public_key.to_vec()),
        message,
        &crate::Signature::new(signature.to_vec()),
    )
    .map_err(js_error)
}
