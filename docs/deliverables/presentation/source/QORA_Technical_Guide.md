# QORA Defense: Technical Guide

Everything you need to explain QORA's methodology and defend it under questioning: the terms, how each module works, and the answers to the questions most likely to come.

## Glossary

One line per term: what it is, then where it shows up in QORA. Learn the bold names; the panel will use them.

### Assets and finance

| Term                               | What it is                                                                                          | In QORA                                                             |
| ---------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **RWA (Real-World Asset)**         | A physical or traditional financial asset: gold, a treasury bill, a bond, property                  | The four asset classes: gold, T-bills, Sukuk, property shares       |
| **Tokenization**                   | Representing ownership of an asset as digital tokens on a blockchain, e.g. 1 token = 1 gram of gold | Every asset is split into small units a user can buy from PKR 1,000 |
| **Custodian**                      | The licensed institution that physically holds the real asset                                       | Signs reserve reports with ML-DSA-65 (M3)                           |
| **Proof-of-reserve / attestation** | The custodian's signed statement of how much asset it holds                                         | An asset goes LIVE only if reserve ≥ tokens issued                  |
| **T-bill (treasury bill)**         | Short-term government debt, repaid at face value                                                    | One of the target asset classes; the govt MoU covers T-bills        |
| **Sukuk**                          | A Shariah-compliant bond: holders own a share of an asset rather than an interest-bearing loan      | Target asset class; Shariah review is in the way forward            |
| **REIT / property shares**         | A fund that owns property, split into shares                                                        | The "real estate" token                                             |
| **Stablecoin / USDC**              | A token pegged 1:1 to the US dollar; USDC is issued by Circle                                       | The unit of account; test-net USDC in the sandbox                   |
| **Remittance**                     | Money sent home by workers abroad                                                                   | $41.6B into Pakistan in FY26: the PKR–USD flow our rail serves      |
| **KYC (Know Your Customer)**       | Identity verification a bank performs: CNIC, photo, address                                         | Only KYC-verified wallets can hold QORA tokens                      |
| **AML (Anti-Money Laundering)**    | Checks that funds are not from crime; usually done with KYC                                         | Part of the compliance layer                                        |
| **Qualified purchaser**            | A US investor category with ≥ $5M in investments                                                    | Why BUIDL excludes ordinary users                                   |
| **BUIDL**                          | BlackRock's tokenized US Treasury fund (~$2.8B, $5M minimum)                                        | Literature: institutional adoption, but no small investors          |
| **SBP / PVARA**                    | State Bank of Pakistan / Pakistan Virtual Assets Regulatory Authority                               | The regulatory path after the FYP                                   |
| **Raast**                          | Pakistan's instant payment system run by SBP                                                        | A future PKR rail behind IFiatRail                                  |

### Ethereum and token standards

