// QORA technical proposal, IEEE two-column format, generated with docx-js.
// Run: node build_proposal.js  -> ../QORA_Technical_Proposal.docx
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, WidthType, AlignmentType,
  HeadingLevel, SectionType, LevelFormat, BorderStyle, TabStopType, ShadingType, VerticalAlign,
} = require(path.join("C:/Users/USER/AppData/Local/Temp/claude/C--Users-USER-OneDrive-Desktop-RWA-vault/22c0d93f-95db-488a-9ad8-cfe9b0a46593/scratchpad/deck/node_modules/docx"));

const FIG = (f) => path.join(__dirname, "fig", f);
const FONT = "Times New Roman";
const PAGE = { width: 12240, height: 15840 }; // US Letter
const MARGIN = { top: 1080, bottom: 1440, left: 900, right: 900 };
const GAP = 360;
const FULLW = PAGE.width - MARGIN.left - MARGIN.right; // 10440
const COLW = (FULLW - GAP) / 2; // 5040

// ---------- inline mini-markup: **bold**, *italic*, _{sub}, ^{sup}, [n] kept as text
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|_\{[^}]+\}|\^\{[^}]+\})/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), ...base }));
    const t = m[0];
    if (t.startsWith("**")) out.push(new TextRun({ text: t.slice(2, -2), bold: true, ...base }));
    else if (t.startsWith("_{")) out.push(new TextRun({ text: t.slice(2, -1), subScript: true, ...base }));
    else if (t.startsWith("^{")) out.push(new TextRun({ text: t.slice(2, -1), superScript: true, ...base }));
    else out.push(new TextRun({ text: t.slice(1, -1), italics: true, ...base }));
    last = m.index + t.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), ...base }));
  return out;
}
const P = (text, o = {}) => new Paragraph({ children: runs(text), alignment: AlignmentType.JUSTIFIED, indent: o.noIndent ? undefined : { firstLine: 202 }, spacing: { after: 40, line: 230 }, ...o.p });
let h1n = 0;
const H1 = (t) => { const num = t === "References" ? "" : `${["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][++h1n]}. `; return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(num + t)] }); };
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)] });
const H3 = (lead, text) => new Paragraph({ alignment: AlignmentType.JUSTIFIED, indent: { firstLine: 202 }, spacing: { after: 40, line: 230 },
  children: [new TextRun({ text: lead + ": ", italics: true }), ...runs(text)] });
const BUL = (text) => new Paragraph({ numbering: { reference: "bul", level: 0 }, alignment: AlignmentType.JUSTIFIED, spacing: { after: 20, line: 230 }, children: runs(text) });
let eqn = 0;
const EQ = (text) => { eqn++; return new Paragraph({ tabStops: [{ type: TabStopType.CENTER, position: COLW / 2 }, { type: TabStopType.RIGHT, position: COLW }], spacing: { before: 60, after: 60 },
  children: [new TextRun("\t"), ...runs(text, { italics: false }), new TextRun(`\t(${eqn})`)] }); };
let figN = 0, tabN = 0;
const ROMAN = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"];
function pngSize(f) { const b = fs.readFileSync(f); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) }; }
function FIGURE(num, file, caption, wide) {
  figN = Math.max(figN, num);
  const { w, h } = pngSize(FIG(file));
  const pw = wide ? 690 : 330, ph = Math.round(pw * h / w);
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 80 }, children: [new ImageRun({ type: "png", data: fs.readFileSync(FIG(file)), transformation: { width: pw, height: ph } })] }),
    new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 120 }, children: [new TextRun({ text: `Fig. ${num}. `, size: 16 }), ...runs(caption, { size: 16 })] }),
  ];
}
const thin = { style: BorderStyle.SINGLE, size: 4, color: "000000" };
function TABLE(title, header, rows, widths, wide) {
  tabN++;
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (t, head) => new TableCell({
    width: { size: widths[0], type: WidthType.DXA }, verticalAlign: VerticalAlign.CENTER,
    margins: { top: 30, bottom: 30, left: 60, right: 60 },
    shading: head ? { type: ShadingType.CLEAR, fill: "FFFFFF", color: "auto" } : undefined,
    children: [new Paragraph({ children: runs(t, { size: 15, bold: head || undefined }) })],
  });
  const mk = (cells, head) => new TableRow({ tableHeader: head, children: cells.map((c, i) => { const tc = cell(c, head); tc.options = tc.options; return new TableCell({
    width: { size: widths[i], type: WidthType.DXA }, verticalAlign: VerticalAlign.CENTER, margins: { top: 30, bottom: 30, left: 60, right: 60 },
    children: [new Paragraph({ children: runs(c, { size: 15, bold: head || undefined }) })] }); }) });
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120 }, children: [new TextRun({ text: `TABLE ${ROMAN[tabN]}`, size: 16, smallCaps: true })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 }, children: [new TextRun({ text: title, size: 16, smallCaps: true })] }),
    new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths, alignment: AlignmentType.CENTER,
      borders: { top: thin, bottom: thin, left: thin, right: thin, insideHorizontal: thin, insideVertical: thin },
      rows: [mk(header, true), ...rows.map((r) => mk(r, false))] }),
    new Paragraph({ spacing: { after: 80 }, children: [] }),
  ];
}
const C2 = (children) => ({ properties: { type: SectionType.CONTINUOUS, page: { size: PAGE, margin: MARGIN }, column: { count: 2, space: GAP, equalWidth: true } }, children });
const C1 = (children) => ({ properties: { type: SectionType.CONTINUOUS, page: { size: PAGE, margin: MARGIN }, column: { count: 1 } }, children });

// =====================================================================  CONTENT
const titleBlock = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 }, children: [new TextRun({ text: "QORA: A Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets", size: 44 })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 40 }, children: [new TextRun({ text: "Final Year Project Proposal \u2014 Technical Report", size: 20, italics: true })] }),
  new Table({
    width: { size: FULLW, type: WidthType.DXA }, columnWidths: [3480, 3480, 3480], alignment: AlignmentType.CENTER,
    borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE }, insideHorizontal: { style: BorderStyle.NONE }, insideVertical: { style: BorderStyle.NONE } },
    rows: [new TableRow({ children: [["Fahad Naseer", "403897"], ["Hassan Attique", "482073"], ["Fawaz Asif", "473423"]].map(([n, c]) => new TableCell({
      width: { size: 3480, type: WidthType.DXA },
      children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: n, size: 22 })] }),
                 new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: `CMS ID: ${c}`, size: 18, italics: true })] })] })) })],
  }),
  new Paragraph({ spacing: { after: 200 }, children: [] }),
];

