//! Offline SLH-DSA root ceremony tool.
//!
//! Runs air-gapped. Never linked into any service binary.
//!
//! Usage:
//!   pqctl keygen --out <dir>
//!   pqctl sign   --key <private-key-file> --message <file> --out <sig-file>
//!   pqctl verify --key <public-key-file>  --message <file> --sig <sig-file>

use rwa_vault_pq_core::{self as core, PqAlgorithm, PqError};
use std::{fs, path::PathBuf, process};

const ALGORITHM: PqAlgorithm = PqAlgorithm::SlhDsaSha2_128s;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        usage();
    }

    let result = match args[1].as_str() {
        "keygen" => cmd_keygen(&args[2..]),
        "sign" => cmd_sign(&args[2..]),
        "verify" => cmd_verify(&args[2..]),
        _ => {
            usage();
        }
    };

    if let Err(error) = result {
        eprintln!("pqctl: {error}");
        process::exit(1);
    }
}

fn usage() -> ! {
    eprintln!("usage: pqctl <keygen|sign|verify> [options]");
    eprintln!();
    eprintln!("  keygen --out <dir>         Generate an SLH-DSA-SHA2-128s key pair");
    eprintln!("  sign   --key <sk> --message <file> --out <sig>  Sign a file");
    eprintln!("  verify --key <pk> --message <file> --sig <sig>  Verify a file");
    process::exit(2);
}

fn require_arg<'a>(args: &'a [String], flag: &str) -> Result<&'a str, String> {
    args.iter()
        .position(|a| a == flag)
        .and_then(|i| args.get(i + 1))
        .map(|s| s.as_str())
        .ok_or_else(|| format!("missing required argument: {flag}"))
}

fn cmd_keygen(args: &[String]) -> Result<(), String> {
    let out_dir = PathBuf::from(require_arg(args, "--out")?);
    fs::create_dir_all(&out_dir).map_err(|e| format!("cannot create output directory: {e}"))?;

    let pair = core::keygen(ALGORITHM).map_err(format_pq)?;

    let pk_path = out_dir.join("slh-dsa-sha2-128s.pub");
    let sk_path = out_dir.join("slh-dsa-sha2-128s.key");

    fs::write(&pk_path, pair.public_key().as_bytes())
        .map_err(|e| format!("cannot write public key: {e}"))?;
    fs::write(&sk_path, pair.private_key().as_bytes())
        .map_err(|e| format!("cannot write private key: {e}"))?;

    eprintln!("public key:  {}", pk_path.display());
    eprintln!("private key: {}", sk_path.display());
    eprintln!("algorithm:   slh-dsa-sha2-128s (FIPS 205)");
    Ok(())
}

fn cmd_sign(args: &[String]) -> Result<(), String> {
    let key_path = PathBuf::from(require_arg(args, "--key")?);
    let msg_path = PathBuf::from(require_arg(args, "--message")?);
    let out_path = PathBuf::from(require_arg(args, "--out")?);

    let sk_bytes = fs::read(&key_path).map_err(|e| format!("cannot read key: {e}"))?;
    let message = fs::read(&msg_path).map_err(|e| format!("cannot read message: {e}"))?;

    let sk = core::PrivateKey::new(sk_bytes);
    let signature = core::sign(ALGORITHM, &sk, &message).map_err(format_pq)?;

    fs::write(&out_path, signature.as_bytes())
        .map_err(|e| format!("cannot write signature: {e}"))?;

    eprintln!("signature:   {} ({} bytes)", out_path.display(), signature.len());
    Ok(())
}

fn cmd_verify(args: &[String]) -> Result<(), String> {
    let key_path = PathBuf::from(require_arg(args, "--key")?);
    let msg_path = PathBuf::from(require_arg(args, "--message")?);
    let sig_path = PathBuf::from(require_arg(args, "--sig")?);

    let pk_bytes = fs::read(&key_path).map_err(|e| format!("cannot read key: {e}"))?;
    let message = fs::read(&msg_path).map_err(|e| format!("cannot read message: {e}"))?;
    let sig_bytes = fs::read(&sig_path).map_err(|e| format!("cannot read signature: {e}"))?;

    let pk = core::PublicKey::new(pk_bytes);
    let sig = core::Signature::new(sig_bytes);

    let valid = core::verify(ALGORITHM, &pk, &message, &sig).map_err(format_pq)?;

    if valid {
        eprintln!("verification: PASS");
        Ok(())
    } else {
        Err("verification: FAIL — signature is not valid for this key and message".into())
    }
}

fn format_pq(error: PqError) -> String {
    format!("{} ({})", error, error.code())
}