| Term                            | What it is                                                                                                                                | In QORA                                                  |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Blockchain**                  | A shared, append-only ledger that many computers agree on; past entries cannot be edited                                                  | The permanent record of ownership and anchors            |
| **Smart contract**              | A program stored on the blockchain that runs exactly as written                                                                           | Registry, vault, lending pool, liquidator, anchor        |
| **EVM**                         | Ethereum Virtual Machine: the engine that runs smart contracts on Ethereum and compatible chains                                          | We stay EVM-compatible, unlike QRL                       |
| **EIP / ERC**                   | EIP = Ethereum Improvement Proposal (the draft); ERC = the adopted application standard and its number                                    | ERC-20, ERC-3643, ERC-4626                               |
| **ERC-20**                      | The basic token standard: anyone can send to anyone. Fine for currency, illegal for securities because it cannot enforce KYC              | USDC is an ERC-20; our asset tokens are not              |
| **ERC-3643 (T-REX)**            | A permissioned token: every transfer checks an identity registry and compliance rules inside the token, so a non-KYC receiver is rejected | Our asset tokens (M3)                                    |
| **ONCHAINID**                   | The on-chain identity contract that holds a user's verified KYC claim                                                                     | Paired with ERC-3643                                     |
| **ERC-4626**                    | The standard vault: many investors deposit an asset and receive proportional shares, like mutual-fund units                               | Our vault (M4). If you hear "4023" or "4626", it is this |
| **Inflation (donation) attack** | An attacker manipulates a nearly empty vault so a later small deposit rounds down to zero shares                                          | The exact risk at PKR 1,000 scale                        |
| **Virtual offset**              | Phantom shares (σ = 10⁶) added to the share formula so the vault behaves as if already seeded                                             | Raises the attack cost to ~10⁶ × the deposit             |
| **Gas**                         | Ethereum's fee unit for computation and storage                                                                                           | ECDSA check 3,000; our anchor ~43,000 per minute         |
| **ecrecover**                   | The built-in ECDSA signature check on Ethereum (3,000 gas)                                                                                | The cost baseline we beat                                |
| **Precompile**                  | A built-in, fast function in the EVM. There is one for ECDSA, none yet for PQC                                                            | EIP-8052 would add Falcon; we switch to it when it ships |
| **Layer 2 / rollup**            | A chain that processes transactions off Ethereum and posts compact commitments to it                                                      | Arbitrum is one                                          |
| **Arbitrum Sepolia**            | The test network of the Arbitrum rollup; tokens have no real value                                                                        | Our deployment target                                    |
| **Optimistic / fraud proof**    | Results are assumed correct unless someone proves cheating; only then the expensive check runs                                            | Our dispute path                                         |

### Lending and risk

| Term                          | What it is                                                                          | In QORA                                   |
| ----------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------- |
| **DeFi**                      | Decentralized finance: lending and trading run by smart contracts instead of a bank | Aave, Compound, MakerDAO                  |
| **Collateral**                | An asset locked to secure a loan, like pawning gold                                 | Vault shares are the collateral           |
| **Over-collateralized**       | You lock more value than you borrow                                                 | Gold: borrow up to 60% of value           |
| **LTV (loan-to-value, θ)**    | Maximum debt as a share of collateral value                                         | Gold 60%, T-bill 75%, Sukuk 65%, REIT 40% |
| **Liquidation threshold (λ)** | The weighting used in the health factor; above LTV to leave a safety gap            | Gold 75%                                  |
| **Health factor (HF)**        | Collateral value × λ ÷ debt. Below 1 means unsafe                                   | Bands at 1.15, 1.00, 0.95, 0.90           |
| **Liquidation**               | Automatic sale of a borrower's collateral to repay the loan                         | Only below HF 0.95                        |
| **Close factor**              | The maximum share of debt repaid in one liquidation                                 | 50%                                       |
| **Liquidation bonus**         | The discount a liquidator earns, paid from the borrower's collateral                | Decays from 5% to 3% over 20 blocks       |
| **Reserve buffer**            | Our fund that covers a brief, shallow dip for up to 6 h before any liquidation      | Cap: 40% per epoch; funded from interest  |
| **Bad debt**                  | A loan the collateral can no longer cover                                           | Socialised only below HF 0.90             |
| **Utilisation (U)**           | Borrowed ÷ total liquidity in the pool                                              | Interest kink at 80%                      |
| **Borrow index**              | One global number that grows with interest; each debt = scaled balance × index      | 10,000 loans cost the same gas as one     |
| **Oracle**                    | The service that brings off-chain prices onto the chain                             | M5, five sources                          |
| **Quorum**                    | The minimum number of live sources needed to publish a price                        | 3 of 5                                    |
| **Median**                    | The middle value; one or two bad sources cannot move it                             | Like a median filter                      |
| **TWAP**                      | Time-weighted average price over a window                                           | 30 min; reject moves over 10%             |
| **Heartbeat**                 | Maximum price age before borrowing freezes                                          | Gold 60 s                                 |
| **Price wick**                | A sudden, very short price dip that recovers                                        | What the buffer absorbs                   |

### Cryptography