const abstract = [
  new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 60, line: 220 }, children: [new TextRun({ text: "Abstract", bold: true, italics: true, size: 18 }), new TextRun({ text: "\u2014", bold: true, size: 18 }),
    ...runs("A tokenized real-world asset is a record of who owns what fraction of a physical or financial asset, and that record must remain verifiable for as long as the asset exists, commonly thirty years. Every deployed tokenization platform authenticates such records with elliptic-curve signatures, which a cryptographically relevant quantum computer will break, while verifying a standards-conformant post-quantum signature inside the Ethereum Virtual Machine costs about 3.9 million gas. QORA separates authentication from anchoring. Every user intent and every institutional attestation is signed with a NIST post-quantum algorithm inside a canonical envelope (Falcon-512 on the user device, ML-DSA for services, SLH-DSA for an offline root), verified off-chain, and committed each 60 seconds as one Keccak-256 Merkle root on Arbitrum Sepolia at a budgeted 43k gas regardless of event count, which falls below the per-event cost of ECDSA beyond roughly fourteen events per epoch. On this fabric QORA carries permissioned fractional ownership (ERC-3643 with ERC-4626 vault accounting hardened by a virtual-share offset), a five-source oracle, and a collateralised lending market whose bounded reserve buffer and decaying liquidation bonus are parameterised for PKR 1,000 positions. The system is built as a sandbox and every claim is measured against an otherwise identical ECDSA-only control build.", { bold: true, size: 18 })] }),
  new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 120, line: 220 }, children: [new TextRun({ text: "Index Terms", bold: true, italics: true, size: 18 }), new TextRun({ text: "\u2014post-quantum cryptography, ML-DSA, Falcon, SLH-DSA, Merkle anchoring, RWA tokenization, ERC-3643, ERC-4626, DeFi lending, Arbitrum.", bold: true, size: 18 })] }),
];

const intro = [
  H1("Introduction"),
  P("QORA is a post-quantum secured platform that lets everyday users invest in real-world assets such as gold, treasury bills, Sukuk and property shares, starting from as little as PKR 1,000. Each asset is held by a verified custodian and represented on a blockchain as small, permissioned digital units, so a user can own a fraction of an asset that was previously out of reach."),
  P("QORA turns that ownership into programmable wealth. Holders do not only own their assets; they can unlock their value by borrowing against them without selling, while other users lend into the platform's pool and earn a return. Borrowing limits, repayments and protection against transient price drops are enforced by smart contracts rather than by an intermediary."),
  P("The platform connects digital ownership to everyday money. Users deposit in PKR, which is credited as a dollar stablecoin (USDC) for investing and lending and converted back to PKR on withdrawal, behind a settlement interface designed to integrate with banking and card networks."),
  P("Underneath all of this, every transaction (investing, borrowing, lending, transferring and withdrawing) is signed with post-quantum cryptography and permanently anchored on-chain, so a user's proof of ownership stays tamper-evident for the asset's lifetime, including against future quantum computers."),
  P("The rest of this report follows one thread. Section II sizes the market. Section III reviews post-quantum signing and its status on existing blockchains, then the anchoring, tokenization and lending literature that QORA builds on. Section IV derives the problem statement from the gaps that review exposes. Section V describes the engineering method module by module, down to the stack. Sections VI to VIII give the expected deliverables, the sustainable development goals served, and the timeline."),
];

const market = [
  H1("Market Context"),
  P("Tokenized real-world assets on public blockchains reached US$39.02 billion in distributed value across 5.19 million holder addresses by October 2026, after growth of roughly 266% in 2025 and a further 30% in the first quarter of 2026 alone [32], [33]; forecasts for 2030 range from about US$2 trillion to US$16 trillion [34]. Pakistan is positioned unusually well for this shift: it ranks third in the world in Chainalysis' 2025 Global Crypto Adoption Index and second for retail-size transactions, which is exactly the PKR 1,000 scale QORA targets [35]; the government signed a memorandum with Binance in December 2025 to explore tokenizing up to US$2 billion of treasury bills, bonds and commodity reserves [36]; workers' remittances reached a record US$41.6 billion in FY26, a large and steady PKR\u2013USD flow [37]; and 92% of retail payments are already digital, with 95.8 million branchless-banking app users [38]. Yet only about a quarter of adults hold a formal account [39], so demand for small-ticket, asset-backed investment is large and unserved."),
];

