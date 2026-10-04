//! Human-readable walkthrough of all six primitives: keygen, sign/verify and
//! tamper checks for the signature schemes, encapsulate/decapsulate for the KEMs.
//!
//! Keys shown here are throwaway demo keys generated on every run.

use rwa_vault_pq_core::{
    decapsulate, encapsulate, kem_keygen, keygen, metadata, sign, verify, Ciphertext, PqAlgorithm,
    Signature,
};
use std::fmt::Write;
use std::time::Instant;

const MESSAGE: &[u8] = b"Approve loan #42: 10,000 against token RWA-001";
const TAMPERED: &[u8] = b"Approve loan #42: 99,000 against token RWA-001";

fn preview(bytes: &[u8]) -> String {
    let mut head = String::new();
    for byte in bytes.iter().take(16) {
        let _ = write!(head, "{byte:02x}");
    }
    format!("{head}...  ({} bytes)", bytes.len())
}

fn tick(ok: bool) -> &'static str {
    if ok {
        "PASS"
    } else {
        "FAIL"
    }
}

fn signature_demo(algorithm: PqAlgorithm) -> Result<bool, Box<dyn std::error::Error>> {
    println!("\n=== {} (signature) ===", metadata(algorithm).identifier);

    let started = Instant::now();
    let keys = keygen(algorithm)?;
    println!("1. Key generated in {:?}", started.elapsed());
    println!("   public key : {}", preview(keys.public_key().as_bytes()));
    println!("   private key: {}", preview(keys.private_key().as_bytes()));

    let started = Instant::now();
    let signature = sign(algorithm, keys.private_key(), MESSAGE)?;
    println!("2. Message signed in {:?}", started.elapsed());
    println!("   message    : {}", String::from_utf8_lossy(MESSAGE));
    println!("   signature  : {}", preview(signature.as_bytes()));

    let genuine = verify(algorithm, keys.public_key(), MESSAGE, &signature)?;
    println!(
        "3. [{}] Original message verifies        -> {genuine}",
        tick(genuine)
    );

    let changed_message = verify(algorithm, keys.public_key(), TAMPERED, &signature)?;
    println!(
        "4. [{}] Changed message is rejected      -> {changed_message}",
        tick(!changed_message)
    );

    let mut flipped = signature.as_bytes().to_vec();
    flipped[10] ^= 0x01;
    let flipped = Signature::new(flipped);
    let flipped_ok = verify(algorithm, keys.public_key(), MESSAGE, &flipped)?;
    println!(
        "5. [{}] 1-bit-damaged signature rejected -> {flipped_ok}",
        tick(!flipped_ok)
    );

    let stranger = keygen(algorithm)?;
    let wrong_key = verify(algorithm, stranger.public_key(), MESSAGE, &signature)?;
    println!(
        "6. [{}] Someone else's key rejected      -> {wrong_key}",
        tick(!wrong_key)
    );

    Ok(genuine && !changed_message && !flipped_ok && !wrong_key)
}

fn kem_demo(algorithm: PqAlgorithm) -> Result<bool, Box<dyn std::error::Error>> {
    println!(
        "\n=== {} (encryption key exchange) ===",
        metadata(algorithm).identifier
    );

    let started = Instant::now();
    let keys = kem_keygen(algorithm)?;
    println!("1. Receiver's key generated in {:?}", started.elapsed());
    println!("   public key : {}", preview(keys.public_key().as_bytes()));
    println!("   private key: {}", preview(keys.private_key().as_bytes()));

    let sent = encapsulate(algorithm, keys.public_key())?;
    println!("2. Sender locks a fresh secret with the public key");
    println!("   sealed box : {}", preview(sent.ciphertext().as_bytes()));
    println!(
        "   secret     : {}",
        preview(sent.shared_secret().as_bytes())
    );

    let received = decapsulate(algorithm, keys.private_key(), sent.ciphertext())?;
    println!("3. Receiver opens it with the private key");
    println!("   secret     : {}", preview(received.as_bytes()));
    let same = received.as_bytes() == sent.shared_secret().as_bytes();
    println!(
        "   [{}] Both sides now hold the same secret -> {same}",
        tick(same)
    );

    let mut damaged = sent.ciphertext().as_bytes().to_vec();
    damaged[10] ^= 0x01;
    let garbage = decapsulate(algorithm, keys.private_key(), &Ciphertext::new(damaged))?;
    let differs = garbage.as_bytes() != sent.shared_secret().as_bytes();
    println!(
        "4. [{}] Damaged sealed box gives a useless secret -> {differs}",
        tick(differs)
    );

    let stranger = kem_keygen(algorithm)?;
    let intercepted = decapsulate(algorithm, stranger.private_key(), sent.ciphertext())?;
    let locked_out = intercepted.as_bytes() != sent.shared_secret().as_bytes();
    println!(
        "5. [{}] Someone else's key cannot open it       -> {locked_out}",
        tick(locked_out)
    );

    Ok(same && differs && locked_out)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut all_passed = true;
    for algorithm in [
        PqAlgorithm::Falcon512,
        PqAlgorithm::MlDsa44,
        PqAlgorithm::MlDsa65,
        PqAlgorithm::SlhDsaSha2_128s,
    ] {
        all_passed &= signature_demo(algorithm)?;
    }
    for algorithm in [PqAlgorithm::MlKem768, PqAlgorithm::MlKem1024] {
        all_passed &= kem_demo(algorithm)?;
    }

    println!();
    if all_passed {
        println!("ALL 6 ALGORITHMS PASSED EVERY CHECK");
        Ok(())
    } else {
        Err("at least one check failed".into())
    }
}
