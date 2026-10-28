# QORA Defense: Presentation Script

## How to use this guide

The deck (QORA_Proposal_Defense_v3.pptx) has 66 click-steps, but it is one 10-minute talk: most clicks move a token inside the same slide, so keep talking through them. This script is what you say, line by line, with every click marked **[CLICK]**. The glossary, the methodology in depth and the 23 likely questions are in the companion Technical Guide.

| Section                      | Slides | Target time | Running clock |
| ---------------------------- | ------ | ----------- | ------------- |
| Title + Introduction         | 1–2    | 1:00        | 1:00          |
| Market Landscape             | 3–5    | 1:15        | 2:15          |
| Literature Review (rail)     | 6–14   | 2:00        | 4:15          |
| Problem Statement            | 15–17  | 0:45        | 5:00          |
| Verification Cycle + 43k gas | 18–25  | 1:30        | 6:30          |
| Four Leaves (modules)        | 26–55  | 2:00        | 8:30          |
| Timeline + Tools             | 56–57  | 0:30        | 9:00          |
| SDGs                         | 58–63  | 0:30        | 9:30          |
| Outcomes, Way Forward, Close | 64–66  | 0:30        | 10:00         |

**Delivery rules that make the animations work**

- Click on the last word of a sentence, not after a pause. Each transition takes 0.6 s, so one click is enough; never double-click.
- When a token moves, say where it is going ("the token moves to section 3.2"). The panel follows your eyes.
- Read the bold words on the slide, not whole rows. The tables are for the panel to scan; you say the one line that matters.
- If you fall behind, cut speech, not clicks: in the leaf slides say only the module's tagline and its "Why it holds".
- Suggested hand-offs for three speakers: Introduction to Problem Statement (speaker 1), Verification Cycle to Leaf 2 (speaker 2), Leaf 3 to Close (speaker 3). Each hand-off happens on a question line, so the next speaker opens with the answer.

## Script: slides 1–17

### Slide 1 · Title (0:00)

**On screen:** a gold bullion bar, QORA, the full title.

**Say:** "Assalam-o-Alaikum. We are presenting QORA, a Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets. This gold bar is a real asset. Watch what happens when we tokenize it."

**[CLICK]** → the bar splits into four tokens: gold, treasury bills, Sukuk and property shares.

### Slide 2 · Introduction (0:15)

**On screen:** four asset tokens; four rows: Invest, Borrow, Lend, Transact.

**Say:** "QORA lets everyday users **invest** in real-world assets like these four, starting from as little as **PKR 1,000**. Each asset is held by a verified custodian and split into small digital units on the blockchain. Users can **borrow** against their holdings without selling them, and other users can **lend** into the pool and earn a return. Money moves in PKR, is converted to USDC for investing and lending, and back to PKR on withdrawal. And underneath all of this, every transaction is signed with post-quantum cryptography and permanently recorded. We have seen what QORA does; is the market ready for it?"

**[CLICK]** → the four tokens climb into a staircase.

### Slide 3 · The Global Shift (1:00)

**Say:** "Tokenized real-world assets on public blockchains have reached **$39 billion**, held in **5.19 million wallets**. The market grew about **266% in 2025** and another **30% in the first quarter of 2026** alone. So tokenization is no longer an experiment. Five million people already hold these assets; where is the next wave? One of the strongest answers is Pakistan."

**[CLICK]** → the asset tokens leave; PKR and USDC tokens arrive.

### Slide 4 · Pakistan: A Crypto-Ready Nation (1:30)

**Say:** "Pakistan ranks **#3 in the world** for crypto adoption and **#2 for retail-size transactions**, which means people transact in small amounts, exactly QORA's PKR 1,000 scale. The government has signed an MoU to explore tokenizing up to **$2 billion** of T-bills, bonds and commodities, the same asset classes we target. And **$41.6 billion** in remittances flow between PKR and dollars every year, which is the conversion our PKR–USDC rail is built for. Users are already on-chain; they just lack real, asset-backed investments. Owning is half the story; the other half is lending."

**[CLICK]**

### Slide 5 · Lending: The Engine of On-Chain Finance (1:55)

**Say:** "Aave, the lending model our design follows, has processed **$1 trillion** in loans and already holds **over $1 billion of real-world assets as collateral**. Lending is more than **80%** of on-chain finance activity. On the left, a gold token is locked as collateral and a USDC loan comes out. QORA brings this model down to PKR 1,000. So the opportunity is clear. How has research tried to build it, and what has it missed?"

**[CLICK]** → a rail with four stations appears; the gold token sits at 3.1.

### Slides 6–14 · Literature Review: one rail (2:15)

The rail is the thread of the whole review. Each section is two clicks: the question, then the table. Say the question, click, say only the bold findings, click.

**Slide 6 (question 3.1):** "Our literature review follows one ownership record. First question: how do you turn ownership of a real asset into a digital record that is also legal?" **[CLICK]**