const lit = [
  H1("Literature Review"),
  P("The review starts where QORA's security starts, with the post-quantum signature standards and their state on existing blockchains, then moves to the commitment techniques that make post-quantum authentication affordable, and finally to the tokenization and lending work that defines the financial layer. Each subsection ends on the limitation it leaves, and Section IV collects them."),
  H2("A. Post-Quantum Signature Standards"),
  P("NIST's post-quantum programme, opened in 2016, published its first three standards on 13 August 2024: ML-KEM (FIPS 203), a module-lattice key-encapsulation mechanism; ML-DSA (FIPS 204), a module-lattice signature; and SLH-DSA (FIPS 205), a stateless hash-based signature [1]\u2013[3]. Falcon is being standardized as FN-DSA (FIPS 206), submitted for approval in August 2025 and still a draft [4], and HQC was selected in March 2025 as a code-based backup KEM. NIST's transition plan proposes deprecating 112-bit quantum-vulnerable algorithms, including ECDSA, after 2030 and disallowing them after 2035 [5]."),
  P("The schemes trade size, speed and assumption differently (Table I). ML-DSA is integer-only and simple to implement in constant time, but its signatures are 2.4\u20133.3 KB. Falcon produces the most compact lattice signature (666 B in its padded form) but relies on Gaussian sampling over floating point, a documented side-channel and portability hazard on shared hosts. SLH-DSA rests only on hash functions, which makes it the most conservative choice for a long-lived root of trust, at the cost of 7.8 KB signatures and slow signing."),
  ...TABLE("Signature Primitives Relevant to QORA", ["Scheme", "Basis", "pk / sig (B)", "Status"], [
    ["ECDSA secp256k1", "elliptic curve", "33 / 64", "quantum-vulnerable"],
    ["ML-DSA-44", "module lattice", "1312 / 2420", "FIPS 204"],
    ["ML-DSA-65", "module lattice", "1952 / 3309", "FIPS 204"],
    ["Falcon-512 (padded)", "NTRU lattice", "897 / 666", "FIPS 206 draft"],
    ["SLH-DSA-SHA2-128s", "hash-based", "32 / 7856", "FIPS 205"],
  ], [1450, 1150, 1240, 1200]),
  P("The threat timeline that motivates migration has shortened. Mosca's inequality states that data whose security lifetime X plus migration time Y exceeds the time Z to a cryptographically relevant quantum computer is already at risk [6]; a thirty-year ownership record satisfies it today. Gidney reduced the estimate for factoring RSA-2048 to fewer than one million noisy qubits in under a week, twenty times fewer than his 2019 figure [7], and Babbush et al. estimate that the 256-bit elliptic-curve discrete logarithm used by blockchains needs fewer than 1,200 logical qubits and could run in minutes on under 500,000 physical qubits, urging migration \"without delay\" [8]. Surveyed experts put the probability of such a machine within ten years at 28\u201349% [9], yet only 7% of organizations have deployed quantum-safe cryptography at scale [10]. The limitation is not the absence of standards but their absence from deployed systems."),
  H2("B. Post-Quantum Signing on Existing Blockchains"),
  P("Fern\u00e1ndez-Caram\u00e9s and Fraga-Lamas concluded that blockchains must be redesigned around quantum-resistant cryptosystems, because signatures, hashes and consensus all depend on them [11]. Four ecosystems illustrate how differently that redesign is being attempted (Table II)."),
  H3("QRL", "The Quantum Resistant Ledger was built from genesis on XMSS, a stateful hash-based Merkle signature that lets one address sign up to 2^{13} times. Its transactions are about 6 KB and wallets must track one-time key state; it runs its own chain and is migrating to an EVM-compatible proof-of-stake successor [12]. Quantum resistance is achieved by isolation from the ecosystem in which tokenized assets live."),
  H3("Algorand", "Since 2022 Algorand signs state proofs, compact certificates over every 256 block headers, with Falcon; the first Falcon-authorized user transaction, executed through a LogicSig program, followed in November 2025, and broad quantum resilience, possibly with hybrid Ed25519\u2013Falcon consensus messages, is targeted for 2027 [13]. Chain history is protected first; ordinary accounts remain on Ed25519 by default."),
  H3("Cosmos", "Cosmos chains use secp256k1 for accounts and Ed25519 for CometBFT validator consensus by default [14]. Ledger Security 2026.1 (Cosmos SDK v0.55.0, CometBFT v0.40.0, cosmos/kms v0.1.0), released in October 2026, adds ML-DSA-65 for accounts and consensus, but each chain must enable it and a network is post-quantum secure only once two-thirds of voting power has rotated; chains that keep Ethereum-compatible accounts stay on secp256k1 [15]. In parallel, the Cosmos Hub is removing Interchain Security, so a new application chain must bootstrap its own validator set [16]."),
  H3("Ethereum", "The EVM has no post-quantum precompile. ZKNox's ETHFALCON provides Solidity verifiers: the NIST-compliant ZKNOX_falcon costs about 3.9M gas, while the cheaper ZKNOX_ethfalcon (about 1.5M gas) replaces SHAKE with Keccak and therefore verifies a different scheme [17]. Precompile proposals such as EIP-7885 (an NTT precompile) and EIP-8052 would reduce verification to thousands of gas, and the Ethereum Foundation's post-quantum programme, formed in 2026 with more than ten client teams, targets protocol-level support around 2029 [18], [19]."),
  ...TABLE("Post-Quantum Status of Candidate Chains", ["Chain", "Accounts / consensus", "PQ today", "Limitation"], [
    ["QRL", "XMSS / PoW", "yes", "6 KB tx, stateful keys, non-EVM"],
    ["Algorand", "Ed25519 (+Falcon LogicSig) / Ed25519", "partial", "full resilience 2027"],
    ["Cosmos", "secp256k1 / Ed25519 (ML-DSA-65 opt-in)", "opt-in", "needs 2/3 stake rotation; EVM accounts stay secp256k1"],
    ["Ethereum / L2", "secp256k1 / BLS", "no", "on-chain Falcon 3.9M gas; protocol fix ~2029"],
  ], [1000, 1640, 700, 1700]),
  P("No chain today offers post-quantum authentication that is simultaneously default, EVM-compatible and affordable per action. An application that needs thirty-year records cannot wait for its base layer."),
  H2("C. Commitment, Anchoring and Optimistic Verification"),
  P("Merkle trees commit any number of records to one 32-byte root, and membership of one record is proven with \u2308log_{2} n\u2309 sibling hashes [20]. Haber and Stornetta's linked timestamping, cited by the Bitcoin whitepaper, made records tamper-evident without a trusted clerk [21], and services such as OpenTimestamps batch many hashes into one root anchored on a public chain. Optimistic rollups such as Arbitrum post compact commitments and adjudicate only when a fraud proof is submitted; the BoLD protocol made that dispute game resistant to delay attacks without raising on-chain cost [22]. Most directly, recent work on post-quantum-resilient audit evidence signs only the Merkle root of a batch with a post-quantum signature, spreading its cost across many records [23]. These techniques are proven for timestamps, rollups and audit logs; none has been applied to a financial protocol whose records drive custody, collateral and liquidation, and none quantifies the break-even against per-event ECDSA."),
  H2("D. Tokenization and Vault Standards"),
  P("The OECD defined tokenization as the digital representation of real assets on distributed ledgers and observed that it still depends on a trusted custodian and on a tokenized cash leg [24]. Tokeny's T-REX (2018), standardized as ERC-3643 in 2021, enforces securities compliance inside the token: every transfer consults an identity registry of ONCHAINID claims and a compliance module, and fails if the receiver is not eligible [25]. ERC-4626 (2022) standardized vaults that convert deposits into proportional shares; it is vulnerable to an inflation (donation) attack in which an attacker seeds an empty vault and donates assets so that a later deposit rounds to zero shares, which OpenZeppelin mitigates with virtual shares and assets [26]. The BIS proposed a unified ledger on which tokenized money and tokenized assets settle in one step [27], and BlackRock's BUIDL fund reached about US$2.8 billion, open only to qualified purchasers with a US$5 million minimum [28]. Ownership has become digital, compliant and institutional, but the inflation attack is cheapest precisely at small deposit sizes and the minimums exclude retail savers."),
  H2("E. Collateralized Lending and Liquidation Risk"),
  P("MakerDAO, Compound and Aave established over-collateralized lending without intermediaries, and Aave has now processed US$1 trillion in cumulative loans and accepts over US$1 billion of tokenized real-world assets as collateral [29]. Measurement studies show how harsh these designs are for borrowers. Perez et al. found that a price move of only 3% can make over US$10 million of Compound positions liquidatable, with more than 70% liquidated almost immediately [30]. Qin et al., covering Aave, Compound, MakerDAO and dYdX (over 85% of the market), showed that liquidators sell more discounted collateral than necessary at borrowers' expense [31]. The Mango Markets exploit, in which a thin market was pumped 5\u201310\u00d7 to borrow and drain about US$114 million, demonstrated that the price oracle is a primary attack surface [40]. Lending against tokenized assets works at scale, but its liquidation and oracle designs are tuned for large positions and leave micro-borrowers exposed."),
];

