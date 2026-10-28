// QORA proposal defense deck v2.
// Black background, Bodoni MT headings, DM Sans body. Asset tokens (gold, bond, Sukuk, real estate,
// PKR, USDC, lock) travel between slides through Morph (objects named "!!...").
// On-slide wording is condensed only from "PQC presentation drafts.pdf"; connectors and detail go to notes.
const pptxgen = require("pptxgenjs");
const path = require("path");
const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5
pres.title = "QORA";

const WHITE = "FFFFFF", MUTED = "A8A8A8", FAINT = "6A6A6A", RULE = "2C2C2C", CARD = "0E0E0E", CARD2 = "181818";
const GOLD = "E2B544";
const HEAD = "Bodoni MT", BODY = "DM Sans";
const ART = (f) => path.join(__dirname, "art5", f);

// ---------- primitives
const T = (s, text, o) => s.addText(text, Object.assign({ fontFace: BODY, color: WHITE, margin: 0, isTextBox: true, valign: "top" }, o));
const R = (text, o) => ({ text, options: o || {} });
const B = (text) => ({ text, options: { bold: true } });
const G = (text) => ({ text, options: { bold: true, color: GOLD } });
const TOK = { gold: "gold_gold", bond: "bond_silver", sukuk: "sukuk_silver", estate: "estate_silver", lock: "lock_gold", pkr: "pkr_silver", usdc: "usdc_silver", blank: "blank_silver", blankg: "blank_gold", dim: "blank_silver_dim", lockS: "lock_silver" };
function tok(s, kind, x, y, d, name) {
  s.addImage(Object.assign({ path: ART(TOK[kind] + ".png"), x, y, w: d, h: d }, name ? { objectName: `!!${name}` } : {}));
}
const ingot = (s, x, y, w, name) => s.addImage({ path: ART("ingot_gold.png"), x, y, w, h: w * 0.578, objectName: `!!${name || "ingot"}` });
let n = 0;
const seen = new Set();
function slide(section, opts = {}) {
  if (!seen.has(section)) { pres.addSection({ title: section }); seen.add(section); }
  const s = pres.addSlide({ sectionTitle: section });
  s.background = { color: "000000" };
  n++;
  if (!opts.noPage) T(s, String(n), { x: 12.3, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: FAINT, align: "right", objectName: "!!pageno" });
  return s;
}
function head(s, title, kicker, o = {}) {
  if (kicker) T(s, kicker.toUpperCase(), { x: o.x || 0.6, y: 0.48, w: 10, h: 0.3, fontSize: 11, bold: true, color: GOLD, charSpacing: 4, objectName: "!!kicker" });
  T(s, title, { x: o.x || 0.6, y: 0.78, w: o.w || 11.0, h: 0.8, fontFace: HEAD, fontSize: o.size || 34, objectName: "!!title" });
}
const src = (s, t) => T(s, t, { x: 0.6, y: 7.0, w: 11, h: 0.3, fontSize: 10, color: FAINT });
const rule = (top) => ({ border: [{ type: "none" }, { type: "none" }, { pt: top ? 1.5 : 0.75, color: top ? GOLD : RULE }, { type: "none" }] });
function table(s, header, rows, o) {
  const H = header.map((h, i) => ({ text: h, options: Object.assign({ bold: true, fontSize: 12, color: MUTED, valign: "bottom", align: (o.align && o.align[i]) || "left" }, rule(true)) }));
  const body = rows.map((r) => r.map((c, j) => ({ text: c, options: Object.assign({ fontSize: o.fontSize || 14, color: WHITE, valign: "middle", align: (o.align && o.align[j]) || "left" }, (o.colStyle && o.colStyle[j]) || {}, rule(false)) })));
  s.addTable([H, ...body], { x: o.x, y: o.y, w: o.w, colW: o.colW, rowH: o.rowH || 0.5, fontFace: BODY, margin: o.margin || [4, 10, 4, 0], objectName: o.name });
}
function card(s, x, y, w, h, name) { s.addShape(pres.shapes.ROUNDED_RECTANGLE, Object.assign({ x, y, w, h, rectRadius: 0.1, fill: { color: CARD }, line: { color: RULE, width: 1 } }, name ? { objectName: `!!${name}` } : {})); }
const label = (s, t, x, y, w, color) => T(s, t.toUpperCase(), { x, y, w: w || 7, h: 0.28, fontSize: 11, bold: true, color: color || GOLD, charSpacing: 3 });
function bullets(s, items, o) {
  const runs = [];
  items.forEach((it, i) => {
    const parts = Array.isArray(it) ? it : [R(it)];
    parts.forEach((p, k) => {
      const opt = Object.assign({}, p.options);
      if (k === 0) opt.bullet = { code: "25CF" };
      if (k === parts.length - 1 && i < items.length - 1) opt.breakLine = true;
      opt.paraSpaceAfter = 6;
      runs.push({ text: p.text, options: opt });
    });
  });
  T(s, runs, Object.assign({ fontSize: 15 }, o));
}
function stat(s, x, y, w, value, lab, note, size) {
  T(s, value, { x, y, w, h: 0.95, fontFace: HEAD, fontSize: size || 50, color: GOLD, valign: "bottom" });
  T(s, note ? [R(lab, { breakLine: true }), R(note, { color: MUTED, fontSize: 13 })] : lab, { x, y: y + 1.02, w, h: 0.75, fontSize: 16 });
}
function chips(s, items, x, y, w, h, fs, o = {}) {
  const gap = 0.12, cw = (w - gap * (items.length - 1)) / items.length;
  items.forEach((t, i) => {
    const cx = x + i * (cw + gap), on = o.active === i + (o.start || 0);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: cx, y, w: cw, h, rectRadius: 0.08, fill: { color: on ? "2A2110" : CARD2 }, line: { color: on ? GOLD : RULE, width: on ? 1.5 : 1 }, objectName: `!!chip${o.key || ""}${i}` });
    T(s, [R(String(i + 1 + (o.start || 0)), { color: GOLD, bold: true, breakLine: true }), R(t, { color: on || o.active === undefined ? WHITE : MUTED })], { x: cx + 0.08, y: y + 0.06, w: cw - 0.16, h: h - 0.12, fontSize: fs || 12, align: "center", valign: "middle", objectName: `!!chipt${o.key || ""}${i}` });
  });
  return (i) => ({ x: x + i * (cw + gap) + cw / 2, y });
}
function miniTable(s, rows, x, y, w, colW, rowH, fs) {
  const rb = { border: [{ type: "none" }, { type: "none" }, { pt: 0.5, color: RULE }, { type: "none" }], valign: "middle" };
  s.addTable(rows.map(([a, b]) => [
    { text: a, options: Object.assign({ bold: true, color: WHITE, fontSize: fs || 13 }, rb) },
    { text: b, options: Object.assign({ color: MUTED, fontSize: fs || 13 }, rb) },
  ]), { x, y, w, colW, rowH: rowH || 0.34, fontFace: BODY, margin: [2, 6, 2, 0] });
}
const quote = (s, runs, name) => T(s, runs, { x: 1.4, y: 3.4, w: 10.5, h: 2.4, fontFace: HEAD, fontSize: 30, italic: true, align: "center", valign: "middle", objectName: `!!${name || "quote"}` });

// =====================================================================  1 Title
let s = slide("Title", { noPage: true });
["gold", "bond", "sukuk", "estate"].forEach((k, i) => tok(s, k, 6.05 + i * 0.03, 1.35, 1.25, k));
ingot(s, 4.92, 0.95, 3.5);
T(s, "QORA", { x: 1.5, y: 3.15, w: 10.33, h: 1.35, fontFace: HEAD, fontSize: 88, align: "center", charSpacing: 26 });
T(s, "Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets", { x: 0.5, y: 4.6, w: 12.33, h: 0.5, fontSize: 19, color: MUTED, align: "center" });
s.addNotes("QORA: Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets. Next click: the bar is tokenized into gold, treasury bills, Sukuk and property shares.");

