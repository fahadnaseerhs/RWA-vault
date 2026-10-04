//! Node-API addon for RWA-Vault post-quantum primitives.
//!
//! Stateless: every call receives its inputs and returns outputs with no
//! global mutable state in the crate. Async variants (`AsyncTask`) are the
//! default so that slow operations (SLH-DSA verify, Falcon keygen) do not
//! block the Node.js event loop.
//!
//! **ADR 0005:** SLH-DSA *signing* is deliberately excluded from this addon.
//! Only verification is exposed server-side. Signing runs offline via `pqctl`.

use napi::bindgen_prelude::*;
use napi_derive::napi;
use rwa_vault_pq_core as pq;
use pq::{PqAlgorithm, PqError};

// ---------------------------------------------------------------------------
// Error mapping (S3-03)
// ---------------------------------------------------------------------------

fn to_napi_error(error: PqError) -> napi::Error {
    napi::Error::new(
        napi::Status::GenericFailure,
        format!("[{}] {}", error.code(), error),
    )
}

fn parse_signature_algorithm(name: &str) -> Result<PqAlgorithm> {
    match name {
        "falcon-512" => Ok(PqAlgorithm::Falcon512),
        "ml-dsa-44" => Ok(PqAlgorithm::MlDsa44),
        "ml-dsa-65" => Ok(PqAlgorithm::MlDsa65),
        "slh-dsa-sha2-128s" => Ok(PqAlgorithm::SlhDsaSha2_128s),
        _ => Err(to_napi_error(PqError::UnsupportedAlgorithm)),
    }
}

fn parse_kem_algorithm(name: &str) -> Result<PqAlgorithm> {
    match name {
        "ml-kem-768" => Ok(PqAlgorithm::MlKem768),
        "ml-kem-1024" => Ok(PqAlgorithm::MlKem1024),
        _ => Err(to_napi_error(PqError::UnsupportedAlgorithm)),
    }
}

// ---------------------------------------------------------------------------
// Key pair / encapsulation output structs
// ---------------------------------------------------------------------------

#[napi(object)]
pub struct NapiKeyPair {
    pub public_key: Buffer,
    pub private_key: Buffer,
}

#[napi(object)]
pub struct NapiEncapsulation {
    pub ciphertext: Buffer,
    pub shared_secret: Buffer,
}

#[napi(object)]
pub struct NapiSignatureMetadata {
    pub algorithm: String,
    pub public_key_bytes: u32,
    pub private_key_bytes: u32,
    pub signature_bytes: u32,
}

#[napi(object)]
pub struct NapiKemMetadata {
    pub algorithm: String,
    pub public_key_bytes: u32,
    pub private_key_bytes: u32,
    pub ciphertext_bytes: u32,
    pub shared_secret_bytes: u32,
}

// ---------------------------------------------------------------------------
// Async tasks (S3-02)
// ---------------------------------------------------------------------------

struct KeygenTask {
    algorithm: PqAlgorithm,
}

#[napi]
impl Task for KeygenTask {
    type Output = (Vec<u8>, Vec<u8>);
    type JsValue = NapiKeyPair;

    fn compute(&mut self) -> Result<Self::Output> {
        let pair = pq::keygen(self.algorithm).map_err(to_napi_error)?;
        Ok((
            pair.public_key().as_bytes().to_vec(),
            pair.private_key().as_bytes().to_vec(),
        ))
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(NapiKeyPair {
            public_key: output.0.into(),
            private_key: output.1.into(),
        })
    }
}

struct SignTask {
    algorithm: PqAlgorithm,
    private_key: Vec<u8>,
    message: Vec<u8>,
}

#[napi]
impl Task for SignTask {
    type Output = Vec<u8>;
    type JsValue = Buffer;

    fn compute(&mut self) -> Result<Self::Output> {
        let pk = pq::PrivateKey::new(std::mem::take(&mut self.private_key));
        let sig = pq::sign(self.algorithm, &pk, &self.message).map_err(to_napi_error)?;
        Ok(sig.as_bytes().to_vec())
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(output.into())
    }
}

struct VerifyTask {
    algorithm: PqAlgorithm,
    public_key: Vec<u8>,
    message: Vec<u8>,
    signature: Vec<u8>,
}

#[napi]
impl Task for VerifyTask {
    type Output = bool;
    type JsValue = bool;

    fn compute(&mut self) -> Result<Self::Output> {
        let pk = pq::PublicKey::new(std::mem::take(&mut self.public_key));
        let sig = pq::Signature::new(std::mem::take(&mut self.signature));
        pq::verify(self.algorithm, &pk, &self.message, &sig).map_err(to_napi_error)
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(output)
    }
}

struct KemKeygenTask {
    algorithm: PqAlgorithm,
}

#[napi]
impl Task for KemKeygenTask {
    type Output = (Vec<u8>, Vec<u8>);
    type JsValue = NapiKeyPair;

    fn compute(&mut self) -> Result<Self::Output> {
        let pair = pq::kem_keygen(self.algorithm).map_err(to_napi_error)?;
        Ok((
            pair.public_key().as_bytes().to_vec(),
            pair.private_key().as_bytes().to_vec(),
        ))
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(NapiKeyPair {
            public_key: output.0.into(),
            private_key: output.1.into(),
        })
    }
}

struct EncapsulateTask {
    algorithm: PqAlgorithm,
    public_key: Vec<u8>,
}