const problem = [
  H1("Problem Statement"),
  H2("A. Blockchain and Post-Quantum Authentication"),
  P("Every tokenized-asset platform reviewed authenticates ownership, attestations and transfers with ECDSA or Ed25519, both broken by Shor's algorithm, while asset records must remain verifiable for thirty years or more (Section III-A). The chains themselves are not post-quantum by default: QRL is isolated, Algorand's coverage is partial until 2027, Cosmos requires per-chain opt-in and stake rotation and leaves EVM accounts classical, and Ethereum's protocol support is targeted for about 2029 (Section III-B). Verifying a standards-conformant post-quantum signature in the EVM costs about 3.9M gas, roughly 1,300 times an ECDSA recovery, which makes per-action on-chain verification uneconomic. Anchoring techniques that amortize this cost exist but have not been engineered into a financial protocol (Section III-C)."),
  H2("B. Financial Inclusion and Borrower Safety"),
  P("On the financial side, tokenized asset products are institutional, with minimums up to US$5 million, and the standard vault construction is most exploitable at small deposits (Section III-D). Collateralized lending liquidates on small, transient price moves, transfers excess collateral to liquidators and depends on manipulable price feeds (Section III-E); at PKR 1,000 scale a single liquidation bonus is a large fraction of the position."),
  H2("C. Consolidated Statement and Research Questions"),
  P("**No existing system provides post-quantum, affordable, permanently verifiable authentication for tokenized real-world asset ownership on an EVM chain, combined with compliant fractional ownership and lending that are safe at PKR 1,000 scale.** QORA addresses this and is evaluated through four research questions:", { noIndent: false }),
  BUL("**RQ1:** What do the six post-quantum primitives cost in key generation, signing and verification time and in key and signature size, natively and in browser WebAssembly on desktop and a mid-range Android device?"),
  BUL("**RQ2:** What end-to-end p50/p95 latency does a user experience in the deposit and borrow flows at 1, 10 and 100 concurrent users?"),
  BUL("**RQ3:** What is the measured on-chain cost per authenticated event of epoch anchoring from 1 to 4,096 events, and where is the break-even against per-event ECDSA?"),
  BUL("**RQ4:** Does the bounded reserve buffer reduce liquidations caused by transient shocks without allowing sustained undercollateralization, compared with an Aave-V3-parameterised control?"),
];

const method1 = [
  H1("Methodology"),
  P("The method follows one dividing rule: **the chain holds authority, everything else holds work**. On-chain code is the sole system of record for ownership, debt and commitments; off-chain services perform post-quantum verification, price aggregation, risk sweeps and proof serving, and every assertion they make must appear inside a signed envelope that the chain has anchored. No off-chain component can move a user's funds."),
  H2("A. Platform Selection"),
  P("Five deployment targets were assessed against the requirements of Section IV (Table III). Ethereum mainnet offers the strongest security and the RWA ecosystem but the highest fees, and real funds are out of scope for a final-year project. A Cosmos application chain could verify ML-DSA natively, but its post-quantum mode is opt-in and stake-weighted, its EVM-compatible accounts remain secp256k1, and with Interchain Security being withdrawn it would need its own validator set. Algorand and QRL provide partial or complete post-quantum signing but lie outside the EVM, where ERC-3643, ERC-4626, OpenZeppelin, the Aave patterns and Ethereum's 43\u201352% share of tokenized RWA value reside [41]."),
  ...TABLE("Deployment Target Assessment", ["Criterion", "Eth. L1", "Arbitrum", "Cosmos app", "Algorand", "QRL"], [
    ["EVM / RWA standards", "yes", "yes", "partial", "no", "no"],
    ["Security inherited", "native", "Ethereum", "own validators", "native", "native"],
    ["Cost per anchor", "high", "low", "low", "low", "low"],
    ["App-layer PQ possible today", "yes", "yes", "yes", "yes", "yes"],
    ["Real funds avoided (testnet)", "Sepolia", "Arb. Sepolia", "testnet", "testnet", "testnet"],
  ], [1450, 700, 760, 820, 660, 650]),
  P("**Arbitrum Sepolia** was selected. As an optimistic rollup it inherits Ethereum's security and roadmap, keeps full EVM compatibility, and makes the per-epoch anchor cheap. Because QORA places post-quantum authentication at the application layer, users are protected today rather than when the base layer migrates, and the anchor is chain-agnostic: when a Falcon precompile ships, moving to direct verification is a change of verifier address rather than a migration. The Solidity target is pinned (solc 0.8.26, optimizer 200 runs, evm_version cancun, verified on Arbitrum Sepolia before any gas figure is published)."),
  H2("B. System Architecture and Stack"),
  P("QORA is a pnpm 9 monorepo with five layers (Fig. 1). The client layer hosts the investor progressive web app and the operations console; the service layer hosts five stateless NestJS services on Node.js 22.16; the package layer contains the cryptographic core and the canonical envelope codec; the contract layer contains the Solidity system of record; and the chain layer is Arbitrum Sepolia, with Anvil, Redis 7 and PostgreSQL 16 provided locally through docker-compose. Table IV lists the stack."),
];

const stackTable = TABLE("Implementation Stack", ["Layer", "Technology (pinned)", "Role in QORA"], [
  ["Cryptography", "PQClean clean C (pinned commit), RustCrypto slh-dsa 0.1.0, Rust 1.81, cc, getrandom 0.2.15", "Six primitives: Falcon-512, ML-DSA-44/65, SLH-DSA-SHA2-128s, ML-KEM-768/1024"],
  ["Runtime bridges", "napi-rs (Node-API v8), wasm-pack \u2192 wasm32-unknown-unknown, wasm-bindgen 0.2.127", "Server addon; in-browser signer; offline pqctl CLI"],
  ["Contracts", "Solidity 0.8.26, Foundry (forge, anvil), OpenZeppelin 5.x, T-REX, ONCHAINID, ETHFALCON (pinned)", "Registry, ERC-3643 tokens, ERC-4626 vault, oracle, lending, anchor, dispute"],
  ["Services", "NestJS, TypeScript, Node.js 22.16 LTS", "pq-verifier, oracle, settlement-rail, risk-engine, anchor-batcher"],
  ["Data", "Redis 7 Streams, PostgreSQL 16", "Epoch and risk queues; double-entry ledger, nonces, key records"],
  ["Clients", "React 18 PWA, viem, IndexedDB", "Investor app with device signing; operations console"],
  ["Verification", "Foundry fuzz/invariant, Halmos, NIST ACVP v1.1.0.43 vectors, headless Chromium", "Contract invariants, symbolic proofs, cryptographic conformance"],
  ["Evaluation & CI", "Python pipeline, forge snapshot, GitHub Actions (pq-native, pq-wasm, pq-conformance)", "Benchmarks, gas curves, regression gates"],
], [1500, 4600, 4340], true);

