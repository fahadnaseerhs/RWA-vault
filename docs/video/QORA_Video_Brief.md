# QORA — Project Overview & Product-Launch Video Brief

> **For the AI assistant reading this (Claude, Gemini, etc.):** this file is the single source of truth about the QORA project for making a product-launch / explainer video. Use only the facts here. Do not invent features, partners, prices, users, or results. Where a claim is marked *planned* or *sandbox*, keep it that way in the video.

---

## 1. One-line pitch

**QORA lets anyone own a fraction of real assets — gold, treasury bills, Sukuk, property — from just PKR 1,000, borrow against them without selling, and trust that ownership for decades, because every action is secured with post-quantum cryptography.**

Full name: *QORA — Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets.*
Short tagline options:
- "Own the real. Secure it for the quantum era."
- "Real assets. From PKR 1,000. Safe for decades."
- "Invest, borrow, lend — quantum-safe."

---

## 2. What QORA is (plain language)

1. **Invest from PKR 1,000.** A verified custodian holds a real asset (e.g. a gold bar). QORA splits it into small digital units on a blockchain, so an ordinary saver can own a fraction.
2. **Unlock value without selling.** Users can **borrow** against what they own, or **lend** into a shared pool and earn a return. Limits and protections are enforced automatically by smart contracts.
3. **Everyday money in and out.** Deposit in **PKR**, it becomes a digital dollar (**USDC**) inside the platform, and converts back to **PKR** on withdrawal. Designed to plug into banks, Raast and card networks later.
4. **Quantum-safe ownership.** Every action — invest, borrow, repay, withdraw — is signed with **NIST post-quantum cryptography** and permanently recorded on-chain, so ownership records can't be forged, even by future quantum computers.

---

## 3. The problem it solves (the "why now")