| Term                                 | What it is                                                                                       | In QORA                                                        |
| ------------------------------------ | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| **Digital signature**                | Proof that the holder of a private key approved a message                                        | Every action is signed                                         |
| **ECDSA**                            | The elliptic-curve signature used by Bitcoin, Ethereum and all current RWA platforms             | What quantum computers will break                              |
| **Shor's algorithm**                 | A quantum algorithm (1994) that recovers a private key from a public key                         | The threat to ECDSA                                            |
| **Qubit (logical / physical)**       | A quantum bit. Physical = raw hardware; logical = error-corrected, built from many physical      | ECC-256: < 1,200 logical qubits (Google, 2026)                 |
| **CRQC**                             | Cryptographically relevant quantum computer: one big enough to break real encryption             | 28–49% chance within 10 years (GRI)                            |
| **Harvest-now, forge-later**         | Store signed records today; forge them once a CRQC exists                                        | Why 30-year records are at risk now                            |
| **Mosca's theorem**                  | If data lifetime + migration time > time to CRQC, you are already late                           | Our urgency argument                                           |
| **PQC**                              | Post-quantum cryptography: algorithms that run on normal computers but resist quantum attack     | The whole security layer                                       |
| **NIST / FIPS**                      | US standards body / its official standards documents                                             | FIPS 203, 204, 205 (Aug 2024); 206 in draft                    |
| **ML-KEM (FIPS 203)**                | Lattice-based key exchange and encryption (was Kyber)                                            | Encrypting KYC documents                                       |
| **ML-DSA (FIPS 204)**                | Lattice-based signatures (was Dilithium); integer-only                                           | Custodian, oracle, admin keys                                  |
| **SLH-DSA (FIPS 205)**               | Hash-based signatures (was SPHINCS+); slow and large but different maths                         | Offline root key                                               |
| **Falcon / FN-DSA (FIPS 206 draft)** | Lattice signatures with the smallest size (~666 B); uses floating point                          | User signatures, in the browser                                |
| **Side-channel**                     | Leaking a key through timing or power use rather than breaking the maths                         | Why Falcon never signs on shared servers                       |
| **Hash / Keccak-256**                | A fixed 32-byte fingerprint; changing one bit changes it completely, like a CRC                  | Leaf = Keccak-256(envelope)                                    |
| **Merkle tree / root**               | Hash pairs repeatedly until one root covers every record; proving one record needs log₂ n hashes | One root per 60 s; 12 hashes for 4,096 actions                 |
| **Anchoring**                        | Writing a Merkle root on-chain as permanent proof of a batch                                     | M9, ~43k gas                                                   |
| **Epoch**                            | One batching window                                                                              | 60 seconds                                                     |
| **Envelope**                         | Our fixed signed structure around every action                                                   | 10 fields, 7 checks                                            |
| **Nonce**                            | A one-time counter that stops a request being replayed                                           | Must equal last + 1                                            |
| **Key revocation / rotation**        | Retiring a key / replacing it with a new one                                                     | Revocation closes a validity window; old signatures stay valid |

### Engineering and tools

| Term                         | What it is                                                              | In QORA                                    |
| ---------------------------- | ----------------------------------------------------------------------- | ------------------------------------------ |
| **PQClean**                  | Clean, tested reference C code of the NIST PQC algorithms               | M1's source; no home-made crypto           |
| **Rust / napi-rs**           | Systems language / the bridge that turns Rust into a Node.js addon      | Server-side PQC                            |
| **WebAssembly (WASM)**       | Compiled code that runs in a browser at near-native speed               | Signing on the user's device               |
| **NIST test vectors (CAVP)** | Official input/output pairs to prove an implementation is correct       | Run on native and browser builds           |
| **Foundry**                  | Solidity build and test toolkit; fuzzing and invariants; gas snapshots  | Contract tests and gas measurement         |
| **Fuzzing / invariant test** | Thousands of random inputs checking a rule that must always hold        | e.g. tokens ≤ reserve                      |
| **Halmos**                   | Symbolic execution: proves a property for all inputs, not samples       | Vault rounding                             |
| **Redis Streams**            | A fast message queue                                                    | Batching epochs, risk sweeps               |
| **Double-entry ledger**      | Every money movement recorded as a matched debit and credit             | M8 settlement rail                         |
| **PWA / IndexedDB**          | A web app that installs like a phone app / the browser's local database | The client app; where the Falcon key lives |
| **Control build**            | The same system with ECDSA instead of PQC, switched by one compile flag | Every result is compared against it        |