// =====================================================================  2 Introduction
s = slide("Introduction");
s.addImage({ path: ART("ingot_gold.png"), x: 9.9, y: 1.6, w: 0.02, h: 0.01, objectName: "!!ingot", transparency: 100 });
head(s, "Introduction");
[["gold", "gold"], ["bond", "treasury bills"], ["sukuk", "Sukuk"], ["estate", "property shares"]].forEach(([k, cap], i) => {
  const x = 7.15 + i * 1.45;
  tok(s, k, x, 0.75, 1.05, k);
  T(s, cap, { x: x - 0.3, y: 1.85, w: 1.65, h: 0.35, fontSize: 13, color: MUTED, align: "center" });
});
[
  ["Invest", [R("in real-world assets, starting from as little as "), B("PKR 1,000")]],
  ["Borrow", [R("against their holdings "), B("without selling them")]],
  ["Lend", [R("into the platform’s pool and "), B("earn a return")]],
  ["Transact", [R("deposit in PKR, "), B("USDC for investing and lending"), R(", converted back to PKR when they withdraw")]],
].forEach(([k, runs], i) => {
  const y = 2.55 + i * 0.85;
  T(s, k, { x: 0.6, y, w: 2.2, h: 0.6, fontFace: HEAD, fontSize: 26, color: GOLD, valign: "middle" });
  T(s, runs, { x: 2.9, y, w: 9.8, h: 0.6, fontSize: 18, valign: "middle" });
});
T(s, [R("Every transaction "), G("signed with post-quantum cryptography"), R(" and permanently recorded on the blockchain.")], { x: 0.6, y: 6.25, w: 12, h: 0.5, fontSize: 18 });
s.addNotes("QORA is a post-quantum secured platform that lets everyday users invest in real-world assets, such as gold, treasury bills, Sukuk and property shares, starting from as little as PKR 1,000. Each asset is held by a verified custodian and represented on the blockchain as small digital units. Users can borrow against their holdings without selling them, while other users lend into the platform's pool and earn a return. Users deposit in PKR, converted into USDC, and converted back to PKR when they withdraw; the platform is designed to integrate with card payment networks such as Mastercard. Every transaction is signed with post-quantum cryptography and permanently recorded on the blockchain.\n\nBridge: We've seen what QORA does. Now the question is whether the market is ready for it.");

// =====================================================================  Market
s = slide("Market Landscape & Opportunity");
head(s, "The Global Shift: Real Assets Are Moving On-Chain", "Market Landscape & Opportunity");
stat(s, 0.6, 1.95, 3.9, "$39.02B", "Tokenized RWAs on public blockchains", "Oct 2026");
stat(s, 4.7, 1.95, 3.9, "5.19M", "Wallets holding tokenized assets");
stat(s, 0.6, 3.95, 3.9, "~266%", "Market growth in 2025");
stat(s, 4.7, 3.95, 3.9, "+30%", "Growth in Q1 2026 alone", "$21B → $27.5B");
["gold", "bond", "sukuk", "estate"].forEach((k, i) => tok(s, k, 8.95 + i * 0.95, 4.75 - i * 0.82, 1.0, k));
T(s, "Tokenization is no longer an experiment.", { x: 0.6, y: 6.15, w: 12, h: 0.5, fontFace: HEAD, fontSize: 24, italic: true });
src(s, "Sources: RWA.xyz via KuCoin · InvestaX");
s.addNotes("In about 18 months the market went from roughly $10B to $39B, nearly 4x. Growth is speeding up: 30% in a single quarter. The 5.19 million wallets show this isn't only institutions.\n\nConnector: 5 million people worldwide already hold tokenized assets. Where is the next wave of users? One of the strongest answers is Pakistan.");

s = slide("Market Landscape & Opportunity");
head(s, "Pakistan: A Crypto-Ready Nation", "Market Landscape & Opportunity");
stat(s, 0.6, 1.95, 3.9, "#3", "Global crypto adoption rank", "behind only India and the US");
stat(s, 4.7, 1.95, 3.9, "#2", "Retail-size crypto transactions");
stat(s, 0.6, 3.95, 3.9, "$2B", "Govt–Binance tokenization MoU", "T-bills, bonds, commodities");
stat(s, 4.7, 3.95, 3.9, "$41.6B", "Workers’ remittances, FY26", "record, +8.6%");
["gold", "bond", "sukuk", "estate"].forEach((k, i) => tok(s, k, 13.6, 1.0 + i * 1.2, 1.0, k)); // assets leave to the right
tok(s, "pkr", 9.0, 3.2, 1.35, "pkr");
tok(s, "usdc", 11.2, 3.2, 1.35, "usdc");
T(s, "⇄", { x: 10.35, y: 3.35, w: 0.85, h: 0.9, fontSize: 40, color: GOLD, align: "center", valign: "middle" });
T(s, "PKR ↔ USD flow", { x: 9.0, y: 4.75, w: 3.55, h: 0.4, fontSize: 15, color: MUTED, align: "center" });
T(s, [R("Users are already on-chain; they just lack access to "), B("real, asset-backed investments"), R(".")], { x: 0.6, y: 6.15, w: 12, h: 0.5, fontFace: HEAD, fontSize: 22, italic: true });
src(s, "Sources: Chainalysis 2025 via The Standard · Arab News · The News · SBP via The News");
s.addNotes("Being #2 in retail-size transactions means Pakistani users trade in small amounts, matching QORA's PKR 1,000 minimum. The $2B MoU covers treasury bills, bonds and commodities, the same asset classes QORA tokenizes. $41.6B in remittances a year is a huge, steady PKR to USD flow; QORA's PKR to USDC to PKR rail is built for exactly this kind of conversion.\n\nConnector: People want in, the government is moving, and money is flowing. The other half of what QORA offers is lending.");

s = slide("Market Landscape & Opportunity");
head(s, "Lending: The Engine of On-Chain Finance", "Market Landscape & Opportunity");
stat(s, 0.6, 1.95, 3.9, "$1T", "Aave cumulative lending volume", "first in DeFi history", 58);
stat(s, 4.75, 1.95, 3.9, "$1B+", "RWAs deposited as collateral on Aave", "", 58);
stat(s, 8.9, 1.95, 3.9, "80%+", "Lending’s share of on-chain DeFi activity", "", 58);
tok(s, "gold", 0.9, 4.35, 1.2, "gold");
T(s, "collateral", { x: 0.6, y: 5.6, w: 1.8, h: 0.35, fontSize: 13, color: MUTED, align: "center" });
s.addShape(pres.shapes.LINE, { x: 2.35, y: 4.95, w: 1.5, h: 0, line: { color: GOLD, width: 2, endArrowType: "triangle" } });
tok(s, "usdc", 4.05, 4.35, 1.2, "usdc");
T(s, "loan", { x: 3.75, y: 5.6, w: 1.8, h: 0.35, fontSize: 13, color: MUTED, align: "center" });
T(s, [R("QORA brings this model down to "), G("micro-scale (PKR 1,000)"), R(" and pairs it with tokenized gold, T-bills and Sukuk.")], { x: 6.0, y: 4.45, w: 6.7, h: 1.1, fontSize: 20, valign: "middle" });
src(s, "Sources: The Block via TradingView · BlockEden");
s.addNotes("Aave, the lending model QORA's design follows, has processed $1 trillion in loans. More than 80% of on-chain finance activity is lending. $1B+ of real-world assets are already used as collateral, so lending against RWAs is proven to work.\n\nConnector: The market opportunity is clear. How have existing platforms, standards and research tried to build this, and what have they missed?");