#[napi]
impl Task for EncapsulateTask {
    type Output = (Vec<u8>, Vec<u8>);
    type JsValue = NapiEncapsulation;

    fn compute(&mut self) -> Result<Self::Output> {
        let pk = pq::PublicKey::new(std::mem::take(&mut self.public_key));
        let enc = pq::encapsulate(self.algorithm, &pk).map_err(to_napi_error)?;
        Ok((
            enc.ciphertext().as_bytes().to_vec(),
            enc.shared_secret().as_bytes().to_vec(),
        ))
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(NapiEncapsulation {
            ciphertext: output.0.into(),
            shared_secret: output.1.into(),
        })
    }
}

struct DecapsulateTask {
    algorithm: PqAlgorithm,
    private_key: Vec<u8>,
    ciphertext: Vec<u8>,
}

#[napi]
impl Task for DecapsulateTask {
    type Output = Vec<u8>;
    type JsValue = Buffer;

    fn compute(&mut self) -> Result<Self::Output> {
        let sk = pq::PrivateKey::new(std::mem::take(&mut self.private_key));
        let ct = pq::Ciphertext::new(std::mem::take(&mut self.ciphertext));
        let ss = pq::decapsulate(self.algorithm, &sk, &ct).map_err(to_napi_error)?;
        Ok(ss.as_bytes().to_vec())
    }

    fn resolve(&mut self, _env: Env, output: Self::Output) -> Result<Self::JsValue> {
        Ok(output.into())
    }
}

// ---------------------------------------------------------------------------
// Signature API
// ---------------------------------------------------------------------------

#[napi]
pub fn keygen(algorithm: String) -> AsyncTask<KeygenTask> {
    AsyncTask::new(KeygenTask {
        algorithm: parse_signature_algorithm(&algorithm).unwrap_or(PqAlgorithm::Falcon512),
    })
}

// S3-04: SLH-DSA signing is excluded — `sign` rejects "slh-dsa-sha2-128s".
#[napi]
pub fn sign(
    algorithm: String,
    private_key: Buffer,
    message: Buffer,
) -> Result<AsyncTask<SignTask>> {
    let alg = parse_signature_algorithm(&algorithm)?;
    if matches!(alg, PqAlgorithm::SlhDsaSha2_128s) {
        return Err(napi::Error::new(
            napi::Status::GenericFailure,
            "SLH-DSA signing is not available in the server addon (ADR 0005); use pqctl for offline signing",
        ));
    }
    Ok(AsyncTask::new(SignTask {
        algorithm: alg,
        private_key: private_key.to_vec(),
        message: message.to_vec(),
    }))
}

#[napi]
pub fn verify(
    algorithm: String,
    public_key: Buffer,
    message: Buffer,
    signature: Buffer,
) -> Result<AsyncTask<VerifyTask>> {
    let alg = parse_signature_algorithm(&algorithm)?;
    Ok(AsyncTask::new(VerifyTask {
        algorithm: alg,
        public_key: public_key.to_vec(),
        message: message.to_vec(),
        signature: signature.to_vec(),
    }))
}

#[napi]
pub fn signature_metadata(algorithm: String) -> Result<NapiSignatureMetadata> {
    let alg = parse_signature_algorithm(&algorithm)?;
    let row = pq::signature_metadata(alg).map_err(to_napi_error)?;
    Ok(NapiSignatureMetadata {
        algorithm: row.identifier.to_string(),
        public_key_bytes: row.public_key_bytes as u32,
        private_key_bytes: row.private_key_bytes as u32,
        signature_bytes: row.signature_bytes.unwrap_or(0) as u32,
    })
}

// ---------------------------------------------------------------------------
// KEM API
// ---------------------------------------------------------------------------

#[napi]
pub fn kem_keygen(algorithm: String) -> Result<AsyncTask<KemKeygenTask>> {
    let alg = parse_kem_algorithm(&algorithm)?;
    Ok(AsyncTask::new(KemKeygenTask { algorithm: alg }))
}

#[napi]
pub fn encapsulate(
    algorithm: String,
    public_key: Buffer,
) -> Result<AsyncTask<EncapsulateTask>> {
    let alg = parse_kem_algorithm(&algorithm)?;
    Ok(AsyncTask::new(EncapsulateTask {
        algorithm: alg,
        public_key: public_key.to_vec(),
    }))
}

#[napi]
pub fn decapsulate(
    algorithm: String,
    private_key: Buffer,
    ciphertext: Buffer,
) -> Result<AsyncTask<DecapsulateTask>> {
    let alg = parse_kem_algorithm(&algorithm)?;
    Ok(AsyncTask::new(DecapsulateTask {
        algorithm: alg,
        private_key: private_key.to_vec(),
        ciphertext: ciphertext.to_vec(),
    }))
}

#[napi]
pub fn kem_metadata(algorithm: String) -> Result<NapiKemMetadata> {
    let alg = parse_kem_algorithm(&algorithm)?;
    let row = pq::kem_metadata(alg).map_err(to_napi_error)?;
    Ok(NapiKemMetadata {
        algorithm: row.identifier.to_string(),
        public_key_bytes: row.public_key_bytes as u32,
        private_key_bytes: row.private_key_bytes as u32,
        ciphertext_bytes: row.ciphertext_bytes.unwrap_or(0) as u32,
        shared_secret_bytes: row.shared_secret_bytes.unwrap_or(0) as u32,
    })
}