const method2 = [
  H2("C. Cryptographic Core (M1)"),
  P("M1 implements six primitives as two APIs, a signature API (keygen, sign, verify, metadata) and a KEM API (keygen, encapsulate, decapsulate), and signs bytes, never business objects (Fig. 2). Five schemes are vendored from PQClean's portable *clean* implementations into the crate at a pinned commit with a provenance file recording upstream URL, commit and per-file SHA-256, and compiled by build.rs through the cc crate; SLH-DSA comes from the pure-Rust RustCrypto implementation because PQClean does not provide FIPS 205. The padded Falcon variant is used so that every signature is exactly 666 bytes, which turns every length check into an equality and fixes the dispute calldata size."),
  P("For the browser, the same Rust core is built for wasm32-unknown-unknown with wasm-pack. Because that target provides no libc, the vendored C is compiled freestanding (clang --target=wasm32-unknown-unknown -ffreestanding -nostdlibinc) against project-owned declaration stubs, Rust's compiler builtins supply memcpy and memset, and a small shim provides malloc, free and an exit that traps; CI rejects any header outside the reviewed include roots. For services, a napi-rs addon targeting Node-API v8 exposes pure, stateless functions over byte buffers with asynchronous variants on the libuv thread pool (AsyncTask), so concurrent calls cannot interfere and slow operations never block the event loop. The addon deliberately contains no SLH-DSA signing entry point; root signing happens only in the offline pqctl command-line tool used in the key ceremony."),
  P("Randomness comes from the operating-system CSPRNG natively and from crypto.getRandomValues in WebAssembly, through getrandom, with no user-space generator and no fallback: any failure returns RngFailure and the browser module refuses to initialize. Deterministic seeds needed for conformance vectors are reachable only through a kat feature that fails compilation in optimized builds. Errors cross every boundary as a PqError enum whose variants carry no key, message or signature bytes. M1 Stages 0\u20133 (49 of 102 tasks) are complete: all six primitives native and in WebAssembly, the Node addon, the TypeScript PqCoreApi and the pqctl tool."),
  H2("D. Key Hierarchy and Envelope (M2)"),
  P("Keys form three tiers. Tier 0 is an SLH-DSA-SHA2-128s root held offline, which authorizes key records only and never touches funds; because it is hash-based, recovery survives a structural break in lattice cryptography. Tier 1 holds ML-DSA-65 service keys for the custodian and administration and ML-DSA-44 for the oracle, each with a validity window and scheduled rotation. Tier 2 holds Falcon-512 device keys generated in the browser. PQKeyRegistry.sol stores, per key, its public-key hash, algorithm identifier, role and window [validFrom, validTo]. Rotation registers the successor before retiring the predecessor, and revocation never deletes: it closes the window, so signatures made before revocation remain verifiable, which Section V-E's anchoring makes checkable."),
  P("No signature is ever taken over a raw payload. Every action is a canonical envelope serialized byte-identically by the TypeScript envelope-codec and the Rust core, tested against shared vectors (Table V). The stateless pq-verifier service accepts an envelope only if seven conditions hold: the algorithm is allowed for the action, the signer's key is active and unrevoked, the domain separator matches, the clock is inside the window, the nonce equals the stored value plus one, the signature verifies over the envelope with its signature field zeroed, and the payload hash matches the executed payload. Each failure is rejected at a named check, and the adversarial test suite asserts the name."),
  ...TABLE("Envelope Fields and the Attack Each Removes", ["Field", "Attack prevented"], [
    ["version, algorithm", "ambiguous encoding; downgrade to a retired primitive"],
    ["chainId, contract", "cross-chain and cross-contract replay"],
    ["action", "reuse of a signature for a different action"],
    ["signer", "binding to a PQKeyRegistry record"],
    ["nonce", "same-signer replay (strictly incrementing)"],
    ["validFrom, validTo", "delayed execution (90 s users, 1 h attestations)"],
    ["payloadHash", "substitution of the executed payload"],
  ], [1700, 3340]),
  H2("E. Anchoring, Audit and Dispute (M9)"),
  P("The anchor-batcher consumes accepted envelopes from a Redis stream, computes each leaf as the Keccak-256 of the envelope, and every 60 seconds builds a sorted-pair Merkle tree, the construction OpenZeppelin's audited MerkleProof verifies, so any independent tool can check a proof (Fig. 3). It writes {root, leafCount, epoch} to PQAnchor.sol, which is immutable and non-upgradeable; epochs strictly increase and a root is never overwritten. If the batcher stops, execution is unaffected and the next anchor carries the accumulated leaves with the gap explicit. Users receive {leaf, sibling hashes, epoch} and verify inclusion offline against the chain alone. With anchor cost G_{a} \u2248 43,000 gas, ECDSA cost G_{ec} = 3,000, proof check G_{p} \u2248 22,000, on-chain Falcon G_{fal} \u2248 3.9\u00d710^{6} and a disputed fraction \u03c1, the per-event cost and the break-even are"),
];