// =====================================================================  Literature review: one rail, one travelling token
const RAIL = [["3.1", "Digital, Legal, Accessible"], ["3.2", "Useful"], ["3.3", "Last"], ["3.4", "Affordable"]];
const RX = [1.9, 5.1, 8.3, 11.5], RY = 2.2;
function rail(s, at, done) {
  s.addShape(pres.shapes.LINE, { x: RX[0], y: RY, w: RX[3] - RX[0], h: 0, line: { color: RULE, width: 2 }, objectName: "!!railbase" });
  const reach = Math.min(at, 3);
  if (reach > 0) s.addShape(pres.shapes.LINE, { x: RX[0], y: RY, w: RX[reach] - RX[0], h: 0, line: { color: GOLD, width: 2 }, objectName: "!!railgold" });
  RAIL.forEach(([id, lab], i) => {
    const lit = i <= at || done;
    s.addShape(pres.shapes.OVAL, { x: RX[i] - 0.11, y: RY - 0.11, w: 0.22, h: 0.22, fill: { color: lit ? GOLD : "3A3A3A" }, line: { type: "none" }, objectName: `!!railnode${i}` });
    T(s, [R(id + "  ", { bold: true, color: lit ? GOLD : FAINT }), R(lab, { color: i === at ? WHITE : FAINT })], { x: RX[i] - 1.6, y: RY + 0.36, w: 3.2, h: 0.35, fontSize: 13, align: "center", objectName: `!!raillab${i}` });
  });
  if (at >= 0 && at <= 3) tok(s, at >= 2 ? "lock" : "gold", RX[at] - 0.32, RY - 0.32, 0.64, "traveller");
  if (done) tok(s, "lock", RX[3] + 0.5, RY - 0.32, 0.64, "traveller");
}
const litHead = (s, title) => head(s, title, "Literature Review");
const lit = (s, rows, fs, rowH) => table(s, ["Year", "Work", "Idea / Contribution"], rows, {
  x: 0.6, y: 2.95, w: 12.1, colW: [1.25, 3.4, 7.45], fontSize: fs || 14, rowH: rowH || 0.55,
  colStyle: [{ bold: true, color: GOLD }, { bold: true }, {}], name: "littable",
});
const LIT = [
  { title: "Making Ownership Digital, Legal and Accessible",
    q: [R("How do you turn ownership of a real asset into a digital record that is also "), G("legal"), R("?")],
    rows: [
      ["2018", "T-REX by Tokeny", [R("The "), B("first token designed for regulated securities"), R(". Links every holder to a verified digital identity.")]],
      ["2020", "OECD, The Tokenisation of Assets", [R("Could improve liquidity, settlement speed and access, but "), B("still depends on a trusted custodian"), R(" and a digital form of cash.")]],
      ["2021", "ERC-3643 standard", [R("Identity registry and compliance rules "), B("inside the token itself"), R(". Receiver hasn’t passed KYC: automatically rejected.")]],
      ["2022", "ERC-4626 + OpenZeppelin virtual offset", [R("Investors deposit an asset and receive proportional shares. "), B("Virtual shares and assets"), R(": the attack becomes unprofitable.")]],
      ["2023", "BIS, Unified Ledger", [R("Tokenized money and tokenized assets live together, so "), B("payment and asset delivery settle in one step"), R(".")]],
      ["2024", "BlackRock BUIDL", [R("Tokenized US Treasury fund, "), B("~$2.8B"), R(". Full institutional adoption.")]],
    ], fs: 14, rh: 0.58,
    notes: "Our story starts with the most basic question: how do you turn ownership of a real asset into a digital record that is also legal?" },
  { title: "Making Ownership Useful: Lending Against Assets",
    q: [R("Owning an asset is only half its value. The other half is being able to "), G("use it without selling it"), R(".")],
    rows: [
      ["2017–2020", "MakerDAO, Compound, Aave", [B("Over-collateralized on-chain lending"), R(". A user locks an asset worth more than the loan and borrows against it, with no bank.")]],
      ["2021", "Perez, Werner, Xu & Livshits, FC 2021", [R("A price change of "), B("only 3%"), R(" can make "), B("over $10M"), R(" of loans eligible for liquidation.")]],
      ["2021", "Qin et al., ACM IMC 2021", [R("Liquidators sell more discounted collateral than necessary, "), B("at the borrowers’ expense"), R(".")]],
      ["2022", "Mango Markets exploit", [R("Price pumped 5–10× in minutes; "), B("~$114M"), R(" borrowed and drained. Oracles are a critical attack surface.")]],
      ["2026", "Aave at scale", [B("$1 trillion"), R(" in cumulative loans and over "), B("$1B"), R(" of tokenized real-world assets as collateral.")]],
    ], fs: 14, rh: 0.68,
    notes: "By 2024, ownership had become digital, compliant and trusted by institutions like BlackRock. But a record that just sits in a wallet doesn't help an ordinary user." },
  { title: "Making Ownership Last: The Quantum Threat",
    q: [R("Every ownership record, every transfer and every loan is authorized by one signature scheme: "), G("ECDSA"), R(". Will ECDSA last that long?")],
    rows: [
      ["1994", "Shor’s algorithm", [R("Can efficiently solve the math problems behind RSA and ECDSA, and "), B("forge signatures"), R(".")]],
      ["2016", "NIST PQC competition", [R("Global, multi-year public competition to find algorithms that resist quantum attacks.")]],
      ["2018", "Mosca’s theorem", [R("If X + Y > Z, the data is already at risk. "), B("Long-lived records are in danger today"), R(".")]],
      ["Aug 2024", "NIST FIPS 203, 204, 205", [B("ML-KEM, ML-DSA, SLH-DSA"), R(": the first official post-quantum standards. Falcon (FIPS 206) in draft.")]],
      ["Nov 2024", "NIST IR 8547 (draft)", [R("ECDSA and RSA "), B("deprecated after 2030, disallowed after 2035"), R(".")]],
      ["May 2025", "Gidney (Google)", [R("RSA-2048 in under a week with fewer than 1 million noisy qubits: "), B("about 20× fewer"), R(".")]],
      ["Mar 2026", "Google Quantum AI, Boneh, Drake et al.", [R("256-bit elliptic curves: "), B("fewer than 1,200 logical qubits, in minutes"), R(". Migrate “without delay”.")]],
      ["2026", "GRI + DigiCert surveys", [B("28–49%"), R(" chance within 10 years. Only "), B("7%"), R(" have deployed quantum-safe cryptography at scale.")]],
    ], fs: 13, rh: 0.44,
    notes: "Lending against assets now works at a trillion-dollar scale. A real asset's record has to stay valid for 30 years or more. Mosca: X = how long data must stay secure, Y = time needed to migrate, Z = time until quantum computers arrive." },
  { title: "Making Protection Affordable",
    q: [R("The replacement already exists: "), G("NIST’s post-quantum standards"), R(". Why hasn’t anyone put them directly on the blockchain?")],
    rows: [
      ["1979/1987", "Merkle trees", [R("Any number of records into "), B("one 32-byte root hash"), R("; about 14 hashes for 10,000 records.")]],
      ["1991", "Haber & Stornetta", [R("Tamper-proof timestamping. The Bitcoin whitepaper cites this work.")]],
      ["2018", "QRL: Quantum Resistant Ledger", [R("New blockchain with XMSS hash-based signatures; "), B("about 6 KB"), R(" per transaction.")]],
      ["2020", "Fernández-Caramés & Fraga-Lamas", [R("Blockchains will need to be "), B("redesigned"), R(" around quantum-resistant cryptography.")]],
      ["2022", "Algorand State Proofs", [R("Falcon signatures every 256 blocks; full quantum resilience targeted for "), B("2027"), R(".")]],
      ["2019–2024", "Optimistic rollups & BoLD", [R("Post only a compact commitment on-chain; correct unless someone submits a "), B("fraud proof"), R(".")]],
      ["2025", "ZKNox ETHFALCON", [R("Falcon verifier on Ethereum: ~24M gas to "), B("~1.5M gas"), R(" per signature.")]],
      ["Dec 2025", "PQ-Resilient Audit Evidence", [R("Sign only the Merkle root of a batch: "), B("spreads the cost of PQC across many records"), R(".")]],
      ["2026", "Ethereum Foundation PQ roadmap", [R("Built-in PQ signature verification (precompiles), targeting "), B("~2029"), R(".")]],
    ], fs: 13, rh: 0.39,
    notes: "The signature protecting every tokenized asset has an expiry date, and that date keeps moving closer. The obvious solution is to put these quantum-safe signatures directly on the blockchain." },
];
LIT.forEach((L, i) => {
  s = slide("Literature Review");
  litHead(s, L.title); rail(s, i); quote(s, L.q, "litq");
  s.addNotes(L.notes);
  s = slide("Literature Review");
  litHead(s, L.title); rail(s, i); lit(s, L.rows, L.fs, L.rh);
  s.addNotes("Section " + RAIL[i][0] + ". Click: the table closes and the token moves to the next section.");
});
s = slide("Literature Review");
litHead(s, "Each Piece Exists, in a Different Place");
rail(s, 4, true);
quote(s, [R("Compliant tokens, working lending, PQC standards and affordable anchoring: "), G("each in a different place"), R(".")], "litq");
s.addNotes("The direct path is either incompatible (a new chain) or ~500x too expensive, and Ethereum's own fix is years away. The anchoring path is cheap and proven, but so far only for audit logs. Does any system bring them together?");

