//! Differential oracle: the same upstream PQClean, packaged independently.
//!
//! Two modes, which together give a two-way check against our vendored build:
//!
//!   generate            emit vectors produced by this build, on stdout
//!   verify <file>       consume vectors produced by the native crate and
//!                       check them with this build; exit non-zero on any
//!                       disagreement
//!
//! Record format is one line per vector, no dependencies needed to parse it:
//!
//!   <scheme>|key=hex|key=hex|...
//!
//! Signature schemes carry `pk`, `msg`, `sig`. KEMs carry `pk`, `sk`, `ct`, `ss`
//! — the shared secret is what both sides must agree on.

use std::io::Read;
use std::process::ExitCode;

use pqcrypto_traits::kem::{Ciphertext as _, PublicKey as _, SecretKey as _, SharedSecret as _};
use pqcrypto_traits::sign::{DetachedSignature as _, PublicKey as _};

const MESSAGE: &[u8] = b"RWA-Vault differential oracle vector";

fn to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

fn from_hex(text: &str) -> Result<Vec<u8>, String> {
    if text.len() % 2 != 0 {
        return Err(format!("odd-length hex field ({} chars)", text.len()));
    }
    (0..text.len())
        .step_by(2)
        .map(|i| {
            u8::from_str_radix(&text[i..i + 2], 16)
                .map_err(|_| format!("bad hex at byte {}", i / 2))
        })
        .collect()
}

/// One vector: a scheme tag and its named hex fields.
struct Record {
    scheme: String,
    fields: Vec<(String, Vec<u8>)>,
}

impl Record {
    fn parse(line: &str) -> Result<Self, String> {
        let mut parts = line.split('|');
        let scheme = parts.next().ok_or("empty record")?.trim().to_string();
        if scheme.is_empty() {
            return Err("record has no scheme tag".into());
        }
        let mut fields = Vec::new();
        for part in parts {
            let (name, value) = part
                .split_once('=')
                .ok_or_else(|| format!("field is not name=value: {part}"))?;
            fields.push((name.trim().to_string(), from_hex(value.trim())?));
        }
        Ok(Record { scheme, fields })
    }

    fn get(&self, name: &str) -> Result<&[u8], String> {
        self.fields
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.as_slice())
            .ok_or_else(|| format!("{} record is missing field `{name}`", self.scheme))
    }
}

fn render(scheme: &str, fields: &[(&str, &[u8])]) -> String {
    let mut line = String::from(scheme);
    for (name, value) in fields {
        line.push('|');
        line.push_str(name);
        line.push('=');
        line.push_str(&to_hex(value));
    }
    line
}

/// Emit one signature and one KEM vector per scheme.
macro_rules! generate_sign {
    ($out:expr, $tag:literal, $module:path) => {{
        use $module as scheme;
        let (pk, sk) = scheme::keypair();
        let sig = scheme::detached_sign(MESSAGE, &sk);
        $out.push(render(
            $tag,
            &[
                ("pk", pk.as_bytes()),
                ("msg", MESSAGE),
                ("sig", sig.as_bytes()),
            ],
        ));
    }};
}

macro_rules! generate_kem {
    ($out:expr, $tag:literal, $module:path) => {{
        use $module as scheme;
        let (pk, sk) = scheme::keypair();
        let (ss, ct) = scheme::encapsulate(&pk);
        $out.push(render(
            $tag,
            &[
                ("pk", pk.as_bytes()),
                ("sk", sk.as_bytes()),
                ("ct", ct.as_bytes()),
                ("ss", ss.as_bytes()),
            ],
        ));
    }};
}

fn generate() -> Vec<String> {
    let mut out = Vec::new();
    generate_sign!(out, "falcon-padded-512", pqcrypto_falcon::falconpadded512);
    generate_sign!(out, "ml-dsa-44", pqcrypto_mldsa::mldsa44);
    generate_sign!(out, "ml-dsa-65", pqcrypto_mldsa::mldsa65);
    generate_kem!(out, "ml-kem-768", pqcrypto_mlkem::mlkem768);
    generate_kem!(out, "ml-kem-1024", pqcrypto_mlkem::mlkem1024);
    out
}