const method2b = [
  EQ("g(n) = G_{a} / n + \u03c1 (G_{p} + G_{fal})"),
  EQ("n* = G_{a} / G_{ec} \u2248 43,000 / 3,000 \u2248 14.3"),
  P("so from about fifteen events per epoch the post-quantum system costs less gas per authenticated action than the ECDSA system it replaces. The 43k figure is a budget (21,000 base transaction, about 20,000 for the fresh root slot, plus count, epoch and log) that Experiment A replaces with measured forge snapshots. The dispute path uses ETHFALCON's NIST-compliant ZKNOX_falcon, pinned at commit 7d5ecd41, vendored with provenance, and fed through a separately tested adapter that converts the canonical 897-byte key and 666-byte signature into the verifier's packed form (sixteen coefficients per uint256, key in the NTT domain). It is called only on challenge and is paid by the challenger."),
  H2("F. Asset Registry and Compliance (M3)"),
  P("An asset is a state machine whose LIVE state is the only precondition for minting (Fig. 4). Each Asset record holds its identifier, type (GOLD, TBILL, SUKUK, REIT), custodian, reserveAmount in physical units, attestedSupply, last committed price and timestamp, a strictly increasing attestationSequence and status. A custodian submits an ML-DSA-65 reserve statement; AssetRegistry.sol accepts it only if the signature is valid under an active Tier 1 key, the sequence exceeds the previous one, reserveAmount \u2265 intended supply, and the valuation is fresh. The invariant attestedSupply \u2264 reserveAmount is enforced on every mint and re-checked on every attestation; redemption burns supply first and the custodian lowers the reserve afterwards, so the invariant never breaks even transiently. Overdue re-attestation or a revoked custodian key moves the asset to FROZEN: minting and transfers stop, redemption stays open."),
  ...FIGURE(4, "fig4_asset_fsm.png", "Asset lifecycle in AssetRegistry.sol: supply can exist only in LIVE; FROZEN stops minting and transfer while redemption stays open."),
  P("Ownership tokens implement ERC-3643 through the T-REX suite: an identity registry maps wallets to ONCHAINID contracts holding KYC claims from trusted issuers, and a compliance module is consulted inside every transfer. KYC documents never reach the chain; they are encrypted under ML-KEM-1024 off-chain and only their hash is recorded."),
  H2("G. Vault Accounting (M4)"),
  P("AssetVault.sol is an OpenZeppelin ERC-4626 subclass that holds ERC-3643 units and issues shares. With S shares, A assets and virtual offset \u03c3 = 10^{6} (_decimalsOffset() = 6),"),
  EQ("shares(a) = \u230a a (S + \u03c3) / (A + 1) \u230b"),
  EQ("assets(s) = \u2308 s (A + 1) / (S + \u03c3) \u2309"),
  P("with floor on deposit and ceiling on redemption so every rounding error favours the pool. To force a deposit a to zero shares an attacker must now donate X > a\u03c3 \u2212 1 \u2248 10^{6} a, which turns a PKR 1,000 attack into a PKR 1 billion one. The four conversion functions are overridden to fix rounding direction explicitly; share monotonicity and \"no caller redeems more than contributed plus pro-rata yield\" are fuzzed over 10^{6} randomized deposit\u2013donate\u2013withdraw sequences in Foundry and proved symbolically with Halmos."),
  H2("H. Oracle and Proof of Reserve (M5)"),
  P("A price is treated as a decision, and the order of checks is the security property (Fig. 5). Node workers poll five independent sources in parallel with a 3 s timeout, drop stale feeds, require a quorum k \u2265 3, take the median, and commit the round only if"),
  EQ("|P_{med} \u2212 P_{TWAP}| / P_{TWAP} \u2264 \u03b4 = 0.10"),
  P("against the 30-minute time-weighted average, with strictly increasing round identifier and timestamp. The median bounds a minority of corrupted feeds; the TWAP gate bounds a correlated majority, because an attacker must hold a manipulated price for 30 minutes. Rounds are signed with ML-DSA-44 and committed to PriceOracle.sol, which re-checks the submitting role and monotonicity. On any failure no price is committed: once a round exceeds the asset's heartbeat, borrowing and new locks freeze while repayment and withdrawal stay open, so a frozen oracle can never create a liquidation."),
  ...FIGURE(5, "fig5_oracle.png", "Oracle decision pipeline (M5). The order of checks is the security property."),
  ...TABLE("Risk Parameters per Asset Class", ["Asset", "LTV \u03b8", "Threshold \u03bb", "Bonus \u03b2_{max}", "Heartbeat"], [
    ["Gold (reference)", "60%", "75%", "5%", "60 s"], ["Treasury bill", "75%", "85%", "3%", "300 s"], ["Sukuk", "65%", "80%", "4%", "300 s"], ["Fractional REIT", "40%", "60%", "10%", "3600 s"],
  ], [1300, 800, 1000, 1000, 940]),
  H2("I. Settlement Rail (M8)"),
  P("The settlement rail is a NestJS service behind a single IFiatRail interface. In the sandbox it implements a mock PKR rail over a double-entry ledger in PostgreSQL 16, in which every movement is a balanced debit and credit committed in one transaction, so a partial movement cannot persist; it credits test-net USDC and supports deterministic delays and injected failures so that half-completed payments can be tested. Deposits flow PKR \u2192 ledger credit \u2192 USDC \u2192 vault shares and withdrawals reverse the path; each step is a signed, anchored envelope. It is the only simulated component, and replacing it with a licensed bank, Raast or card-issuing partner is a configuration change behind the same interface."),
  H2("J. Risk Engine and Lending (M6, M7)"),
  P("For a position with collateral quantities q_{i}, committed prices p_{i} and debt D, CollateralManager computes"),
  EQ("HF = \u03a3 q_{i} p_{i} \u03bb_{i} / D,   capacity = \u03a3 q_{i} p_{i} \u03b8_{i} \u2212 D"),
  P("and a borrow is admitted only if the post-state HF \u2265 1.15 (Fig. 6). The off-chain risk engine, a pool of Redis-Streams workers, recomputes HF on every accepted price round and proposes actions, but every liquidation re-derives HF on-chain and reverts if the engine was wrong. Interest accrues through a single global borrow index, so 10,000 positions cost the same gas as one, with a two-slope rate on utilization U (kink at U* = 0.8, slopes 4% and 75%):"),
  EQ("I_{t+\u0394t} = I_{t} (1 + r(U) \u0394t / T_{year}),   D_{u}(t) = b_{u} I_{t}"),
  ...FIGURE(6, "fig6_hf_bands.png", "Health-factor state bands driving the risk engine, reserve buffer and liquidator."),
  P("When 0.95 \u2264 HF < 1.00, ReserveBuffer.sol opens a claim for the shortfall D(1 \u2212 HF) and a 6-hour grace timer; the claim is an accounting reservation, released at zero cost if HF recovers above 1.00 and realized only if the timer expires. Claims per epoch are capped at \u03ba = 40% of the buffer, which is funded from the interest spread and never from depositors; an empty buffer degrades exactly to the control behaviour. Below HF 0.95, Liquidator.sol lets a liquidator repay x \u2264 \u03c6D with \u03c6 = 0.5 and seize collateral worth x(1 + \u03b2(t)), where the bonus decays linearly over 20 blocks from \u03b2_{max} to 0.6\u03b2_{max} (5% to 3% for gold). A position handed over at HF 0.95 returns to HF \u2248 1.11; below 0.90 the position is closed fully and residual bad debt is socialized from the buffer first."),
  H2("K. Client Applications (M10)"),
  P("The investor app is a React 18 progressive web app built with viem. It loads M1's WebAssembly package, generates the Falcon-512 device key locally, stores it in IndexedDB, and builds and signs envelopes in the browser, so no service ever holds a user key. The operations and custodian console submits ML-DSA-65 reserve attestations and monitors oracle health, buffer utilization and anchor epochs."),
  H2("L. Evaluation and Verification (M11)"),
  P("Every claim is measured against an otherwise identical ECDSA-only build selected by one compile flag, and the lending experiments against the same pool parameterized as Aave V3 without the buffer (Table VII). Cryptographic conformance draws on NIST ACVP vectors (v1.1.0.43) for ML-DSA, ML-KEM and SLH-DSA, NIST Round-3 KATs for Falcon (FIPS 206 has no ACVP set yet), PQClean KATs, a pqcrypto differential oracle, project golden vectors shared by Rust, TypeScript, WebAssembly and Foundry, negative and malformed-input suites, and cross-runtime checks in both directions. Benchmarks run on a reproducible CI runner (D1), a fixed workstation (D2) and a physical mid-range Android handset (A1), with hardware identity scanned rather than typed. Contract correctness relies on Foundry invariants (for example attestedSupply \u2264 reserve and post-borrow HF \u2265 1.15) and Halmos proofs. Hypotheses are falsifiable, and a null result is reported as a finding."),
];