// =====================================================================  Problem statement (cards build)
const PROBS = [
  ["P1", "lock", "Ownership records are quantum-vulnerable, and the fix is unaffordable", [[R("Signed with "), B("ECDSA"), R(", which quantum computers will break")], [R("Records must stay valid for "), B("30+ years")], [R("On-chain PQC: "), B("~1.5M gas, about 500× ECDSA")], [R("Ethereum’s fix: "), B("~2029")]], "Shor 1994 · Mosca 2018 · Google Quantum AI 2026 · NIST IR 8547 · ZKNox ETHFALCON · EF roadmap"],
  ["P2", "gold", "Tokenized real-world assets exclude small investors", [[R("Minimums of up to "), B("$5M"), R(", qualified purchasers only")], [R("ERC-4626 is "), B("most exploitable at small deposit sizes")]], "BlackRock BUIDL ($5M min) · ERC-4626 inflation attack (OpenZeppelin)"],
  ["P3", "estate", "Borrowing against assets is unsafe for micro-borrowers", [[R("Liquidate on "), B("small, brief price dips")], [R("Excess collateral to liquidators "), B("at the borrower’s expense")], [B("Manipulable price feeds")]], "Perez et al. 2021 · Qin et al. 2021 · Mango Markets 2022"],
];
for (let k = 1; k <= 3; k++) {
  s = slide("Problem Statement");
  head(s, "The Three Problems", "Problem Statement");
  T(s, "Can a person with PKR 1,000 own a real asset, use it, and trust that ownership for decades? The literature answers no.", { x: 0.6, y: 1.55, w: 12, h: 0.5, fontSize: 16, color: MUTED });
  PROBS.slice(0, k).forEach(([id, tk, t, items, ev], i) => {
    const x = 0.6 + i * 4.1, w = 3.9;
    card(s, x, 2.2, w, 4.7, `pcard${i}`);
    tok(s, tk, x + w - 1.05, 2.4, 0.8, i === 0 ? "traveller" : `ptok${i}`);
    T(s, id, { x: x + 0.3, y: 2.35, w: 1.5, h: 0.7, fontFace: HEAD, fontSize: 40, color: GOLD });
    T(s, t, { x: x + 0.3, y: 3.15, w: w - 0.6, h: 0.95, fontSize: 16, bold: true });
    bullets(s, items, { x: x + 0.3, y: 4.15, w: w - 0.6, h: 2.0, fontSize: 13 });
    T(s, ev, { x: x + 0.3, y: 6.3, w: w - 0.6, h: 0.5, fontSize: 10, color: FAINT });
  });
  s.addNotes(k === 3 ? "P1 is the core problem, the quantum-security side. P2 and P3 are the financial-inclusion side. P1 affects every user's ownership record. P2 decides who can become an owner at all. P3 decides whether owners can safely use what they own." : "Click to reveal the next problem.");
}

// =====================================================================  Methodology: verification cycle (token travels the ring)
const CYC = [
  ["SIGN", "device", [R("The app builds an envelope (action, contract, chain, signer, nonce, time window, payload hash) and signs it with "), B("Falcon-512"), R(" in the browser. The key is created and stored "), B("on the device only"), R(".")]],
  ["VERIFY", "backend", [R("The backend runs "), B("7 checks"), R(": algorithm allowed, key active and not revoked, correct chain and contract, inside the time window, nonce equals last + 1, signature valid, payload matches. Any failure is rejected with a "), B("named reason"), R(".")]],
  ["EXECUTE", "contract", [R("The contract call is submitted, and the chain "), B("re-checks its own rules independently"), R(".")]],
  ["LEAF", "batch", [R("The envelope’s hash, "), B("Keccak-256(envelope)"), R(", is added to the current 60-second batch.")]],
  ["ANCHOR", "on-chain", [R("Every 60 seconds, all leaves are built into "), B("one Merkle tree"), R(", and "), B("{root, count, epoch}"), R(" is written on-chain.")]],
  ["PROVE", "offline", [R("The user downloads {leaf, sibling hashes, epoch} and "), B("recomputes the root offline"), R(". If it matches, the action is permanently recorded.")]],
];
const CX = 3.95, CYc = 4.6, CRX = 2.0, CRY = 1.75;
const cpos = (i) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / 6; return { x: CX + CRX * Math.cos(a), y: CYc + CRY * Math.sin(a), a }; };
function cycle(active, dispute) {
  const s = slide("Methodology");
  head(s, "The Verification Cycle", "Methodology");
  s.addShape(pres.shapes.OVAL, { x: CX - CRX, y: CYc - CRY, w: 2 * CRX, h: 2 * CRY, fill: { type: "none" }, line: { color: RULE, width: 2 }, objectName: "!!cring" });
  CYC.forEach(([a, b], i) => {
    const p = cpos(i), on = i === active, done = active > i;
    s.addShape(pres.shapes.OVAL, { x: p.x - 0.13, y: p.y - 0.13, w: 0.26, h: 0.26, fill: { color: on || done ? GOLD : "3A3A3A" }, line: { type: "none" }, objectName: `!!cnode${i}` });
    const left = Math.cos(p.a) < -0.1, right = Math.cos(p.a) > 0.1, top = !left && !right && Math.sin(p.a) < 0;
    const tx = left ? p.x - 1.95 : right ? p.x + 0.5 : p.x - 0.9, ty = left || right ? p.y - 0.3 : top ? p.y - 1.05 : p.y + 0.5;
    T(s, [R(`${i + 1}  ${a}`, { bold: true, fontSize: 15, color: on ? GOLD : WHITE, breakLine: true }), R(b, { fontSize: 12, color: MUTED })], { x: tx, y: ty, w: left || right ? 1.45 : 1.8, h: 0.6, align: left ? "right" : right ? "left" : "center", objectName: `!!clab${i}` });
  });
  if (dispute) {
    tok(s, "lock", CX - 0.55, CYc - 0.55, 1.1, "lock");
    T(s, "DISPUTE", { x: 8.1, y: 2.3, w: 4.6, h: 0.5, fontSize: 14, bold: true, color: GOLD, charSpacing: 4, objectName: "!!cstep" });
    T(s, "only if challenged", { x: 8.1, y: 2.8, w: 4.6, h: 0.8, fontFace: HEAD, fontSize: 36, objectName: "!!cname" });
    T(s, [R("Anyone who suspects a false batch can challenge one envelope. The "), B("full Falcon verifier (~1.5M gas)"), R(" then runs on-chain for that single case, "), B("paid by the challenger"), R(".")], { x: 8.1, y: 3.85, w: 4.6, h: 2.4, fontSize: 18, objectName: "!!cdesc" });
  } else {
    const p = cpos(active);
    tok(s, "lock", p.x - 0.42, p.y - 0.42, 0.84, "lock");
    T(s, `STEP ${active + 1} OF 6`, { x: 8.1, y: 2.3, w: 4.6, h: 0.5, fontSize: 14, bold: true, color: GOLD, charSpacing: 4, objectName: "!!cstep" });
    T(s, CYC[active][0].charAt(0) + CYC[active][0].slice(1).toLowerCase(), { x: 8.1, y: 2.8, w: 4.6, h: 0.8, fontFace: HEAD, fontSize: 40, objectName: "!!cname" });
    T(s, CYC[active][2], { x: 8.1, y: 3.85, w: 4.6, h: 2.6, fontSize: 18, objectName: "!!cdesc" });
  }
  return s;
}
for (let i = 0; i < 6; i++) cycle(i).addNotes(["The key never leaves the device.", "Each check fails with its own named reason.", "The chain enforces its own invariants independently.", "Keccak-256 works like a CRC: a fixed 32-byte fingerprint where changing one bit changes everything.", "A Merkle tree is a hierarchical checksum: hash pairs, then hash the results, until one root remains.", "Proving one action among n needs only log2(n) hashes: 12 hashes for 4,096 actions."][i]);
cycle(6, true).addNotes("The dispute path is error detection on demand. The expensive check runs only when a fault is flagged.");

// 43k gas
s = slide("Methodology");
head(s, "How 43k Gas Is Possible", "Methodology");
T(s, [R("We don’t verify signatures on-chain. "), G("We store one 32-byte number per minute.")], { x: 0.6, y: 1.55, w: 12, h: 0.45, fontSize: 17, color: MUTED });
label(s, "Cost per batch", 0.6, 2.25);
table(s, ["Cost item", "Gas"], [
  ["Base cost of any transaction", "21,000"], ["Writing the 32-byte root to new storage", "~20,000"],
  ["Batch count, epoch number and event log", "remainder"], [[B("Total per batch")], [G("≈ 43,000")]],
], { x: 0.6, y: 2.6, w: 5.6, colW: [4.1, 1.5], fontSize: 14, rowH: 0.5, align: ["left", "right"] });
T(s, "the same for 1 action or 4,096", { x: 0.6, y: 5.15, w: 5.6, h: 0.4, fontSize: 14, italic: true, color: MUTED });
label(s, "Gas per action", 6.9, 2.25);
table(s, ["Option", "Gas"], [
  ["ECDSA today (ecrecover)", "3,000"], ["Falcon verified directly on-chain", "~1,500,000"],
  [[B("QORA at 15 actions per batch")], [G("≈ 2,870")]], [[B("QORA at 100 actions per batch")], [G("≈ 430")]], [[B("QORA at 4,096 actions per batch")], [G("≈ 10.5")]],
], { x: 6.9, y: 2.6, w: 5.8, colW: [4.1, 1.7], fontSize: 14, rowH: 0.5, align: ["left", "right"] });
card(s, 0.6, 5.8, 12.1, 0.9);
T(s, [G("Break-even  43,000 ÷ 3,000 ≈ 14.3   "), R("From 15 actions per minute onward, quantum-safe authentication costs less than ECDSA.")], { x: 0.9, y: 5.88, w: 11.6, h: 0.74, fontSize: 16, valign: "middle" });
s.addNotes("We verify off-chain, where it is cheap, and the chain only stores tamper-proof evidence, like logging the checksum of a whole data block instead of re-checking every packet at the receiver.");