**Slide 7 (table 3.1):** "T-REX in 2018 created the first token designed for regulated securities, and in 2021 it became ERC-3643, where KYC rules live **inside the token**. ERC-4626 in 2022 standardized shared vaults, and OpenZeppelin's virtual offset fixed the attack on small depositors. The BIS endorsed tokenization in 2023, and by 2024 BlackRock's BUIDL fund reached **$2.8 billion**. Ownership became digital and legal, but only for institutions." **[CLICK]** → the table closes, the token moves to 3.2.

**Slide 8 (question 3.2):** "Owning an asset is only half its value. The other half is being able to use it without selling it." **[CLICK]**

**Slide 9 (table 3.2):** "MakerDAO, Compound and Aave made over-collateralized lending possible. But Perez and colleagues showed that a price change of **only 3%** can make **over $10 million** of loans liquidatable. Qin and colleagues showed liquidators take more collateral than necessary, **at the borrower's expense**. And Mango Markets lost **$114 million** when its price feed was manipulated." **[CLICK]** → the token becomes a lock and moves to 3.3.

**Slide 10 (question 3.3):** "Every record, transfer and loan we just saw is signed with one scheme: ECDSA. A property record must stay valid for thirty years. Will ECDSA last that long?" **[CLICK]**

**Slide 11 (table 3.3):** "In 1994 Shor proved a quantum computer can break ECDSA. Mosca's theorem says long-lived records are in danger **today**. NIST published the post-quantum standards in 2024 and plans to disallow ECDSA after **2035**. In 2026 Google estimated the curve used by blockchains could fall to fewer than **1,200 logical qubits, in minutes**. Yet only **7%** of organizations have deployed quantum-safe cryptography." **[CLICK]** → the token moves to 3.4.

**Slide 12 (question 3.4):** "The replacement already exists. So why hasn't anyone put it directly on the blockchain?" **[CLICK]**

**Slide 13 (table 3.4):** "Because direct verification costs too much. QRL built a new chain with **6 KB** transactions; Algorand's full resilience is targeted for **2027**; the best Falcon verifier on Ethereum still costs **1.5 million gas** per signature; Ethereum's own fix targets **2029**. The affordable path comes from Merkle trees and rollups: commit one root, check only when challenged. A 2025 paper applied it to audit logs, but not to finance." **[CLICK]** → all four stations turn gold.

**Slide 14 (synthesis):** "Compliant tokens, working lending, PQC standards and affordable anchoring all exist, each in a different place. No one has put them together." **[CLICK]**

### Slides 15–17 · The Three Problems (4:15)

Each click adds one card.

**Slide 15:** "So, can a person with PKR 1,000 own a real asset, use it, and trust that ownership for decades? The literature says no, for three reasons. **P1:** ownership records are quantum-vulnerable, and the fix costs about **500 times** more than ECDSA." **[CLICK]**

**Slide 16:** "**P2:** tokenized assets exclude small investors, with minimums of up to **$5 million**, and the standard vault is most exploitable at small deposits." **[CLICK]**

**Slide 17:** "**P3:** borrowing is unsafe for micro-borrowers: brief price dips trigger liquidations, liquidators take excess collateral, and price feeds can be manipulated. P1 is the security problem; P2 and P3 are the inclusion problems. Here is how QORA solves them." **[CLICK]**

## Script: slides 18–66

### Slides 18–24 · The Verification Cycle (5:00)

The lock token walks the ring one step per click. Say the step name, then one sentence.

**Slide 18 (Sign):** "Our core idea is to sign off-chain and anchor on-chain. Step one: the user's app builds an envelope describing the action and signs it with **Falcon-512** in the browser. The key never leaves the device." **[CLICK]**

**Slide 19 (Verify):** "Our backend runs **seven checks**: right algorithm, active key, right chain and contract, inside the time window, correct nonce, valid signature, unchanged payload. Any failure is rejected with a named reason." **[CLICK]**

**Slide 20 (Execute):** "The contract call goes on-chain, and the chain re-checks its own rules independently." **[CLICK]**

**Slide 21 (Leaf):** "The envelope's hash, a 32-byte fingerprint like a CRC, joins the current 60-second batch." **[CLICK]**

**Slide 22 (Anchor):** "Every 60 seconds, the whole batch becomes one Merkle tree, and only its 32-byte root is written on-chain." **[CLICK]**

**Slide 23 (Prove):** "Any user can download a short proof and check offline that their action is permanently recorded, without trusting us." **[CLICK]** → the lock moves to the centre.

**Slide 24 (Dispute):** "And if anyone suspects a false batch, they challenge one envelope, and the full Falcon verifier runs on-chain for that single case, paid by the challenger. The expensive check runs only when a fault is flagged." **[CLICK]**

### Slide 25 · How 43k Gas Is Possible (6:00)

**Say:** "Gas is Ethereum's fee unit. We do not verify signatures on-chain; we store one 32-byte number per minute. A transaction's base cost is 21,000 gas, writing the root about 20,000, so a batch costs about **43,000 gas**, the same for 1 action or 4,096. ECDSA costs 3,000 gas per action; Falcon directly on-chain costs 1.5 million. Divide 43,000 by 3,000 and you get **14.3**: from 15 actions per minute onward, quantum-safe authentication is cheaper than today's ECDSA." **[CLICK]** → the leaf hub appears.