const evalTable = TABLE("Experiments", ["Experiment", "Measurement", "Answers"], [
  ["A: primitives & gas", "keygen/sign/verify time and sizes, 6 primitives, D1/D2/A1, native and WASM; gas per event at n = 1\u20134,096 from forge snapshots", "RQ1, RQ3"],
  ["Latency", "p50/p95 end-to-end deposit and borrow flows at 1, 10, 100 concurrent users", "RQ2"],
  ["B: buffer", "liquidations avoided, bad debt, peak buffer use, value returned; 2020 and 2024 gold drawdowns and 10,000 Monte Carlo GBM paths at 1\u03c3, 2\u03c3, 3\u03c3 vs Aave-V3 control", "RQ4"],
  ["C: oracle", "1, 2, 3 malicious sources, stale source, large deviation; assert the named check that rejects each", "oracle design"],
  ["E: scale", "risk sweep latency at 10,000 open positions; constant-cost index and anchor", "scalability"],
], [1700, 6900, 1840], true);

const results = [
  H1("Expected Results"),
  P("The project is expected to produce working artefacts that can be installed, used and inspected, together with the measurements that answer RQ1\u2013RQ4 (Table VIII)."),
];
const resultsTable = TABLE("Expected Deliverables", ["Deliverable", "What will be seen"], [
  ["Investor mobile PWA", "Installable on Android/desktop: KYC onboarding, portfolio of tokenized gold, T-bill, Sukuk and property shares, invest from PKR 1,000, borrow/repay with live health factor and buffer status, withdraw to PKR, and an offline proof viewer that verifies any past action against the chain"],
  ["Operations & custodian console", "Submit and track ML-DSA-65 reserve attestations; asset LIVE/FROZEN status; oracle rounds and rejected feeds; buffer utilization; anchor epochs and pending leaves"],
  ["Backend services", "pq-verifier, oracle, settlement-rail, risk-engine and anchor-batcher running under docker-compose with Redis and PostgreSQL, logging every named rejection"],
  ["Smart contracts", "Registry, ERC-3643 token suite, ERC-4626 vault, PriceOracle, LendingPool, ReserveBuffer, Liquidator, PQKeyRegistry and immutable PQAnchor deployed on Arbitrum Sepolia with verified source"],
  ["pq-core package and pqctl", "Reusable npm package with native Node addon and browser WASM for six NIST primitives; offline CLI for the SLH-DSA root ceremony; conformance report per primitive"],
  ["Evaluation report and dataset", "Gas-per-event curve with measured break-even, primitive timing on desktop and Android, latency distributions, buffer-versus-control liquidation outcomes, oracle rejection matrix, all reproducible from the Python pipeline"],
  ["Milestone demonstrations", "MS1: a gold lot registered LIVE against an attested reserve; MS2: PKR 5,000 deposit to shares with an offline-verified proof; MS3: borrow, price drop, buffer or liquidation with zero bad debt; MS4: every RQ answered"],
], [2600, 7840], true);
const resultsTail = [
  P("Expected quantitative outcomes are stated as hypotheses: a measured break-even near the projected fourteen events per epoch; Falcon-512 signing in the browser of a mid-range Android device within interactive latency; and fewer transient-shock liquidations than the Aave-V3 control with no increase in bad debt at 3\u03c3."),
];

const sdgs = [
  H1("Sustainable Development Goals"),
  P("QORA's inclusion and transparency objectives map onto five targets of the UN Sustainable Development Goals (Table IX)."),
  ...TABLE("SDG Alignment", ["SDG", "Target", "Contribution"], [
    ["1 No Poverty", "1.4", "fractional ownership of gold, T-bills, Sukuk and property from PKR 1,000, plus micro-loans against it"],
    ["5 Gender Equality", "5.a", "mobile-first, low-minimum accounts against an account gap of 11.9% (women) vs 42.3% (men) [39]"],
    ["8 Decent Work & Growth", "8.10", "investing, borrowing and lending in one platform with PKR in and out"],
    ["9 Industry & Innovation", "9.3", "asset-backed micro-credit without selling, with protection from unfair liquidation"],
    ["16 Strong Institutions", "16.6", "every action anchored and verifiable by anyone; custodian reserves publicly checkable"],
  ], [1350, 600, 3090]),
];

const timeline = [
  H1("Timeline"),
  P("Development spans 24 weeks in four phases, each closing with a demonstrable milestone gate (Fig. 7, Fig. 8). The critical path is M1 \u2192 M2, because nearly every module consumes the envelope; M1 is already built."),
];

const conclusion = [
  H1("Conclusion"),
  P("The review showed that post-quantum standards exist but are absent from deployed tokenization, that no blockchain offers post-quantum authentication that is default, EVM-compatible and affordable today, and that tokenization and lending remain hostile to small users. QORA answers with application-layer post-quantum authentication anchored for a fixed cost per minute on Arbitrum Sepolia, compliant fractional ownership from PKR 1,000, and lending designed for micro-positions, and it commits to measuring every claim against an identical ECDSA build."),
];