// =====================================================================  Methodology: the leaf hub
const LEAVES = [
  { t: "Foundation", mods: ["M1 · PQ Core", "M2 · PQ-PKI & Envelope", "M3 · Registry & Compliance", "M4 · Vault Accounting"] },
  { t: "Investment Path", mods: ["M5 · Oracle & Proof-of-Reserve", "M8 · Settlement Rail", "M9 · Anchoring & Audit"] },
  { t: "Lending & Risk", mods: ["M6 · Risk Engine", "M7 · Lending & Liquidation", "M10 · Clients"] },
  { t: "Evaluation", mods: ["M11 · Evaluation Harness"] },
];
const HX = 6.67, HY = 4.3;
const HUBPOS = [[HX, 2.45], [HX + 3.4, HY], [HX, 6.1], [HX - 3.4, HY]];
function leafNode(s, i, x, y, d, kind) {
  tok(s, kind, x - d / 2, y - d / 2, d, `leaf${i}`);
  T(s, String(i + 1), { x: x - d / 2, y: y - d / 2, w: d, h: d, fontFace: HEAD, fontSize: Math.round(d * 30), bold: true, color: kind === "dim" ? FAINT : "2B2B2B", align: "center", valign: "middle", objectName: `!!leafnum${i}` });
}
function hub(next) {
  const s = slide("Methodology");
  head(s, "Four Leaves, One System", "Methodology");
  s.addShape(pres.shapes.OVAL, { x: HX - 3.4, y: HY - 1.85, w: 6.8, h: 3.7, fill: { type: "none" }, line: { color: RULE, width: 2 }, objectName: "!!hubring" });
  ingot(s, HX - 0.95, HY - 0.55, 1.9);
  LEAVES.forEach((L, i) => {
    const [x, y] = HUBPOS[i], done = i < next, on = i === next;
    leafNode(s, i, x, y, on ? 1.25 : 1.0, done ? "blankg" : on ? "blank" : "dim");
    const right = i === 1, left = i === 3;
    T(s, [R(`Leaf ${i + 1}`, { bold: true, color: on ? GOLD : done ? WHITE : FAINT, breakLine: true }), R(L.t, { color: on || done ? WHITE : FAINT })], {
      x: left ? x - 2.95 : right ? x + 0.8 : x + 0.8, y: y - 0.35, w: 2.1, h: 0.7, fontSize: 15, align: left ? "right" : "left", objectName: `!!leaflab${i}`,
    });
  });
  return s;
}
const PX = 4.55, PY = 1.85, PW = 8.2, PH = 4.95, IX = PX + 0.35, IW = PW - 0.7;
function leafOpen(li, active, tagline, draw, notes) {
  const L = LEAVES[li];
  const s = slide("Methodology");
  leafNode(s, li, 0.98, 1.15, 0.85, "blank");
  T(s, "METHODOLOGY", { x: 1.6, y: 0.48, w: 6, h: 0.3, fontSize: 11, bold: true, color: GOLD, charSpacing: 4, objectName: "!!kicker" });
  T(s, `Leaf ${li + 1}: ${L.t}`, { x: 1.6, y: 0.78, w: 9, h: 0.8, fontFace: HEAD, fontSize: 34, objectName: "!!title" });
  // other leaves shrink into a mini chain, still connected
  const others = [0, 1, 2, 3].filter((k) => k !== li);
  s.addShape(pres.shapes.LINE, { x: 0.85, y: 6.75, w: 1.4, h: 0, line: { color: RULE, width: 1.5 }, objectName: "!!minichain" });
  others.forEach((k, j) => leafNode(s, k, 0.85 + j * 0.7, 6.75, 0.42, k < li ? "blankg" : "dim"));
  // module chain
  const top = 2.0, step = 1.05;
  if (L.mods.length > 1) s.addShape(pres.shapes.LINE, { x: 0.93, y: top + 0.3, w: 0, h: step * (L.mods.length - 1), line: { color: RULE, width: 1.5 }, objectName: "!!modline" });
  L.mods.forEach((m, i) => {
    const y = top + i * step, on = i === active, done = i < active;
    tok(s, on ? "blankg" : done ? "blank" : "dim", 0.63, y, 0.6, `mod${li}${i}`);
    T(s, m, { x: 1.42, y, w: 3.0, h: 0.6, fontSize: 15, bold: on, color: on ? WHITE : done ? MUTED : FAINT, valign: "middle", objectName: `!!modlab${li}${i}` });
  });
  card(s, PX, PY, PW, PH, "panel");
  T(s, tagline, { x: IX, y: PY + 0.22, w: IW, h: 0.7, fontSize: 17, bold: true, objectName: "!!tagline" });
  draw(s, PY + 1.0);
  s.addNotes(notes || "");
  return s;
}
const why = (s, t) => T(s, [G("Why it holds   "), R(t)], { x: IX, y: PY + PH - 0.62, w: IW, h: 0.45, fontSize: 14, objectName: "!!why" });

hub(0).addNotes("Each leaf is a phase, and each module is one block. Click: Leaf 1 opens.");

// ---- Leaf 1
leafOpen(0, 0, "The cryptography engine every other module calls to sign, verify, encrypt and decrypt.", (s, y) => {
  T(s, [B("PQClean (NIST reference C)"), R("  →  Rust  →  ", { color: GOLD }), B("Node.js addon + WebAssembly")], { x: IX, y, w: IW, h: 0.4, fontSize: 15 });
  label(s, "One algorithm per job", IX, y + 0.6);
  miniTable(s, [["Falcon-512", "users · smallest PQ signature (~666 bytes)"], ["ML-DSA-65", "custodians and admins · integer-only, safe on servers"], ["ML-DSA-44", "price feeds · frequent and short-lived"], ["SLH-DSA", "offline root key · hash-based"], ["ML-KEM-1024/768", "encrypting documents"]], IX, y + 0.95, IW, [2.2, 5.3], 0.36, 14);
  why(s, "No cryptography of our own · official NIST test vectors");
}, "Falcon is signed only on user devices, because its floating-point maths is a side-channel risk on shared servers.");
leafOpen(0, 1, "The key system plus the envelope that seals every action.", (s, y) => {
  label(s, "Three-tier key hierarchy", IX, y);
  miniTable(s, [["Tier 0", "SLH-DSA root · offline, air-gapped"], ["Tier 1", "ML-DSA-65 service keys · rotated on a schedule"], ["Tier 2", "Falcon device keys · one per user"]], IX, y + 0.3, IW, [1.3, 6.2], 0.3, 13);
  label(s, "Each envelope field blocks one attack", IX, y + 1.35);
  miniTable(s, [["chainId · contract", "cross-chain and cross-contract replay"], ["action", "signature reused for a different action"], ["nonce", "same request resent"], ["validFrom / validTo", "delayed execution (90 s users, 1 h attestations)"], ["payloadHash", "data swapped"]], IX, y + 1.65, IW, [2.3, 5.2], 0.29, 13);
  why(s, "Revocation never deletes a key: old signatures stay verifiable for 30 years");
}, "Replay protection is built into the format rather than left to careful coding in each handler.");
leafOpen(0, 2, "Decides which assets can exist on-chain and who is allowed to own them.", (s, y) => {
  chips(s, ["UNREGISTERED", "ATTESTATION RECEIVED", "four checks", "LIVE", "FROZEN"], IX, y, IW, 0.75, 12, { key: "m3" });
  label(s, "The four checks", IX, y + 0.95);
  bullets(s, [[R("Custodian’s "), B("ML-DSA-65 signature"), R(" is valid")], [B("Sequence number"), R(" higher than the last one")], [B("Reserve ≥ tokens"), R(" to be issued · price is fresh")], [B("ERC-3643"), R(": a non-KYC wallet is rejected · KYC documents encrypted with ML-KEM-1024")]], { x: IX, y: y + 1.28, w: IW, h: 1.8, fontSize: 14 });
  why(s, "If a custodian lies, the asset is frozen; withdrawals stay open");
}, "Invariant: tokens issued ≤ physical reserve, checked on every mint and every new report.");
leafOpen(0, 3, "The ERC-4626 pool that turns asset tokens into small shares a user can buy from PKR 1,000.", (s, y) => {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: IX, y, w: IW, h: 0.65, rectRadius: 0.08, fill: { color: CARD2 }, line: { color: GOLD, width: 1 } });
  T(s, "shares = deposit × (total shares + 10⁶) ÷ (total assets + 1)", { x: IX, y, w: IW, h: 0.65, fontSize: 17, bold: true, align: "center", valign: "middle" });
  T(s, "Rounding always goes against the user making the operation and in favour of the pool.", { x: IX, y: y + 0.8, w: IW, h: 0.4, fontSize: 14, color: MUTED });
  label(s, "Cost of stealing a PKR 1,000 deposit", IX, y + 1.35);
  T(s, "≈ PKR 1,000", { x: IX, y: y + 1.65, w: 3.6, h: 0.7, fontFace: HEAD, fontSize: 34, color: FAINT });
  T(s, "without the offset", { x: IX, y: y + 2.35, w: 3.6, h: 0.35, fontSize: 13, color: MUTED });
  T(s, "≈ PKR 1 billion", { x: IX + 3.8, y: y + 1.65, w: 3.7, h: 0.7, fontFace: HEAD, fontSize: 34, color: GOLD });
  T(s, "with the 10⁶ virtual offset", { x: IX + 3.8, y: y + 2.35, w: 3.7, h: 0.35, fontSize: 13, color: MUTED });
  why(s, "Fuzz-tested over 10⁶ random sequences (Foundry) · proved by symbolic execution (Halmos)");
}, "The virtual offset makes the vault behave as if it is already seeded, so a donation cannot round a small deposit down to 0 shares.");
hub(1).addNotes("Leaf 1 complete. Click: Leaf 2 opens.");