### Slides 26–55 · Four Leaves, One System (6:30)

The hub is the map. Each leaf opens, walks its modules, and returns to the ring turning gold. One sentence per module; read the tagline and the "Why it holds" line.

**Slide 26 (hub):** "We build QORA as eleven modules in four leaves: Foundation, Investment Path, Lending and Risk, and Evaluation." **[CLICK]**

**Slides 27–30, Leaf 1 Foundation:**

- **M1 PQ Core:** "The cryptography engine: vetted NIST reference code, compiled for the server and the browser, one algorithm per job. We write no cryptography of our own." **[CLICK]**
- **M2 PQ-PKI and Envelope:** "Three tiers of keys, and an envelope where every field blocks one attack, such as replay or a swapped payload." **[CLICK]**
- **M3 Registry and Compliance:** "An asset goes live only after four checks on the custodian's signed reserve report, and only KYC-verified wallets can hold it." **[CLICK]**
- **M4 Vault Accounting:** "The vault issues shares from PKR 1,000. The virtual offset raises the cost of stealing a PKR 1,000 deposit from about PKR 1,000 to about **PKR 1 billion**." **[CLICK]** → back to the hub, Leaf 1 turns gold.

**Slide 31 (hub):** "Leaf 1 done. Leaf 2, the investment path." **[CLICK]**

**Slides 32–38, M5 Oracle (seven clicks, one per chip):** "A price is a decision the protocol makes. Five sources arrive **[CLICK]**; a dead or stale one is dropped **[CLICK]**; at least three must remain **[CLICK]**; we take the median, which rejects outliers like a median filter **[CLICK]**; it must sit within 10% of the 30-minute average, like a low-pass filter **[CLICK]**; the round ID must increase **[CLICK]**; and the price is signed and committed **[CLICK]**."

**Slides 39–47, M8 Settlement (nine clicks):** "Money moves between PKR and USDC. Deposit: PKR, ledger credit, test-net USDC, vault shares **[CLICK × 4]**. Withdraw: shares redeemed, USDC, ledger debit, PKR out **[CLICK × 4]**. It is a double-entry ledger behind one interface, so a real bank or card provider is a configuration change." **[CLICK]**

**Slide 48, M9 Anchoring and Audit:** "This is the module behind the cycle: 43k gas per epoch, 12 hashes to prove one action in 4,096." **[CLICK]**

**Slide 49 (hub):** "Leaf 3, lending and risk." **[CLICK]**

**Slides 50–52, Leaf 3:**

- **M6 Risk Engine:** "It recomputes every loan's health factor on each price, like a comparator with trip levels. The engine proposes; the chain decides." **[CLICK]**
- **M7 Lending and Liquidation:** "Our reserve buffer gives a 6-hour grace period on a brief dip, like a capacitor riding through a voltage dip. A real drop liquidates at most 50%, with a bonus that falls from 5% to 3%." **[CLICK]**
- **M10 Clients:** "The apps: signing happens on the user's device, and no off-chain component can move a user's funds." **[CLICK]**

**Slide 53 (hub):** "Leaf 4." **[CLICK]** **Slide 54, M11 Evaluation:** "Every number is measured against an identical ECDSA build switched by one compile flag, plus the 2020 and 2024 gold crashes." **[CLICK]** **Slide 55 (hub, all gold):** "Eleven modules, four leaves, one system." **[CLICK]**

### Slides 56–57 · Timeline and Tools (8:30)

**Slide 56:** "We deliver in 24 weeks with four milestones. MS2, at FYP-I, is a PKR 5,000 deposit with a proof verified offline. The PQ Core is already built." **[CLICK]**

**Slide 57:** "Our stack: Solidity and Foundry for contracts, Rust and WebAssembly for the cryptography, NestJS, React, and Arbitrum Sepolia testnet with no real funds." **[CLICK]**

### Slides 58–63 · Sustainable Development Goals (9:00)

**Slide 58:** "QORA serves five SDGs." Then one line per click: **SDG 1** fractional ownership from PKR 1,000 **[CLICK]**; **SDG 5** a low-minimum mobile account against an 11.9% vs 42.3% gender gap **[CLICK]**; **SDG 8** banking access in one platform **[CLICK]**; **SDG 9** asset-backed micro-credit **[CLICK]**; **SDG 16** every action verifiable by anyone **[CLICK]**.

### Slides 64–66 · Outcomes, Way Forward, Close (9:30)

**Slide 64:** "We will deliver a working 11-module sandbox and measured results: the gas break-even, PQC speed on a phone, and the liquidations our buffer prevents." **[CLICK]**

**Slide 65:** "Next we finish Module 2, then regulation, real partners, audits and mainnet." **[CLICK]**

**Slide 66:** "QORA: one platform to invest, borrow, lend and transact on real-world assets, secured for the quantum era. Thank you; we welcome your questions."