macro_rules! verify_sign {
    ($record:expr, $module:path) => {{
        use $module as scheme;
        let pk = scheme::PublicKey::from_bytes($record.get("pk")?)
            .map_err(|error| format!("public key rejected by the oracle: {error}"))?;
        let sig = scheme::DetachedSignature::from_bytes($record.get("sig")?)
            .map_err(|error| format!("signature rejected by the oracle: {error}"))?;
        scheme::verify_detached_signature(&sig, $record.get("msg")?, &pk)
            .map_err(|error| format!("signature did not verify under the oracle: {error}"))?;
    }};
}

macro_rules! verify_kem {
    ($record:expr, $module:path) => {{
        use $module as scheme;
        let sk = scheme::SecretKey::from_bytes($record.get("sk")?)
            .map_err(|error| format!("secret key rejected by the oracle: {error}"))?;
        let ct = scheme::Ciphertext::from_bytes($record.get("ct")?)
            .map_err(|error| format!("ciphertext rejected by the oracle: {error}"))?;
        let ss = scheme::decapsulate(&ct, &sk);
        if ss.as_bytes() != $record.get("ss")? {
            return Err("shared secret disagrees with the oracle's decapsulation".into());
        }
    }};
}

fn verify_record(record: &Record) -> Result<(), String> {
    match record.scheme.as_str() {
        "falcon-padded-512" => verify_sign!(record, pqcrypto_falcon::falconpadded512),
        "ml-dsa-44" => verify_sign!(record, pqcrypto_mldsa::mldsa44),
        "ml-dsa-65" => verify_sign!(record, pqcrypto_mldsa::mldsa65),
        "ml-kem-768" => verify_kem!(record, pqcrypto_mlkem::mlkem768),
        "ml-kem-1024" => verify_kem!(record, pqcrypto_mlkem::mlkem1024),
        other => return Err(format!("unknown scheme tag: {other}")),
    }
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("generate") => {
            println!("# Differential oracle vectors from independently packaged PQClean.");
            println!("# Regenerate with: cargo run --manifest-path oracle/Cargo.toml -- generate");
            for line in generate() {
                println!("{line}");
            }
            ExitCode::SUCCESS
        }
        Some("verify") => {
            let mut text = String::new();
            let source = args.get(1).map(String::as_str);
            let read = match source {
                Some("-") | None => std::io::stdin().read_to_string(&mut text).map(|_| ()),
                Some(path) => std::fs::read_to_string(path).map(|content| text = content),
            };
            if let Err(error) = read {
                eprintln!("pq-oracle: cannot read vectors: {error}");
                return ExitCode::FAILURE;
            }

            let mut checked = 0usize;
            let mut failures = Vec::new();
            for (number, line) in text.lines().enumerate() {
                let line = line.trim();
                if line.is_empty() || line.starts_with('#') {
                    continue;
                }
                match Record::parse(line)
                    .and_then(|record| verify_record(&record).map(|()| record.scheme.clone()))
                {
                    Ok(scheme) => {
                        checked += 1;
                        println!("ok   {scheme}");
                    }
                    Err(error) => {
                        failures.push(format!("line {}: {error}", number + 1));
                    }
                }
            }

            if checked == 0 && failures.is_empty() {
                eprintln!("pq-oracle: no vectors found");
                return ExitCode::FAILURE;
            }
            for failure in &failures {
                eprintln!("FAIL {failure}");
            }
            if failures.is_empty() {
                println!("pq-oracle: {checked} vectors agree with the independent build");
                ExitCode::SUCCESS
            } else {
                ExitCode::FAILURE
            }
        }
        _ => {
            eprintln!("usage: pq-oracle generate | pq-oracle verify <file|->");
            ExitCode::FAILURE
        }
    }
}
