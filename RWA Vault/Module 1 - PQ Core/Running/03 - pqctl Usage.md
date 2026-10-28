---
tags: [rwa-vault, m1, running]
---
# pqctl Usage

`pqctl` is the offline CLI for SLH-DSA-SHA2-128s root-ceremony operations. It is a standalone binary that is **never** linked into services or compiled to WASM. Its only purpose is to generate keys and sign files on a secure, offline machine.

## Build it first

```bash
cargo build --release --manifest-path packages/pq-core/native/pqctl/Cargo.toml
```

The binary is at:
- Linux/macOS: `target/release/rwa-vault-pq-core-pqctl`
- Windows: `target/release/rwa-vault-pq-core-pqctl.exe`

For convenience in the examples below, we'll call it `pqctl`.

---

## Command 1: Generate a key pair

```bash
pqctl keygen --out-dir ./ceremony
```

**What it does:** Generates an SLH-DSA-SHA2-128s key pair and writes two files:
- `ceremony/slh-dsa-sha2-128s.pub` — the public key (32 bytes)
- `ceremony/slh-dsa-sha2-128s.key` — the private key (64 bytes)

**Expected output:**
```
Generated SLH-DSA-SHA2-128s key pair
  Public key:  ceremony/slh-dsa-sha2-128s.pub (32 bytes)
  Private key: ceremony/slh-dsa-sha2-128s.key (64 bytes)
```

**What it means practically:** You now have a post-quantum root key pair. The public key is tiny (32 bytes) — that's one of SLH-DSA's advantages. The private key (64 bytes) must be kept secret and ideally stored on an air-gapped machine or hardware security module.

**Time:** Near-instant (key generation for SLH-DSA is fast; it's the signing that's slow).

---

## Command 2: Sign a file

```bash
pqctl sign --key ceremony/slh-dsa-sha2-128s.key --message document.bin --out ceremony/document.sig
```

**What it does:** Reads the private key and the message file, produces an SLH-DSA-SHA2-128s signature, and writes it to the output file.

**Expected output:**
```
Signed document.bin with SLH-DSA-SHA2-128s
  Signature: ceremony/document.sig (7856 bytes)
```

**What it means practically:** The 7,856-byte signature proves that the holder of the private key approved `document.bin`. This signature can be verified by anyone who has the 32-byte public key — on a server, in a browser, or on-chain.

**Time:** ~200 ms. This is why SLH-DSA signing is offline-only — 200 ms is too slow for a server handling hundreds of requests per second, but perfectly fine for a ceremony that happens once.

---

## Command 3: Verify a signature

```bash
pqctl verify --key ceremony/slh-dsa-sha2-128s.pub --message document.bin --signature ceremony/document.sig
```

**What it does:** Reads the public key, message, and signature, then verifies the signature.

**Expected output (valid):**
```
PASS — signature is valid
```

**Expected output (invalid — e.g. message was modified):**
```
FAIL — signature verification failed
```

**What it means practically:** `PASS` confirms that:
1. The message has not been modified since signing
2. The signature was produced by the holder of the corresponding private key
3. The algorithm is SLH-DSA-SHA2-128s, which is quantum-safe

---

## Full ceremony example

This simulates a root-key ceremony — the kind of operation done once, on an air-gapped machine, to establish the root of trust for the entire PKI.

```bash
# 1. Create a ceremony directory
mkdir ceremony

# 2. Generate the root key pair
pqctl keygen --out-dir ./ceremony

# 3. Create a message to sign (e.g. a root certificate payload)
echo "RWA-Vault Root Certificate v1" > ceremony/root-cert.txt

# 4. Sign it
pqctl sign \
  --key ceremony/slh-dsa-sha2-128s.key \
  --message ceremony/root-cert.txt \
  --out ceremony/root-cert.sig

# 5. Verify (sanity check before the private key is locked away)
pqctl verify \
  --key ceremony/slh-dsa-sha2-128s.pub \
  --message ceremony/root-cert.txt \
  --signature ceremony/root-cert.sig
# → PASS

# 6. Tamper with the message and verify again
echo "TAMPERED" > ceremony/root-cert.txt
pqctl verify \
  --key ceremony/slh-dsa-sha2-128s.pub \
  --message ceremony/root-cert.txt \
  --signature ceremony/root-cert.sig
# → FAIL
```

**What this demonstrates:** The signature is bound to the exact message content. Even a single byte change causes verification to fail. This is the integrity guarantee that underpins the entire PKI.

---

## Why SLH-DSA for the root ceremony?

| Property | Why it matters for a root key |
|----------|------------------------------|
| **Hash-based security** | Even if lattice cryptography is broken, SLH-DSA is still safe — it relies only on SHA-256 |
| **Tiny public key (32 bytes)** | Easy to distribute, embed in firmware, print on paper as a backup |
| **Slow signing (~200 ms)** | Acceptable — root ceremonies happen once, not at request-time |
| **Large signature (7,856 bytes)** | Acceptable — root signatures are stored, not sent per-request |
| **Stateless** | Unlike XMSS/LMS (other hash-based schemes), SLH-DSA doesn't require tracking how many signatures have been produced. You can't accidentally reuse state. |

---

Prev: [[02 - Test Commands]] · Up: [[Module 1 - PQ Core]]