| Problem | In one line |
| --- | --- |
| **Quantum threat to ownership records** | Every tokenized-asset platform today signs with ECDSA, which quantum computers will break. Asset records must last 30+ years, so records signed today could be forged later. |
| **Small investors are shut out** | Tokenized asset products are built for institutions (e.g. BlackRock's fund needs a **$5 million** minimum). |
| **Borrowing is unsafe for small borrowers** | A brief price dip can trigger instant liquidation; liquidators take more than needed; price feeds can be manipulated. |

---

## 4. Market facts you may use on screen

- Tokenized real-world assets on public blockchains: **~$39 billion** (Oct 2026), held in **5.19 million wallets**; grew **~266% in 2025**.
- Forecasts for 2030: **$2 trillion to $16 trillion**.
- **Pakistan is #3 in the world** for crypto adoption and **#2 for small (retail-size) transactions** (Chainalysis 2025).
- Pakistan's government signed an MoU to explore tokenizing **up to $2 billion** of T-bills, bonds and commodities (Dec 2025).
- **$41.6 billion** in remittances flowed into Pakistan in FY26 — a huge PKR↔USD flow.
- Only **about 1 in 4** Pakistani adults has a bank account.
- Experts estimate a **28–49% chance** of a code-breaking quantum computer within 10 years; NIST plans to phase out ECDSA by **2035**.

---

## 5. How it works (simple version for visuals)

**The core trick: sign off-chain, anchor on-chain.**
1. **Sign** — the user's phone signs each action with a quantum-safe key (Falcon-512). The key never leaves the phone.
2. **Verify** — QORA's servers check the signature (7 safety checks).
3. **Execute** — the smart contract carries out the action and re-checks its own rules.
4. **Batch** — every 60 seconds, all actions are packed into one digital fingerprint (a Merkle root).
5. **Anchor** — only that one 32-byte fingerprint is written on the blockchain, for a fixed small cost, however many actions it covers.
6. **Prove** — any user can check, offline and without trusting QORA, that their action is permanently recorded.

**Why it matters:** checking a quantum-safe signature directly on Ethereum costs about **1,300×** more than today's signatures. QORA's batching makes quantum safety **cheaper than today's method** once a batch has about **15 actions per minute**.

**Protections for small borrowers:**
- A brief price dip gets a **6-hour grace period** (a reserve buffer) instead of instant liquidation.
- If liquidation is needed, only **half** the loan is closed, with a small penalty that **shrinks from 5% to 3%**.
- Prices come from **5 independent sources**, using the median and a 30-minute average gate, so one fake price can't move the system.

---

## 6. The user journey (great as a story spine)

1. A saver signs up, verifies identity once (KYC), and their phone creates a quantum-safe key.
2. They deposit **PKR 1,000** → it becomes USDC → buys a fraction of real gold held by a custodian.
3. Their ownership is recorded and anchored; they can download proof any time.
4. Later they need cash — they **borrow against their gold** instead of selling it.
5. Gold dips briefly — the **buffer** protects them; no forced sale.
6. They repay, withdraw, and get **PKR** back. Every step was quantum-safe and verifiable.

---

## 7. Who it's for

- **Everyday savers** in Pakistan who want real, asset-backed investments from small amounts.
- **Small borrowers** who need cash without selling their assets.
- **Lenders** who want to earn on idle funds, backed by real assets.
- **Regulators and custodians** who need compliant, auditable records (only identity-verified wallets can hold QORA tokens).

---

## 8. Technology (for a "built with" moment — keep it light)

- NIST post-quantum standards: **ML-DSA, Falcon, SLH-DSA, ML-KEM**.
- **Arbitrum** (Ethereum-secured network), smart contracts in **Solidity**.
- Compliance token standard **ERC-3643** (only verified users can hold tokens); vault standard **ERC-4626**.
- Rust + WebAssembly cryptography that runs **inside the phone's browser**.
- React mobile web app (PWA).

---

## 9. Honest status — do NOT overclaim

- QORA is a **Final Year Project** by **Fahad Naseer, Hassan Attique and Fawaz Asif**.
- It runs as a **sandbox on a test network**: simulated PKR, test-net USDC, a simulated custodian, **no real money**.
- Card / bank / Raast integration, regulatory licensing and mainnet launch are **future plans**, not live features.
- The post-quantum cryptography core is **built**; other modules are **in development** (milestones run to week 24).
- Use phrases like "designed to", "built to", "coming", "in our sandbox" — never "available now", "trusted by", or user counts.

---

## 10. Visual identity (match the existing deck)

- **Background:** black. **Text:** white.
- **Fonts:** Bodoni MT (headings), DM Sans (body).
- **Signature motif:** realistic **minted metal tokens** — a **gold token** for gold, **silver tokens** for treasury bills, Sukuk, property, PKR and USDC, and a **gold lock token** for post-quantum security. A **gold bullion bar** splits into these tokens to show tokenization.
- **Motion style:** tokens travel between scenes (like PowerPoint Morph): the bar splits → tokens line up → a token locks → tokens flow into a chain.
- **Tone:** premium, calm, confident, trustworthy — finance meets deep-tech. Avoid crypto-hype visuals (rockets, moons, neon).

---

## 11. Suggested 75-second launch video storyboard

| Time | Scene | Visual | Voice-over (draft) |
| --- | --- | --- | --- |
| 0–6s | Hook | A gold bar on black, slow light sweep | "For centuries, real wealth meant gold, land, and bonds — out of reach for most people." |
| 6–14s | Tokenization | The bar splits into gold and silver tokens | "QORA turns real assets into small digital units — so anyone can own a piece, from just PKR 1,000." |
| 14–24s | Unlock value | A token slides into a vault, a USDC token comes out | "Need cash? Borrow against what you own — without selling it. Or lend, and earn." |
| 24–32s | Everyday money | PKR coin ⇄ USDC coin | "Deposit in rupees, withdraw in rupees. Simple." |
| 32–44s | The threat | Tokens begin to crack under a faint quantum-grid overlay | "But today's digital ownership is signed with cryptography that quantum computers will break." |
| 44–56s | The solution | A gold lock token seals the tokens; a chain of blocks forms | "QORA signs every action with post-quantum cryptography, and anchors it permanently on-chain." |
| 56–66s | Proof | A phone shows "Verified" over a small proof | "Anyone can verify their ownership — offline, without trusting us." |
| 66–75s | Close | Tokens gather into the QORA wordmark | "QORA. Own the real. Secure it for the quantum era." |

End card: *QORA — Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets* · "Final Year Project · Sandbox demo".

---

## 12. Glossary (for script accuracy)

- **Tokenization:** representing ownership of a real asset as digital units on a blockchain.
- **Custodian:** the institution that physically holds the real asset.
- **KYC:** one-time identity verification.
- **USDC:** a digital dollar (stablecoin) pegged to the US dollar.
- **Post-quantum cryptography (PQC):** encryption and signatures that quantum computers can't break.
- **Anchoring:** writing a tamper-proof fingerprint of many actions onto the blockchain.
- **Liquidation:** automatic sale of collateral when a loan becomes unsafe.
- **Reserve buffer:** QORA's grace period that protects borrowers from brief price dips.
