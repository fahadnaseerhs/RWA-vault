//! Binary-file fixture used by the native/browser Stage 1 equivalence test.

use rwa_vault_pq_core::{falcon_keygen, falcon_sign, falcon_verify, PublicKey, Signature};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const MESSAGE: &[u8] = b"RWA-Vault Stage 1 native/WASM Falcon equivalence";

fn write(path: &Path, bytes: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
    fs::write(path, bytes)?;
    Ok(())
}

fn emit(directory: &Path) -> Result<(), Box<dyn std::error::Error>> {
    fs::create_dir_all(directory)?;
    let key_pair = falcon_keygen()?;
    let signature = falcon_sign(key_pair.private_key(), MESSAGE)?;

    write(&directory.join("message.bin"), MESSAGE)?;
    write(
        &directory.join("native-public.bin"),
        key_pair.public_key().as_bytes(),
    )?;
    write(
        &directory.join("native-signature.bin"),
        signature.as_bytes(),
    )?;
    Ok(())
}

fn verify(directory: &Path) -> Result<(), Box<dyn std::error::Error>> {
    let message = fs::read(directory.join("message.bin"))?;
    let public_key = PublicKey::new(fs::read(directory.join("wasm-public.bin"))?);
    let signature = Signature::new(fs::read(directory.join("wasm-signature.bin"))?);

    if !falcon_verify(&public_key, &message, &signature)? {
        return Err("native verification rejected the WASM signature".into());
    }

    println!("native verified the WASM-generated Falcon signature");
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut arguments = env::args_os().skip(1);
    let operation = arguments
        .next()
        .and_then(|value| value.into_string().ok())
        .ok_or("usage: falcon_interop <emit|verify> <artifact-directory>")?;
    let directory = PathBuf::from(
        arguments
            .next()
            .ok_or("usage: falcon_interop <emit|verify> <artifact-directory>")?,
    );
    if arguments.next().is_some() {
        return Err("usage: falcon_interop <emit|verify> <artifact-directory>".into());
    }

    match operation.as_str() {
        "emit" => emit(&directory),
        "verify" => verify(&directory),
        _ => Err("operation must be `emit` or `verify`".into()),
    }
}