// ---- Leaf 2: M5 oracle sequence (price tokens move through the pipeline)
const OST = [["5 sources, 3 s timeout", "drop dead or stale", "quorum ≥ 3", "median"], ["≤ 10% from 30-minute average", "round ID increases", "sign ML-DSA-44, commit"]];
function oracle(step) {
  leafOpen(1, 0, "A price is a decision the protocol makes, not data it simply reads.", (s, y) => {
    chips(s, OST[0], IX, y - 0.1, IW, 0.5, 11, { key: "oa", active: step });
    chips(s, OST[1], IX, y + 0.48, IW, 0.5, 11, { key: "ob", active: step, start: 4 });
    // pipeline lane: sources | quorum | median | 30-min band | rounds -> commit
    const top = y + 1.25, d = 0.3, gap = 0.34, midY = top + 2 * gap + d / 2;
    const ZX = [IX + 0.25, IX + 1.55, IX + 2.85, IX + 4.25, IX + 5.55];
    s.addShape(pres.shapes.LINE, { x: IX + 0.1, y: midY, w: IW - 0.2, h: 0, line: { color: RULE, width: 1, dashType: "dash" }, objectName: "!!olane" });
    // quorum bracket
    if (step === 2) {
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: ZX[1] - 0.15, y: top + gap / 2 - 0.1, w: d + 0.3, h: 3 * gap + d + 0.2, rectRadius: 0.08, fill: { type: "none" }, line: { color: GOLD, width: 1 }, objectName: "!!obox" });
      T(s, "quorum ≥ 3 ✓", { x: ZX[1] + d + 0.25, y: midY - 0.15, w: 1.3, h: 0.3, fontSize: 11, color: GOLD, objectName: "!!onote" });
    }
    if (step === 3) T(s, "median", { x: ZX[2] + 0.42, y: top + gap + 0.2, w: 1.0, h: 0.4, fontSize: 12, color: GOLD, valign: "middle", objectName: "!!onote" });
    // 30-minute band
    if (step >= 4) {
      s.addShape(pres.shapes.RECTANGLE, { x: ZX[3] - 0.35, y: top - 0.05, w: 1.15, h: 4 * gap + d + 0.1, fill: { color: GOLD, transparency: 88 }, line: { color: GOLD, width: 0.75, dashType: "dash" }, objectName: "!!oband" });
      T(s, "30-minute average", { x: ZX[3] - 0.6, y: top + 4 * gap + d + 0.1, w: 1.65, h: 0.28, fontSize: 10, color: MUTED, align: "center", objectName: "!!obandl" });
    }
    // previous rounds (the new round joins the end of this chain)
    if (step >= 5) [0, 1, 2].forEach((r) => tok(s, "dim", ZX[4] + r * 0.38, midY - 0.15, 0.3, `oround${r}`));
    for (let k = 0; k < 5; k++) {
      let x = ZX[0], yy = top + k * gap, kind = "blank", dd = d, o = {};
      if (k === 4 && step >= 1) { kind = "dim"; x = ZX[0] - 0.05; yy = top + k * gap + 0.25; if (step >= 2) o = { transparency: 100 }; }
      if (k < 4 && step >= 2) { x = ZX[1]; yy = top + k * gap + gap / 2; }
      if (k < 4 && step >= 3) { x = ZX[2]; kind = k === 1 || k === 2 ? "gold" : "blank"; }
      if (k < 4 && step >= 4) { x = ZX[3]; yy = midY - 0.27; dd = 0.54; kind = "gold"; if (k !== 1) o = { transparency: 100 }; }
      if (k === 1 && step >= 5) { x = ZX[4] + 3 * 0.38 + 0.05; yy = midY - 0.27; }
      if (k === 1 && step >= 6) { kind = "lock"; dd = 0.62; yy = midY - 0.31; }
      s.addImage(Object.assign({ path: ART(TOK[kind] + ".png"), x, y: yy, w: dd, h: dd, objectName: `!!feed${k}` }, o));
    }
    if (step >= 5) T(s, "round ID increases", { x: ZX[4] - 0.1, y: top + 4 * gap + d + 0.1, w: 1.9, h: 0.28, fontSize: 10, color: MUTED, align: "center", objectName: "!!oroundl" });
    if (step >= 6) T(s, "signed · committed", { x: ZX[4] + 0.5, y: midY - 0.75, w: 1.6, h: 0.3, fontSize: 11, color: GOLD, align: "center", objectName: "!!ocommit" });
    if (step >= 6) why(s, "Quorum: 2 dead feeds · median: 2 corrupted · 30-minute average: even 3 moving together");
  }, ["Poll 5 independent sources in parallel, with a 3-second timeout.", "Drop dead or stale sources.", "Require a quorum of at least 3.", "Take the median, which rejects outliers like a median filter.", "Reject the price if it is more than 10% away from the 30-minute time-weighted average, which rejects spikes like a low-pass filter.", "Require the round ID and timestamp to increase.", "Sign with ML-DSA-44 and commit on-chain. On failure the oracle refuses rather than guesses; repay and withdraw stay open."][step]);
}
for (let st = 0; st < 7; st++) oracle(st);

// ---- Leaf 2: M8 settlement (money moves along the rail)
const DEP = ["PKR", "ledger credit", "test-net USDC", "vault shares"], WDR = ["shares redeemed", "USDC", "ledger debit", "PKR out"];
const MONEY = [["pkr", 0, 0], ["pkr", 0, 1], ["usdc", 0, 2], ["gold", 0, 3], ["gold", 1, 0], ["usdc", 1, 1], ["usdc", 1, 2], ["pkr", 1, 3]];
function settle(step) {
  leafOpen(1, 1, "Moves money between PKR and USDC.", (s, y) => {
    label(s, "Deposit", IX, y + 0.82, 1.2);
    const dpos = chips(s, DEP, IX + 1.3, y + 0.65, IW - 1.3, 0.62, 13, { key: "dep", active: MONEY[step] && MONEY[step][1] === 0 ? MONEY[step][2] : -1 });
    label(s, "Withdraw", IX, y + 2.12, 1.2);
    const wpos = chips(s, WDR, IX + 1.3, y + 1.95, IW - 1.3, 0.62, 13, { key: "wdr", active: MONEY[step] && MONEY[step][1] === 1 ? MONEY[step][2] : -1 });
    if (step < 8) {
      const [kind, row, col] = MONEY[step];
      const p = (row === 0 ? dpos : wpos)(col);
      tok(s, kind, p.x - 0.33, p.y - 0.72, 0.66, "money");
    } else {
      tok(s, "pkr", wpos(3).x - 0.33, wpos(3).y - 0.72, 0.66, "money");
      bullets(s, [[B("Double-entry ledger"), R(": the books always balance")], [B("One interface (IFiatRail)"), R(": a real bank or card provider is a configuration change")]], { x: IX, y: y + 2.78, w: IW, h: 0.6, fontSize: 13 });
      why(s, "The only simulated part of the system; everything after the USDC credit is real");
    }
  }, step < 8 ? "Deposit: PKR → ledger credit → test-net USDC → the signed deposit envelope mints vault shares. Withdraw: shares redeemed → USDC → ledger debit → PKR out." : "The sandbox has deterministic delays and injectable failures, so we can test a payment failing halfway.");
}
for (let st = 0; st <= 8; st++) settle(st);