const REFS = [
  "NIST, \"Module-Lattice-Based Key-Encapsulation Mechanism Standard,\" FIPS 203, Aug. 2024.",
  "NIST, \"Module-Lattice-Based Digital Signature Standard,\" FIPS 204, Aug. 2024.",
  "NIST, \"Stateless Hash-Based Digital Signature Standard,\" FIPS 205, Aug. 2024.",
  "DigiCert, \"Quantum-ready FN-DSA (FIPS 206) nears draft approval from NIST,\" 2025.",
  "NIST, \"Transition to Post-Quantum Cryptography Standards,\" NIST IR 8547 (initial public draft), Nov. 2024.",
  "M. Mosca, \"Cybersecurity in an era with quantum computers: Will we be ready?\" IEEE Security & Privacy, vol. 16, no. 5, 2018.",
  "C. Gidney, \"How to factor 2048 bit RSA integers with less than a million noisy qubits,\" arXiv:2505.15917, 2025.",
  "R. Babbush et al., \"Securing elliptic curve cryptocurrencies against quantum vulnerabilities: Resource estimates and mitigations,\" arXiv:2603.28846, 2026.",
  "M. Mosca and M. Piani, \"Quantum Threat Timeline Report 2025,\" Global Risk Institute, 2026.",
  "DigiCert, \"Quantum security deployment remains stuck,\" press release, Jul. 2026.",
  "T. M. Fern\u00e1ndez-Caram\u00e9s and P. Fraga-Lamas, \"Towards post-quantum blockchain: A review on blockchain cryptography resistant to quantum computing attacks,\" IEEE Access, vol. 8, pp. 21091\u201321116, 2020.",
  "The QRL Foundation, \"What is QRL,\" documentation, docs.theqrl.org.",
  "Algorand Foundation, \"State Proofs\" (developer docs) and \"Algorand targets broad quantum resilience by 2027,\" 2025\u20132026.",
  "QR Index, \"Cosmos,\" qrindex.org/projects/cosmos.",
  "Cosmos Labs, \"Ledger Security 2026.1\" (Cosmos SDK v0.55.0, CometBFT v0.40.0, cosmos/kms v0.1.0), cosmos.network, Oct. 2026.",
  "Cosmos Hub Forum, \"Remove ICS from the Cosmos Hub,\" forum.cosmos.network, 2026.",
  "ZKNox, \"ETHFALCON: Implementation of FALCON and its variants for Ethereum,\" github.com/ZKNoxHQ/ETHFALCON, commit 7d5ecd41.",
  "\"EIP-7885: Precompile for NTT operations,\" eips.ethereum.org.",
  "Ethereum Foundation, \"Post-quantum cryptography on Ethereum,\" ethereum.org; CoinDesk, Mar. 2026.",
  "R. C. Merkle, \"A digital signature based on a conventional encryption function,\" in Proc. CRYPTO, 1987.",
  "S. Haber and W. S. Stornetta, \"How to time-stamp a digital document,\" J. Cryptology, vol. 3, no. 2, 1991.",
  "M. Alvarez et al., \"BoLD: Fast and cheap dispute resolution,\" in Proc. AFT, LIPIcs vol. 316, 2024.",
  "\"Post-quantum-resilient audit evidence for long-lived regulated systems,\" arXiv:2512.00110, 2025.",
  "OECD, \"The Tokenisation of Assets and Potential Implications for Financial Markets,\" 2020.",
  "J. Lebrun et al., \"ERC-3643: T-REX \u2014 Token for Regulated EXchanges,\" eips.ethereum.org/EIPS/eip-3643, 2021.",
  "OpenZeppelin, \"ERC-4626 \u2014 inflation attack and virtual offset,\" docs.openzeppelin.com/contracts/erc4626.",
  "Bank for International Settlements, Annual Economic Report 2023, ch. III, \"Blueprint for the future monetary system.\"",
  "Eco, \"BUIDL deep dive 2026,\" 2026.",
  "The Block, \"DeFi lending hits record \u2026 Aave, Maple and Morpho lead,\" 2026.",
  "D. Perez, S. M. Werner, J. Xu and B. Livshits, \"Liquidations: DeFi on a knife-edge,\" in Proc. Financial Cryptography, 2021.",
  "K. Qin, L. Zhou, P. Gamito, P. Jovanovic and A. Gervais, \"An empirical study of DeFi liquidations: Incentives, risks, and instabilities,\" in Proc. ACM IMC, 2021.",
  "KuCoin Research, \"Tokenized real-world assets in 2026\" (RWA.xyz data, Oct. 2026).",
  "InvestaX, \"Q1 2026 real world asset tokenization market report,\" 2026.",
  "Ledger Insights, \"McKinsey estimates tokenization will be less than $2 trillion by 2030\"; Stobox, \"RWA market size 2030,\" 2025\u20132026.",
  "The Standard, \"Pakistan ranked among top 3 countries globally for crypto adoption\" (Chainalysis 2025).",
  "Arab News, \"Pakistan signs agreement with Binance to explore tokenization of up to $2 billion assets,\" Dec. 2025.",
  "The News, \"FY26 remittances hit $41.6bn,\" Jul. 2026.",
  "Arab News, \"Pakistan central bank says 92 percent of retail payments made digitally\" (SBP Q3 FY26), 2026.",
  "World Bank, \"Pakistan financial and digital inclusion fact sheet,\" Global Findex 2025; Business Recorder, 2026.",
  "The Block, \"Hacker steals over $100 million from Mango Markets,\" Oct. 2022.",
  "Crypto Briefing, \"Ethereum dominates tokenized RWA market,\" 2026; Value the Markets, 2026.",
];
const refs = [H1("References"), ...REFS.map((r, i) => new Paragraph({ spacing: { after: 20 }, indent: { left: 360, hanging: 360 }, alignment: AlignmentType.LEFT,
  children: [new TextRun({ text: `[${i + 1}]\t`, size: 16 }), new TextRun({ text: r, size: 16 })], tabStops: [{ type: TabStopType.LEFT, position: 360 }] }))];

// =====================================================================  ASSEMBLE (wide figures/tables sit in one-column bands)
const doc = new Document({
  creator: "Fahad Naseer, Hassan Attique, Fawaz Asif",
  title: "QORA Technical Proposal",
  styles: {
    default: { document: { run: { font: FONT, size: 20 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { font: FONT, size: 20, smallCaps: true }, paragraph: { alignment: AlignmentType.CENTER, spacing: { before: 180, after: 80 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { font: FONT, size: 20, italics: true }, paragraph: { spacing: { before: 100, after: 40 }, outlineLevel: 1 } },
    ],
  },
  numbering: {
    config: [
      { reference: "bul", levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 300, hanging: 200 } } } }] },
      { reference: "h1", levels: [{ level: 0, format: LevelFormat.UPPER_ROMAN, text: "%1.", alignment: AlignmentType.LEFT }] },
    ],
  },
  sections: [
    { properties: { page: { size: PAGE, margin: MARGIN } }, children: titleBlock },
    C2([...abstract, ...intro, ...market, ...lit, ...problem, ...method1]),
    C1([...FIGURE(1, "fig1_architecture.png", "QORA layered architecture. Off-chain layers hold work; the contract layer and the chain hold authority over funds, ownership and commitments.", true), ...stackTable]),
    C2([...FIGURE(2, "fig2_pqcore.png", "M1 build pipeline: one Rust core over vendored PQClean C and pure-Rust SLH-DSA, projected into a Node-API addon, a freestanding WebAssembly signer and an offline CLI."), ...method2]),
    C1([...FIGURE(3, "fig3_pipeline.png", "Envelope lifecycle. Verification happens off-chain; only execution and the per-epoch root touch the chain, and the NIST-compliant Falcon verifier runs only on challenge.", true)]),
    C2([...method2b]),
    C1([...evalTable, ...results, ...resultsTable]),
    C2([...resultsTail, ...sdgs, ...timeline]),
    C1([...FIGURE(7, "fig7_modules.png", "Modules grouped into four delivery leaves; module numbers are component names, leaves are build order, each leaf closes on a milestone gate.", true),
        ...FIGURE(8, "fig8_gantt.png", "Development timeline over 24 weeks with milestone gates MS1\u2013MS4.", true)]),
    C2([...conclusion, ...refs]),
  ],
});
// sanity: renumber H1 headings with roman numerals in text (IEEE style) except References
Packer.toBuffer(doc).then((buf) => {
  const out = path.join(__dirname, "..", "QORA_Technical_Proposal.docx");
  fs.writeFileSync(out, buf);
  console.log("wrote", out, "figures:", figN, "tables:", tabN, "equations:", eqn);
});
