//! Browser boundary for all six post-quantum primitives.
//!
//! Every operation requires `init()` to have succeeded first (ADR 0007's
//! fail-closed entropy probe). The `Uint8Array` in/out boundary ensures no
//! key material crosses as a JS string (S1-14).

use crate::{
    algorithms, metadata, AlgorithmKind, PqAlgorithm, PqError, PrivateKey, PublicKey, Signature,
    Ciphertext,
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

fn parse_algorithm(name: &str) -> Result<PqAlgorithm, JsValue> {
    match name {
        "falcon-512" => Ok(PqAlgorithm::Falcon512),
        "ml-dsa-44" => Ok(PqAlgorithm::MlDsa44),
        "ml-dsa-65" => Ok(PqAlgorithm::MlDsa65),
        "slh-dsa-sha2-128s" => Ok(PqAlgorithm::SlhDsaSha2_128s),
        "ml-kem-768" => Ok(PqAlgorithm::MlKem768),
        "ml-kem-1024" => Ok(PqAlgorithm::MlKem1024),
        _ => Err(js_error(PqError::UnsupportedAlgorithm)),
    }
}

fn require_signature(algorithm: PqAlgorithm) -> Result<(), JsValue> {
    if metadata(algorithm).kind == AlgorithmKind::Signature {
        Ok(())
    } else {
        Err(js_error(PqError::UnsupportedAlgorithm))
    }
}

fn require_kem(algorithm: PqAlgorithm) -> Result<(), JsValue> {
    if metadata(algorithm).kind == AlgorithmKind::Kem {
        Ok(())
    } else {
        Err(js_error(PqError::UnsupportedAlgorithm))
    }
}

// ---------------------------------------------------------------------------
// Initialisation (ADR 0007)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Key pair output
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub struct WasmKeyPair {
    public_key: Vec<u8>,
    private_key: Vec<u8>,
}

#[wasm_bindgen]
impl WasmKeyPair {
    #[wasm_bindgen(getter, js_name = publicKey)]
    pub fn public_key(&self) -> Vec<u8> {
        self.public_key.clone()
    }

    #[wasm_bindgen(getter, js_name = privateKey)]
    pub fn private_key(&self) -> Vec<u8> {
        self.private_key.clone()
    }
}

#[wasm_bindgen]
pub struct WasmEncapsulation {
    ciphertext: Vec<u8>,
    shared_secret: Vec<u8>,
}

#[wasm_bindgen]
impl WasmEncapsulation {
    #[wasm_bindgen(getter)]
    pub fn ciphertext(&self) -> Vec<u8> {
        self.ciphertext.clone()
    }

    #[wasm_bindgen(getter, js_name = sharedSecret)]
    pub fn shared_secret(&self) -> Vec<u8> {
        self.shared_secret.clone()
    }
}

// ---------------------------------------------------------------------------
// Signature API
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn keygen(algorithm: &str) -> Result<WasmKeyPair, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_signature(alg)?;
    let pair = algorithms::keygen(alg).map_err(js_error)?;
    Ok(WasmKeyPair {
        public_key: pair.public_key().as_bytes().to_vec(),
        private_key: pair.private_key().as_bytes().to_vec(),
    })
}

#[wasm_bindgen]
pub fn sign(
    algorithm: &str,
    private_key: &[u8],
    message: &[u8],
) -> Result<Vec<u8>, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_signature(alg)?;
    let pk = PrivateKey::new(private_key.to_vec());
    algorithms::sign(alg, &pk, message)
        .map(|sig| sig.as_bytes().to_vec())
        .map_err(js_error)
}

#[wasm_bindgen]
pub fn verify(
    algorithm: &str,
    public_key: &[u8],
    message: &[u8],
    signature: &[u8],
) -> Result<bool, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_signature(alg)?;
    algorithms::verify(
        alg,
        &PublicKey::new(public_key.to_vec()),
        message,
        &Signature::new(signature.to_vec()),
    )
    .map_err(js_error)
}

#[wasm_bindgen(js_name = signatureMetadata)]
pub fn signature_metadata(algorithm: &str) -> Result<JsValue, JsValue> {
    let alg = parse_algorithm(algorithm)?;
    require_signature(alg)?;
    let row = metadata(alg);
    let obj = js_sys::Object::new();
    let _ = js_sys::Reflect::set(&obj, &"algorithm".into(), &row.identifier.into());
    let _ = js_sys::Reflect::set(&obj, &"publicKeyBytes".into(), &(row.public_key_bytes as u32).into());
    let _ = js_sys::Reflect::set(&obj, &"privateKeyBytes".into(), &(row.private_key_bytes as u32).into());
    let _ = js_sys::Reflect::set(
        &obj,
        &"signatureBytes".into(),
        &(row.signature_bytes.unwrap_or(0) as u32).into(),
    );
    Ok(obj.into())
}

// ---------------------------------------------------------------------------
// KEM API
// ---------------------------------------------------------------------------

#[wasm_bindgen(js_name = kemKeygen)]
pub fn kem_keygen(algorithm: &str) -> Result<WasmKeyPair, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_kem(alg)?;
    let pair = algorithms::kem_keygen(alg).map_err(js_error)?;
    Ok(WasmKeyPair {
        public_key: pair.public_key().as_bytes().to_vec(),
        private_key: pair.private_key().as_bytes().to_vec(),
    })
}

#[wasm_bindgen]
pub fn encapsulate(
    algorithm: &str,
    public_key: &[u8],
) -> Result<WasmEncapsulation, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_kem(alg)?;
    let enc = algorithms::encapsulate(alg, &PublicKey::new(public_key.to_vec()))
        .map_err(js_error)?;
    Ok(WasmEncapsulation {
        ciphertext: enc.ciphertext().as_bytes().to_vec(),
        shared_secret: enc.shared_secret().as_bytes().to_vec(),
    })
}

#[wasm_bindgen]
pub fn decapsulate(
    algorithm: &str,
    private_key: &[u8],
    ciphertext: &[u8],
) -> Result<Vec<u8>, JsValue> {
    require_initialised()?;
    let alg = parse_algorithm(algorithm)?;
    require_kem(alg)?;
    let ss = algorithms::decapsulate(
        alg,
        &PrivateKey::new(private_key.to_vec()),
        &Ciphertext::new(ciphertext.to_vec()),
    )
    .map_err(js_error)?;
    Ok(ss.as_bytes().to_vec())
}

#[wasm_bindgen(js_name = kemMetadata)]
pub fn kem_metadata(algorithm: &str) -> Result<JsValue, JsValue> {
    let alg = parse_algorithm(algorithm)?;
    require_kem(alg)?;
    let row = metadata(alg);
    let obj = js_sys::Object::new();
    let _ = js_sys::Reflect::set(&obj, &"algorithm".into(), &row.identifier.into());
    let _ = js_sys::Reflect::set(&obj, &"publicKeyBytes".into(), &(row.public_key_bytes as u32).into());
    let _ = js_sys::Reflect::set(&obj, &"privateKeyBytes".into(), &(row.private_key_bytes as u32).into());
    let _ = js_sys::Reflect::set(
        &obj,
        &"ciphertextBytes".into(),
        &(row.ciphertext_bytes.unwrap_or(0) as u32).into(),
    );
    let _ = js_sys::Reflect::set(
        &obj,
        &"sharedSecretBytes".into(),
        &(row.shared_secret_bytes.unwrap_or(0) as u32).into(),
    );
    Ok(obj.into())
}