leafOpen(1, 2, "Turns every verified action into permanent, publicly checkable evidence.", (s, y) => {
  bullets(s, [[B("Keccak-256(envelope)"), R(" appended to the epoch’s leaf list")], [R("Every 60 seconds: "), B("sorted-pair Merkle tree"), R(", OpenZeppelin’s audited MerkleProof format")], [B("{root, leafCount, epoch}"), R(" written to PQAnchor.sol, immutable and non-upgradeable")]], { x: IX, y, w: IW, h: 1.45, fontSize: 14 });
  [["≈43k", "gas per epoch, fixed"], ["12", "hashes for 4,096 actions"], ["~22k", "gas on-chain proof check, only when needed"]].forEach(([v, l], i) => {
    const x = IX + i * 2.55;
    T(s, v, { x, y: y + 1.55, w: 2.4, h: 0.7, fontFace: HEAD, fontSize: 36, color: GOLD });
    T(s, l, { x, y: y + 2.25, w: 2.35, h: 0.6, fontSize: 13, color: MUTED });
  });
  why(s, "Epochs only increase and roots are never overwritten");
}, "It serves each user's inclusion proof and hosts the Falcon dispute verifier. The 60-second epoch matches gold's price heartbeat.");
hub(2).addNotes("Leaf 2 complete. Click: Leaf 3 opens.");

// ---- Leaf 3
leafOpen(2, 0, "Continuously checks whether every loan is still safe.", (s, y) => {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: IX, y, w: IW, h: 0.6, rectRadius: 0.08, fill: { color: CARD2 }, line: { color: GOLD, width: 1 } });
  T(s, "Health Factor = Σ quantity × price × λ ÷ debt", { x: IX, y, w: IW, h: 0.6, fontSize: 17, bold: true, align: "center", valign: "middle" });
  miniTable(s, [["≥ 1.15", "Healthy, can borrow"], ["1.00 – 1.15", "New borrowing frozen, 6 h to top up"], ["0.95 – 1.00", "Reserve buffer band"], ["< 0.95", "Liquidation"], ["< 0.90", "Full closure"]], IX, y + 0.8, IW, [2.0, 5.5], 0.34, 14);
  T(s, [B("Gold  "), R("θ = 60% · λ = 75% · 60-second price heartbeat", { color: MUTED })], { x: IX, y: y + 2.65, w: IW, h: 0.35, fontSize: 14 });
  why(s, "The engine proposes and the chain decides");
}, "It classifies each position like a comparator with trip levels. The 40% cushion is about ten times gold's worst single-day move.");
leafOpen(2, 1, "The pool where users borrow against their vault shares and lenders earn interest.", (s, y) => {
  bullets(s, [[B("Two-slope interest"), R(": cheap up to 80% usage, then steep")], [B("Global index"), R(": 10,000 small loans cost the same gas as one")]], { x: IX, y, w: IW, h: 0.85, fontSize: 14 });
  label(s, "Reserve buffer · 0.95 ≤ HF < 1.00", IX, y + 0.95);
  T(s, [R("6-hour grace timer · price recovers: "), B("no liquidation ever happens"), R(" · at most 40% of the buffer per epoch · funded from interest income")], { x: IX, y: y + 1.25, w: IW, h: 0.7, fontSize: 14 });
  label(s, "Liquidation · HF < 0.95", IX, y + 2.05);
  T(s, [R("At most "), B("50%"), R(" of the debt · bonus "), B("5% → 3% over 20 blocks"), R(" · HF 0.95 returns to "), G("≈ 1.11")], { x: IX, y: y + 2.35, w: IW, h: 0.6, fontSize: 14 });
  why(s, "Buffer: a capacitor riding through a voltage dip · grace timer: debounce");
}, "The decaying bonus means the borrower pays for the cheapest liquidation someone is willing to do, not the most expensive one bots race for.");
leafOpen(2, 2, "The apps users and operators use.", (s, y) => {
  bullets(s, [[B("Borrower/lender PWA"), R(": invest, borrow, repay, withdraw, and download and verify proofs")], [R("Falcon key "), B("generated on the device"), R(", stored in IndexedDB, never transmitted")], [B("Operations and custodian console"), R(": ML-DSA-65 reserve reports, buffer and oracle health")]], { x: IX, y, w: IW, h: 2.4, fontSize: 15 });
  why(s, "No off-chain component can move a user’s funds");
}, "Signing happens in the browser using M1's WebAssembly build.");
hub(3).addNotes("Leaf 3 complete. Click: Leaf 4 opens.");

// ---- Leaf 4
leafOpen(3, 0, "The automated pipeline that turns every claim into measured data.", (s, y) => {
  miniTable(s, [["Control build", "same system with ECDSA, one compile flag"], ["Crypto and gas", "6 algorithms on desktop, browser, mid-range Android · 1 to 4,096 actions per epoch"], ["Buffer test", "2020 and 2024 gold crashes + 10,000 simulated price paths vs plain Aave V3"], ["Oracle attack test", "1, 2 and 3 malicious feeds"], ["Scale test", "10,000 open positions"]], IX, y, IW, [2.2, 5.3], 0.52, 14);
  why(s, "The hypotheses are falsifiable");
}, "If PQ overhead turns out negligible, or the buffer prevents nothing, that is reported as a finding.");
hub(4).addNotes("Eleven modules, four leaves, one system, and every number is measured.");

// Timeline
s = slide("Methodology");
head(s, "Timeline", "Methodology");
const wx = (w) => 0.9 + ((w - 1) / 23) * 11.4;
s.addShape(pres.shapes.LINE, { x: wx(1), y: 2.85, w: wx(24) - wx(1), h: 0, line: { color: RULE, width: 2 } });
[["Leaf 1", "M1–M4", 1, 6], ["Leaf 2", "M5, M8, M9", 6, 11], ["Leaf 3", "M6, M7, M10", 11, 19], ["Leaf 4", "M11", 19, 24]].forEach(([nm, m, a, b]) => T(s, [B(nm), R("  " + m, { color: MUTED })], { x: wx(a), y: 2.1, w: wx(b) - wx(a), h: 0.4, fontSize: 14, align: "center" }));
[[6, "MS1"], [11, "MS2 (FYP-I)"], [19, "MS3"], [24, "MS4"]].forEach(([w, nm], i) => {
  tok(s, "blankg", wx(w) - 0.27, 2.58, 0.54, `leaf${i}`);
  T(s, [G(nm), R(`  week ${w}`, { color: MUTED })], { x: wx(w) - 1.1, y: 3.25, w: 2.2, h: 0.35, fontSize: 13, align: "center" });
});
table(s, ["Milestone", "Demonstration"], [
  ["MS1", "A gold lot registered and tokenized against a PQ-signed reserve"],
  ["MS2 (FYP-I)", "A PKR 5,000 deposit becomes vault shares, with a Merkle proof verified offline"],
  ["MS3", "Borrow, price drop, then buffer or liquidation with zero bad debt"],
  ["MS4", "Every research question answered with measured data"],
], { x: 0.6, y: 4.0, w: 12.1, colW: [2.0, 10.1], fontSize: 15, rowH: 0.55, colStyle: [{ bold: true, color: GOLD }, {}] });
s.addNotes("13 two-week sprints. The first and most critical block, the PQ Core, is already built.");

// Tools
s = slide("Tools and Technology");
head(s, "Tools and Technology", "Tools and Technology");
table(s, ["Layer", "Tools", "Used for"], [
  ["Smart contracts", "Solidity 0.8.26, Foundry, OpenZeppelin 5.x, T-REX, ONCHAINID", "Registry, vault, lending pool, liquidation, anchor"],
  ["Contract verification", "Foundry fuzz and invariant tests, Halmos", "Vault rounding, health factor, liquidation rules"],
  ["Post-quantum cryptography", "PQClean, Rust, napi-rs, WebAssembly", "Falcon, ML-DSA, SLH-DSA, ML-KEM on servers and browser"],
  ["Backend services", "Node.js 22, NestJS, TypeScript", "Verifier, oracle, risk engine, settlement, batcher"],
  ["Data and messaging", "Redis 7 Streams, PostgreSQL 16", "Epoch and risk queues, double-entry ledger"],
  ["Frontend", "React 18 (PWA), viem", "In-browser PQ signing, operations console"],
  ["Blockchain network", "Arbitrum Sepolia (testnet)", "Ethereum-compatible, no real funds"],
  ["Evaluation", "Python, Foundry gas snapshots", "Benchmarks, gas curves, price-crash replays"],
  ["Engineering workflow", "pnpm monorepo, GitHub Actions CI, Obsidian", "Shared codebase, quality gates, documentation"],
], { x: 0.6, y: 1.85, w: 12.1, colW: [2.9, 4.9, 4.3], fontSize: 13, rowH: 0.5, colStyle: [{ bold: true, color: GOLD }, { bold: true }, { color: MUTED }] });