## Methodology, slide by slide

QORA's whole method rests on one rule: **the chain holds authority, everything else holds work**. Expensive post-quantum verification happens off-chain; the chain stores only a 32-byte commitment and re-checks its own rules. Each subsection matches a methodology slide in the deck.

<<DIAGRAM>>

Steps 1, 2, 4 and 6 run on the device or backend; only Execute, Anchor and the rare Dispute touch the chain.

### 1 · The verification cycle (slides 18–24)

- **Envelope.** No signature is ever taken over raw data. Every action is wrapped in a fixed structure: version, algorithm, chainId, contract, action, signer, nonce, validFrom/validTo, payloadHash. Each field kills one attack: chainId and contract stop replay on another chain or contract; nonce stops resending; the time window (90 s for users, 1 h for custodian reports) stops delayed execution; payloadHash stops data being swapped after signing.
- **Seven checks** (one shared verifier routine): algorithm allowed for this action; signer's key active and not revoked; domain matches; clock inside the window; nonce = stored value + 1; signature valid over the envelope with its signature field zeroed; payload matches the hash. Failures are rejected _at a named check_, which is what the tests assert.
- **Execute.** The backend submits the contract call. It holds no authority: the contract re-checks every invariant, so a compromised backend can withhold actions but never move funds.
- **Leaf and anchor.** Leaf = Keccak-256(envelope). Every 60 s the batcher builds a sorted-pair Merkle tree (the format OpenZeppelin's audited MerkleProof uses) and writes {root, leafCount, epoch} to PQAnchor.sol, which is immutable.
- **Prove.** The user holds {leaf, sibling hashes, epoch}. Recomputing the root takes ⌈log₂ n⌉ hashes: 12 for 4,096 actions. Engineering analogy: a hierarchical checksum over a data block.
- **What the anchor proves and does not.** It proves the envelope existed and was accepted no later than that block, and cannot be altered or reordered. It does not prove the signature was valid (that is the dispute path) and does not prove completeness, which is why the user keeps their own signed copy.
- **Dispute.** A challenger submits one envelope plus its proof; the on-chain Falcon verifier (ZKNox ETHFALCON, ~1.5M gas) runs once, paid by the challenger. Like error detection on demand, the expensive check runs only on a flagged fault.

### 2 · The 43k gas argument (slide 25)

Per epoch of n events, with ECDSA cost G_ec = 3,000, anchor cost G_a ≈ 43,000, proof check G_p ≈ 22,000, Falcon on-chain G_fal ≈ 1.5M, and ρ = the fraction of events ever disputed:

```
g(n) = G_a / n  +  ρ · (G_p + G_fal)
```

With ρ = 0 (the normal case), anchoring beats ECDSA when G_a / n < G_ec, i.e. n > 43,000 / 3,000 ≈ 14.3. At n = 100 it is about 430 gas per event.

Be honest about one point: **43k is a budget, not a measurement**. It is 21,000 base transaction + ~20,000 for the new root storage + count, epoch and event log. If count and epoch need a second fresh storage slot, the figure rises; Experiment A measures the real number with Foundry gas snapshots, and the break-even moves with it. Arbitrum also adds a small L1 data fee.

### 3 · Leaf 1: Foundation (slides 27–30)

| Module                   | How it works                                                                                                                                                                                                                                                                                       | Why it holds                                                                                                                                                                         |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| M1 PQ Core               | PQClean (NIST reference C) wrapped in Rust; built as a Node.js addon (napi-rs) for servers and WebAssembly for browsers. Falcon-512 for users (~666 B signatures), ML-DSA-65 for custodians and admins, ML-DSA-44 for oracle rounds, SLH-DSA for the offline root, ML-KEM-1024/768 for encryption. | No home-made cryptography; NIST test vectors run on both builds. Falcon is signed only on user devices because its floating-point sampling is a side-channel risk on shared servers. |
| M2 PQ-PKI & Envelope     | Three-tier keys: Tier 0 SLH-DSA root (offline, air-gapped, hash-based so it survives a break in lattice maths), Tier 1 ML-DSA-65 service keys, Tier 2 Falcon device keys.                                                                                                                          | Revocation only closes a key's validity window, so signatures made before revocation stay verifiable for 30 years; anchoring provides the independent time reference.                |
| M3 Registry & Compliance | Asset state machine: UNREGISTERED → ATTESTATION RECEIVED → four checks (ML-DSA-65 signature, higher sequence number, reserve ≥ supply, fresh price) → LIVE → FROZEN. ERC-3643 tokens check the identity registry on every transfer.                                                                | Invariant: tokens issued ≤ physical reserve. If a custodian lies, the asset freezes; minting and transfers stop but withdrawals stay open.                                           |
| M4 Vault Accounting      | ERC-4626 vault with a virtual offset σ = 10⁶. Rounding always goes against the user making the operation.                                                                                                                                                                                          | Fuzzed over 10⁶ random sequences (Foundry) and proved symbolically (Halmos).                                                                                                         |

The vault share formula, and why the attack becomes unaffordable:

```
shares(a) = floor( a · (S + σ) / (A + 1) )        attack needs  X > a·σ − 1 ≈ 10⁶ · a
```

Without the offset, an attacker steals a deposit a by donating about a; with it, the donation must exceed about a million times a.

### 4 · Leaf 2: Investment Path (slides 32–48)

- **M5 Oracle.** Five sources polled in parallel (3 s timeout) → drop stale → quorum k ≥ 3 → median → reject if the median deviates more than δ = 10% from the 30-minute TWAP → round ID and timestamp must increase → signed with ML-DSA-44 and committed. The order is the security property: the median bounds a minority of corrupted feeds (one bad feed cannot move it, two cannot move it past a third), and the TWAP gate stops a correlated majority because an attacker must hold a fake price for 30 minutes. On failure, no price is committed: borrowing and liquidation freeze, repay and withdraw stay open.
- **M8 Settlement Rail.** IFiatRail interface over a double-entry ledger (every movement = a matched debit and credit). Mock PKR → test-net USDC in the sandbox, with deterministic delays and injectable failures. It is the only simulated part; swapping in a licensed bank or card provider is a configuration change.
- **M9 Anchoring & Audit.** The implementation of section 1: a Redis Streams batcher, sorted-pair Keccak tree, immutable PQAnchor.sol. The 60 s epoch matches gold's 60 s price heartbeat, so anchoring is never the slowest clock.

### 5 · Leaf 3: Lending & Risk (slides 50–52)

The health factor uses each asset's quantity q, committed price p, and liquidation threshold λ, over debt D:

```
HF = Σ ( qᵢ · pᵢ · λᵢ ) / D
```

| Health factor | State                                                                 |
| ------------- | --------------------------------------------------------------------- |
| ≥ 1.15        | Healthy; a borrow is allowed only if the post-borrow HF stays ≥ 1.15  |
| 1.00 – 1.15   | New borrowing frozen; 6 h to top up                                   |
| 0.95 – 1.00   | Reserve buffer opens a claim for shortfall = D(1 − HF); 6 h grace     |
| < 0.95        | Liquidation: at most 50% of debt, bonus decays 5% → 3% over 20 blocks |
| < 0.90        | Full closure; residual bad debt socialised                            |

- **Gold parameters:** loan-to-value θ = 60%, λ = 75%, heartbeat 60 s.
- **Buffer cap:** at most 40% of the buffer per epoch, so a market-wide crash cannot drain it. It is funded from interest income, never from depositors. A released claim costs nothing.
- **One liquidation is enough:** a position handed over at HF 0.95 returns to HF ≈ 1.11 after a 50% close.
- **Interest** uses a global index (O(1) per update instead of O(n)): 10,000 small loans cost the same gas as one. The rate is two-slope with a kink at 80% utilisation (+4% below, +75% above).
- **M6 has no authority:** the off-chain engine proposes liquidations; the contract recomputes HF and reverts if the engine was wrong.
- **M10 Clients:** React PWA with in-browser Falcon signing; the key lives in IndexedDB and is never transmitted.

### 6 · Leaf 4: Evaluation (slide 54)

| Experiment      | What it measures                                                                                                                                  | Answers       |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| A: crypto + gas | Keygen, sign and verify time and sizes for all 6 algorithms on desktop, browser and mid-range Android; gas from 1 to 4,096 events per epoch       | RQ1, RQ3      |
| User latency    | p50/p95 end-to-end time of the deposit and borrow flows at 1, 10 and 100 users                                                                    | RQ2           |
| B: buffer       | Liquidations avoided, bad debt and buffer use over the 2020 and 2024 gold crashes + 10,000 Monte Carlo paths at 1σ, 2σ, 3σ, vs an Aave V3 control | RQ4           |
| C: oracle       | Inject 1, 2 and 3 malicious feeds; assert which named check rejects each                                                                          | Oracle design |
| E: scale        | Risk sweep time at 10,000 open positions                                                                                                          | Scalability   |

Every result is compared with an otherwise identical **ECDSA-only build**, selected by one compile flag. A null result (negligible PQ overhead, or a buffer that prevents nothing) is reported as a finding.

## Likely panel questions (23)

Answer in two or three sentences: the direct answer first, then the number or mechanism that proves it. If you do not know, say which experiment will measure it.

### Literature review

**1. Why not just use an existing platform like BlackRock BUIDL or Ondo?**

They are built for institutions: BUIDL needs $5M and qualified purchasers. They also sign everything with ECDSA, have no micro-scale lending, and are not quantum-safe. No existing system covers all of these at once, as our literature synthesis shows.

**2. Quantum computers that break ECDSA do not exist yet. Why worry now?**

Because asset records must stay valid for 30+ years, and signatures recorded today can be forged later. Mosca's theorem: if data lifetime plus migration time exceeds the time to a quantum computer, you are already late. Experts put the chance at 28–49% within 10 years, and NIST plans to disallow ECDSA after 2035.

**3. Why not build on QRL or Algorand, which are already quantum-resistant?**

QRL is a separate, non-EVM chain with ~6 KB transactions, cut off from the Ethereum ecosystem where tokenized assets live. Algorand's full quantum resilience is targeted for 2027 and it has no RWA lending stack. We stay EVM-compatible and quantum-safe today.

**4. How is your approach different from rollups or the 2025 PQ audit-evidence paper?**

We reuse their idea (commit one root, check only on challenge), and we say so. Our contribution is applying it to a full financial protocol (custody attestation, KYC tokens, vaults, oracle and lending) and measuring the break-even against ECDSA. That paper covered audit logs only.

**5. ETHFALCON verifies Falcon on Ethereum. On a cheap L2, isn't 1.5M gas acceptable?**

It is still about 500× ECDSA on every single action, which kills PKR 1,000 economics. We keep ETHFALCON as the dispute verifier, paid only when someone challenges. When a Falcon precompile (EIP-8052) ships, switching to direct verification is a change of verifier address, not a migration.

### Methodology

**6. If verification happens off-chain, can't your backend lie?**

The backend holds no authority over funds: contracts re-check every rule. Every accepted envelope is anchored, so history cannot be altered or reordered, and anyone can challenge a false entry through the on-chain Falcon verifier. Users also keep their own signed copy, so an omitted action can be shown against a root that lacks it.

**7. What happens if the batcher or backend goes down?**

Execution is unaffected because the chain is the system of record; only the proof is delayed. The next anchor carries the accumulated leaves, and the epoch numbering makes the gap explicit. Repayment and withdrawal are never pausable.

**8. Where does "14 actions per minute" come from, and what if traffic is lower?**

43,000 gas per anchor divided by 3,000 gas per ECDSA check ≈ 14.3. Below 15 actions, per-action cost is above ECDSA, but it is still bounded at 43k per minute, about 35× cheaper than one direct Falcon check. The 43k is a budget; Experiment A measures the real figure.

**9. Why a 60-second epoch?**

It matches the fastest asset's price heartbeat (gold, 60 s), so anchoring is never the slowest clock. Shorter epochs raise the break-even; longer ones delay the user's proof. RQ2 measures what the user actually feels.

**10. How does a user verify offline?**

They keep {leaf, sibling hashes, epoch}, hash upward (about 12 hashes for 4,096 actions), and compare with the root stored on-chain. It works like checking a hierarchical checksum, and needs nothing from QORA's servers.

**11. Why Falcon for users but ML-DSA for custodians and admins?**

Falcon has the smallest signature (~666 B), which matters because every user action carries one. But its floating-point sampling is a side-channel risk on shared servers, so services use integer-only ML-DSA. The offline root uses hash-based SLH-DSA, so recovery does not depend on the same maths.

**12. Doesn't the reserve buffer just hide bad debt?**

No. It only covers shallow dips (HF 0.95–1.00) for at most 6 hours, at most 40% of the buffer per epoch, funded from interest income, never deposits. A sustained drop still liquidates, and an empty buffer behaves exactly like plain Aave. Experiment B tests this on the 2020 and 2024 gold crashes.

**13. How do you prevent an oracle attack like Mango Markets?**

Five independent sources, a quorum of three and a median mean two corrupted feeds cannot move the price. The 10% gate against the 30-minute average stops even three moving together, because the attacker must hold a fake price for 30 minutes. On any failure the oracle refuses, so a frozen price can never trigger a liquidation.

**14. Explain the vault inflation attack simply.**

An attacker makes a tiny first deposit, then donates a large amount so one share becomes very expensive; the next small deposit rounds down to zero shares. Our 10⁶ virtual offset makes the vault behave as already seeded, so the attack would cost about a million times the victim's deposit.

**15. How do you know the custodian really holds the gold?**

We verify the custodian's signed reserve report, its sequence and freshness, and enforce tokens ≤ reserve; we cannot prove physical existence with a signature, and we say so. If a report is overdue or false, the asset freezes: no minting or transfers, but withdrawals stay open. The real fix is a licensed, audited custodian after the FYP.

**16. What if a user loses their phone and key?**

The device key (Tier 2) can be re-bound to the user's identity through a recovery flow signed by a Tier 1 key. The old key's window is closed, so its past signatures stay valid but it cannot sign new actions.

### Technology and feasibility

**17. Why Arbitrum Sepolia and not Ethereum mainnet?**

It is a testnet, so there are no real funds in our sandbox, and it is an EVM-compatible rollup with low fees. Mainnet deployment comes only after independent audits.

**18. Why not implement the post-quantum algorithms yourselves?**

Hand-rolled lattice code is an unjustifiable risk. We use PQClean, the NIST reference implementations, wrapped in Rust and tested against official NIST test vectors. Our contribution is the integration and its measured cost, not new cryptography.

**19. How will you prove the system is correct?**

Foundry fuzz and invariant tests (e.g. tokens ≤ reserve, HF never below 1.15 after a borrow), Halmos symbolic proofs for vault rounding, an adversarial replay and nonce-reuse suite, and NIST vectors for all six algorithms. Everything is compared with an identical ECDSA build.

**20. Is this legal in Pakistan?**

The FYP is a sandbox: mock PKR, test-net tokens, a simulated custodian and no real funds. Tokens are ERC-3643, so only KYC-verified wallets can hold them. The production path is the SBP regulatory sandbox, PVARA licensing and a Shariah review for Sukuk and gold.

**21. How does PKR actually become USDC?**

In the FYP it is a simulated double-entry ledger behind one interface (IFiatRail). In production, a licensed payment partner, for example via Raast or card issuance, plugs into the same interface; that is a configuration change.

**22. What have you completed so far?**

Module 1, the PQ Core: Stages 0–3, 49 of 102 tasks. That covers all six NIST algorithms natively and in WebAssembly, the Node.js addon, the TypeScript API and the pqctl command-line tool. Module 3's ERC-3643 interfaces are scaffolded, and Module 2 is the critical path we finish next.

**23. Can three people deliver 11 modules in 24 weeks?**

The plan has four milestone gates, and the hardest dependency, the PQ Core, is already built. We reuse audited building blocks (OpenZeppelin, T-REX, PQClean, Aave V3 patterns), so the work is integration and measurement. Each gate is a runnable demo: MS2 at FYP-I is a PKR 5,000 deposit with an offline-verified proof.