// =====================================================================  SDG ring (official colours), one goal per click
const SDG = [
  ["1", "No Poverty", "E5243B", "1.4", "equal rights to economic resources, ownership of property and financial services, including microfinance", [R("Fractional ownership of gold, T-bills, Sukuk and property "), B("from PKR 1,000"), R(", plus micro-loans against it")]],
  ["5", "Gender Equality", "FF3A21", "5.a", "equal access for women to ownership and financial services", [R("A mobile-first, low-minimum account helps narrow Pakistan’s 30-point gender gap: "), B("11.9% women vs 42.3% men")]],
  ["8", "Decent Work and Economic Growth", "A21942", "8.10", "expand access to banking, insurance and financial services for all", [R("Investing, borrowing and lending in "), B("one platform"), R(", with PKR in and out")]],
  ["9", "Industry, Innovation and Infrastructure", "FD6925", "9.3", "access to affordable credit for small enterprises", [B("Asset-backed micro-credit"), R(" without selling the asset, and a buffer that protects small borrowers from unfair liquidation")]],
  ["16", "Peace, Justice and Strong Institutions", "00689D", "16.6", "effective, accountable and transparent institutions", [R("Every action "), B("permanently anchored and verifiable by anyone"), R(", and custodian reserves are publicly checkable")]],
];
const SC = { x: 3.55, y: 4.3, d: 4.3 };
function sdgSlide(active) {
  const s = slide("Sustainable Development Goals");
  head(s, "Relevant Sustainable Development Goals", "Sustainable Development Goals");
  SDG.forEach(([num, name, col], i) => {
    const on = active === i, a0 = (270 + i * 72 + 1.5) % 360, a1 = (270 + i * 72 + 70.5) % 360;
    const d = on ? SC.d + 0.5 : SC.d;
    s.addShape(pres.shapes.BLOCK_ARC, { x: SC.x - d / 2, y: SC.y - d / 2, w: d, h: d, fill: { color: col, transparency: active === -1 || on ? 0 : 72 }, line: { type: "none" }, angleRange: [a0, a1], arcThicknessRatio: on ? 0.34 : 0.26, objectName: `!!seg${i}` });
    const mid = ((270 + i * 72 + 36) * Math.PI) / 180, rr = SC.d / 2 - SC.d * 0.065 + (on ? 0.12 : 0);
    T(s, num, { x: SC.x + rr * Math.cos(mid) - 0.4, y: SC.y + rr * Math.sin(mid) - 0.25, w: 0.8, h: 0.5, fontFace: HEAD, fontSize: 20, bold: true, align: "center", valign: "middle", color: active === -1 || on ? WHITE : FAINT, objectName: `!!segn${i}` });
  });
  if (active === -1) {
    T(s, "SDGs", { x: SC.x - 1.2, y: SC.y - 0.45, w: 2.4, h: 0.9, fontFace: HEAD, fontSize: 40, align: "center", valign: "middle", objectName: "!!sdgc" });
    SDG.forEach(([num, name, col], i) => {
      s.addShape(pres.shapes.OVAL, { x: 7.0, y: 2.2 + i * 0.85, w: 0.5, h: 0.5, fill: { color: col }, line: { type: "none" } });
      T(s, num, { x: 7.0, y: 2.2 + i * 0.85, w: 0.5, h: 0.5, fontFace: HEAD, fontSize: 15, bold: true, align: "center", valign: "middle" });
      T(s, name, { x: 7.75, y: 2.2 + i * 0.85, w: 5, h: 0.5, fontSize: 18, valign: "middle" });
    });
  } else {
    const [num, name, col, tgt, tdesc, runs] = SDG[active];
    T(s, num, { x: SC.x - 1.2, y: SC.y - 0.6, w: 2.4, h: 1.2, fontFace: HEAD, fontSize: 64, color: col, bold: true, align: "center", valign: "middle", objectName: "!!sdgc" });
    T(s, `SDG ${num}`, { x: 7.0, y: 2.05, w: 5.7, h: 0.4, fontSize: 14, bold: true, color: col, charSpacing: 4, objectName: "!!sdgk" });
    T(s, name, { x: 7.0, y: 2.45, w: 5.7, h: 1.2, fontFace: HEAD, fontSize: 32, objectName: "!!sdgn" });
    T(s, [R(`Target ${tgt}  `, { bold: true, color: col }), R(tdesc, { color: MUTED })], { x: 7.0, y: 3.75, w: 5.7, h: 0.9, fontSize: 14, objectName: "!!sdgt" });
    T(s, runs, { x: 7.0, y: 4.8, w: 5.7, h: 1.6, fontSize: 18, objectName: "!!sdgd" });
  }
  return s;
}
sdgSlide(-1).addNotes("Five Sustainable Development Goals. Click through each goal.");
for (let i = 0; i < 5; i++) sdgSlide(i);

// Expected outcomes
s = slide("Expected Outcomes");
head(s, "Expected Outcomes", "Expected Outcomes");
[
  ["Working system", "estate", [R("End-to-end sandbox of "), B("11 modules"), R(" on Arbitrum Sepolia, every step verified offline")]],
  ["Cost result", "gold", [R("Measured break-even "), B("(projected ~14 actions per minute)"), R(": quantum-safe costs less gas than ECDSA")]],
  ["Performance result", "lock", [R("Signing and verification time for "), B("all six NIST algorithms"), R(" on desktop, browser, Android")]],
  ["Risk result", "bond", [B("Liquidations the buffer prevents"), R(" vs plain Aave V3")]],
  ["Security result", "lockS", [R("Every replay, oracle and vault attack "), B("rejected at its named check")]],
  ["Research output", "sukuk", [R("Open benchmark data, a reusable PQ core, and "), B("a research paper")]],
].forEach(([k, tk, runs], i) => {
  const x = 0.6 + (i % 3) * 4.1, y = 1.95 + Math.floor(i / 3) * 2.45, w = 3.9;
  card(s, x, y, w, 2.25);
  tok(s, tk, x + 0.28, y + 0.25, 0.62, null);
  T(s, k, { x: x + 1.05, y: y + 0.3, w: w - 1.3, h: 0.5, fontFace: HEAD, fontSize: 21, color: GOLD, valign: "middle" });
  T(s, runs, { x: x + 0.3, y: y + 1.05, w: w - 0.6, h: 1.1, fontSize: 14 });
});
s.addNotes("Working system: register a gold lot, invest PKR 5,000, receive vault shares, borrow, survive a price drop, withdraw.");

// Way forward
s = slide("Way Forward");
head(s, "Way Forward", "Way Forward");
s.addShape(pres.shapes.LINE, { x: 0.93, y: 2.2, w: 0, h: 3.8, line: { color: RULE, width: 2 } });
[["During the FYP", [R("Finish "), B("Module 2"), R(", the critical-path module; deliver MS1 to MS4")]],
 ["Regulation", [R("SBP regulatory sandbox · PVARA licensing · "), B("Shariah compliance review")]],
 ["Real partners", [R("Licensed payment partner "), B("(Raast and card issuance)"), R(" and licensed custodian")]],
 ["Production", [R("Independent audits, then "), B("mainnet deployment on Arbitrum")]],
 ["Long term", [R("Native PQ verification with "), B("EIP-8052"), R(": a verifier address change, not a migration")]],
].forEach(([k, runs], i) => {
  const y = 1.95 + i * 0.95;
  tok(s, i === 0 ? "blankg" : "blank", 0.66, y, 0.55, null);
  T(s, k, { x: 1.45, y, w: 2.7, h: 0.55, fontFace: HEAD, fontSize: 22, color: GOLD, valign: "middle" });
  T(s, runs, { x: 4.2, y, w: 8.5, h: 0.55, fontSize: 16, valign: "middle" });
});

// Close
s = slide("Close", { noPage: true });
["gold", "bond", "sukuk", "estate"].forEach((k, i) => tok(s, k, 3.85 + i * 1.5, 1.2, 1.15, k));
T(s, "QORA", { x: 1.5, y: 3.0, w: 10.33, h: 1.3, fontFace: HEAD, fontSize: 80, align: "center", charSpacing: 26 });
T(s, "Post-Quantum Secured Programmable Wealth Platform for Tokenized Real-World Assets", { x: 0.5, y: 4.4, w: 12.33, h: 0.5, fontSize: 18, color: MUTED, align: "center" });
s.addNotes("In short, QORA is a single platform where users can invest, borrow, lend and transact on tokenized real-world assets, all secured by quantum-safe cryptography.");

pres.writeFile({ fileName: path.join(__dirname, "QORA_Proposal_Defense.pptx") }).then((f) => console.log("wrote", f, n, "slides"));
