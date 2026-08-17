# RWA-Vault

A post-quantum anchored protocol for tokenised real-world assets with collateralised
micro-liquidity.

Final Year Project — Fahad Naseer (403897) · Hassan Attique (482073) · Fawaz Asif (473423)

- Full technical proposal: [`docs/RWA-Vault_proposal_v2.pdf`](docs/RWA-Vault_proposal_v2.pdf)
- Module build plan and per-phase tasks: [`docs/RWA-Vault_Module_Build_Plan.docx`](docs/RWA-Vault_Module_Build_Plan.docx)
- Contributing, branching and ADR conventions: [`CONTRIBUTING.md`](CONTRIBUTING.md)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Clone the Repository](#clone-the-repository)
3. [Environment Variables](#environment-variables)
4. [Install Dependencies](#install-dependencies)
5. [Local Development Network (Docker)](#local-development-network-docker)
6. [Smart Contracts (Foundry)](#smart-contracts-foundry)
7. [Evaluation Harness (Python)](#evaluation-harness-python)
8. [Dev Container (Zero-Install Alternative)](#dev-container-zero-install-alternative)
9. [Root Scripts](#root-scripts)
10. [Project Structure](#project-structure)
11. [Build Order](#build-order)
12. [CI Pipeline](#ci-pipeline)
13. [Status](#status)

---

## Prerequisites

Install these tools **before** cloning. The pinned versions matter — they prevent
cross-machine "works on my machine" issues.

| Tool | Version | Why |
|------|---------|-----|
| **Git** | latest | Version control; submodules required for Foundry deps |
| **Node.js** | 22.16.0 (LTS) | Runtime for all TS/JS services and apps |
| **pnpm** | 9.12.0 | Monorepo package manager (auto-managed via `corepack`) |
| **Docker + Compose** | latest | Local devnet: Anvil chain, PostgreSQL, Redis |
| **Foundry** (forge, anvil, cast) | stable | Solidity compiler, local chain, contract interaction |
| **Rust** | 1.81.0 | Post-quantum cryptography native library (pq-core) |
| **wasm-pack** | latest | Builds pq-core to WASM for the browser signer |
| **Python** | 3.12+ | Evaluation harness only (thesis data processing) |

> **Shortcut:** If you use VS Code, the [Dev Container](#dev-container-zero-install-alternative)
> installs everything automatically — skip straight to that section.

### Step 1 — Git

Download from [git-scm.com](https://git-scm.com/downloads) or install via your OS package
manager. On Windows, install **Git for Windows** (includes Git Bash).

```bash
git --version
```

### Step 2 — Node.js 22.16.0

Use a version manager so you can switch Node versions per project:

**Using nvm** (macOS / Linux / Git Bash on Windows):

```bash
nvm install 22.16.0
nvm use 22.16.0
```

**Using fnm** (cross-platform):

```bash
fnm install 22.16.0
fnm use 22.16.0
```

Verify:

```bash
node --version
# v22.16.0
```

### Step 3 — Enable pnpm via Corepack

Corepack ships with Node.js. It reads the `packageManager` field in `package.json` and
ensures every developer uses **exactly** pnpm 9.12.0 — no separate install required:

```bash
corepack enable
```

Verify:

```bash
pnpm --version
# 9.12.0
```

### Step 4 — Docker and Docker Compose

Install Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop/).
Docker Compose is included.

Verify:

```bash
docker --version
docker compose version
```

### Step 5 — Foundry (Forge, Anvil, Cast)

**macOS / Linux / Git Bash on Windows:**

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Windows (without WSL):** Download prebuilt binaries from the
[Foundry releases page](https://github.com/foundry-rs/foundry/releases).

Verify:

```bash
forge --version
anvil --version
```

### Step 6 — Rust 1.81.0 and wasm-pack

**Install Rust** (if not already installed):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

On Windows, download the installer from [rustup.rs](https://rustup.rs/).

The project pins Rust 1.81.0 via `packages/pq-core/native/rust-toolchain.toml`. Running
any `cargo` command from that directory will auto-install the correct version via `rustup`.

**Add the WASM target and install wasm-pack:**

```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-pack --locked
```

Verify:

```bash
rustc --version
# rustc 1.81.0
wasm-pack --version
```

### Step 7 — Python 3.12+

Only needed for the evaluation harness (`eval/`). Download from
[python.org](https://www.python.org/downloads/) or use your OS package manager.

On Windows, check **"Add Python to PATH"** during installation.

Verify:

```bash
python --version
# Python 3.12.x or later
```

---

## Clone the Repository

```bash
git clone --recurse-submodules <repository-url>
cd rwa-vault
```

`--recurse-submodules` pulls Foundry's git submodule dependencies (forge-std, OpenZeppelin,
etc.) inside `contracts/lib/`.

**Already cloned without submodules?** Run this from the repo root:

```bash
git submodule update --init --recursive
```

---

## Environment Variables

Copy the template and fill in your values:

```bash
cp .env.example .env
```

For **local development only**, the defaults already work — Anvil, PostgreSQL and Redis
URLs point to the Docker devnet ports. You only need to fill in external values when
deploying to Arbitrum Sepolia.

| Variable | Pre-filled? | When you need it |
|----------|-------------|------------------|
| `ANVIL_RPC_URL` | Yes (`localhost:8545`) | Always (local chain) |
| `DATABASE_URL` | Yes (`localhost:5432`) | Always (off-chain state) |
| `REDIS_URL` | Yes (`localhost:6379`) | Always (event bus) |
| `AUTH_MODE` | Yes (`pq`) | Always — `pq` or `ecdsa_control` |
| `ARBITRUM_SEPOLIA_RPC_URL` | No | Testnet deployment |
| `DEPLOYER_PRIVATE_KEY` | No | Testnet deployment |
| `ARBISCAN_API_KEY` | No | Contract source verification |
| `PRICE_SOURCE_*_URL` | No | Oracle aggregation (M5) |

See `.env.example` for a full explanation of every variable.

---

## Install Dependencies

### JavaScript / TypeScript

From the project root:

```bash
pnpm install
```

This installs dependencies for all 11 workspace packages (`apps/*`, `services/*`,
`packages/*`) in a single command. The lockfile (`pnpm-lock.yaml`) ensures reproducible
installs.

### Foundry (Solidity)

Foundry dependencies live in `contracts/lib/` as git submodules (pulled during the clone
step). Build the contracts to verify everything is wired up:

```bash
pnpm contracts:build
```

### Rust (pq-core)

The Rust toolchain auto-installs via `rustup` when you run any `cargo` command from
`packages/pq-core/native/` — the `rust-toolchain.toml` file handles version pinning.

---

## Local Development Network (Docker)

The devnet starts three containers:

| Service | Port | Purpose |
|---------|------|---------|
| **Anvil** | 8545 | Local Ethereum chain (chain ID 31337) |
| **PostgreSQL 16** | 5432 | Off-chain state (settlement ledger, asset registry) |
| **Redis 7** | 6379 | Event bus (Streams) + real-time notifications (Pub/Sub) |

**Start:**

```bash
pnpm devnet:up
```

**Stop** (data preserved in Docker volumes):

```bash
pnpm devnet:down
```

**Full reset** (wipes all data):

```bash
docker compose -f infra/docker-compose.yml down -v
```

---

## Smart Contracts (Foundry)

All commands run from the project root:

```bash
pnpm contracts:build          # Compile Solidity sources
pnpm contracts:test           # Unit + fuzz tests (1K runs)
pnpm contracts:fmt            # Check formatting (forge fmt)
pnpm contracts:snapshot        # Generate gas snapshots
pnpm contracts:deploy:local   # Deploy to local Anvil
```

Contract source lives in `contracts/src/`, organised by module:

| Directory | Module | Purpose |
|-----------|--------|---------|
| `keys/` | M2 | Post-quantum key registry |
| `registry/` | M3 | Asset registration and attestation |
| `tokens/` | M3 | ERC-20 wrapped tokens |
| `vault/` | M4 | ERC-4626 asset vault |
| `oracle/` | M5 | On-chain oracle consumer |
| `lending/` | M7 | Collateralised micro-lending pool |
| `anchoring/` | M9 | PQ anchor verification |

---

## Evaluation Harness (Python)

The `eval/` directory has its own Python virtual environment, separate from the Node/Rust
stack. It processes Foundry gas snapshots and k6 output into the RQ1–RQ4 tables and
figures for the thesis.

### Step 1 — Create the virtual environment

```bash
cd eval
python -m venv .venv
```

### Step 2 — Activate the virtual environment

Pick your shell:

```bash
# macOS / Linux / Git Bash on Windows:
source .venv/bin/activate

# Windows PowerShell:
.venv\Scripts\Activate.ps1

# Windows Command Prompt:
.venv\Scripts\activate.bat
```

Your terminal prompt should now show `(.venv)` at the beginning.

### Step 3 — Install Python dependencies

```bash
pip install -r requirements.txt
```

`requirements.txt` is a lockfile generated by `pip freeze` — it pins exact versions for
reproducibility. To add a new package, edit `requirements.in` (the human-intent file),
then regenerate:

```bash
pip install -r requirements.in
pip freeze > requirements.txt
```

### Step 4 — Deactivate when done

```bash
deactivate
```

See [`eval/README.md`](eval/README.md) for more on the evaluation pipeline layout.

---

## Dev Container (Zero-Install Alternative)

If you use VS Code with the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers),
skip all manual prerequisite installation:

1. Open the project folder in VS Code.
2. Click **"Reopen in Container"** when prompted (or run `Dev Containers: Reopen in Container`
   from the command palette).
3. Wait for the container to build. It automatically installs Node.js, Rust, Python,
   Foundry, wasm-pack, and all project dependencies.

**Important:** Inside the Dev Container, Anvil, PostgreSQL and Redis are sibling containers
reached by **service name**, not `localhost`. Update your `.env` accordingly:

```
ANVIL_RPC_URL=http://anvil:8545
DATABASE_URL=postgresql://rwa:rwa@postgres:5432/rwa_vault
REDIS_URL=redis://redis:6379
```

From your **host machine's** browser, the same services remain available at `localhost` on
their respective ports (8545, 5432, 6379) via port forwarding.

---

## Root Scripts

| Script | Description |
|--------|-------------|
| `pnpm build` | Recursive build across all workspace packages |
| `pnpm test` | Recursive test across all packages |
| `pnpm lint` | Recursive ESLint |
| `pnpm typecheck` | Recursive `tsc --noEmit` |
| `pnpm format` | Prettier write across the repo |
| `pnpm format:check` | Prettier check (no writes) |
| `pnpm devnet:up` / `devnet:down` | Start / stop the local Docker devnet |
| `pnpm contracts:build` | `forge build` |
| `pnpm contracts:test` | `forge test -vvv` |
| `pnpm contracts:fmt` | `forge fmt --check` |
| `pnpm contracts:snapshot` | `forge snapshot` |
| `pnpm contracts:deploy:local` | Deploy to local Anvil chain |

---

## Project Structure

```
rwa-vault/
├── apps/
│   ├── client/              # M10  Borrower/lender PWA (React, viem, TanStack Query)
│   └── ops-console/         # M10  Provider onboarding and operations dashboard
├── contracts/
│   ├── src/                 # Solidity sources (organised by module)
│   ├── test/                # Forge test files
│   ├── script/              # Deployment scripts
│   ├── lib/                 # Git submodule dependencies (forge-std, OpenZeppelin)
│   └── foundry.toml         # Foundry configuration
├── docs/
│   ├── adr/                 # Architecture Decision Records
│   ├── RWA-Vault_proposal_v2.pdf
│   └── RWA-Vault_Module_Build_Plan.docx
├── eval/
│   ├── .venv/               # Python virtual environment (gitignored)
│   ├── scripts/             # Reproducible RQ1–RQ4 data processing
│   ├── notebooks/           # Exploratory Jupyter notebooks
│   ├── requirements.in      # Human-edited dependency intent
│   └── requirements.txt     # Lockfile (pip freeze)
├── infra/
│   └── docker-compose.yml   # Anvil + PostgreSQL + Redis devnet
├── packages/
│   ├── config/              # Shared ESLint, Prettier, TypeScript config
│   ├── envelope-codec/      # M2  PQ-signed envelope encode/decode (TS)
│   ├── pq-core/             # M1  Falcon-512 / ML-DSA / SLH-DSA (Rust → WASM + native)
│   └── types/               # Shared domain types and ABI-derived bindings
├── services/
│   ├── anchor-batcher/      # M9  60s epoch Merkle batching, on-chain anchoring
│   ├── oracle/              # M5  Five-source aggregation, median + TWAP gate
│   ├── pq-verifier/         # M2  Stateless seven-condition envelope verification
│   ├── risk-engine/         # M6  Health-factor sweep on Redis Streams
│   └── settlement-rail/     # M8  Mock PKR rail, double-entry ledger
├── .devcontainer/           # VS Code Dev Container (zero-install path)
├── .env.example             # Environment variable template
├── .github/workflows/ci.yml # CI pipeline (3 parallel jobs)
├── .gitignore
├── .nvmrc                   # Pins Node.js to 22.16.0
├── package.json             # Root workspace config
├── pnpm-lock.yaml           # Dependency lockfile
└── pnpm-workspace.yaml      # Workspace package definitions
```

`packages/*` is consumed by `apps/*` and `services/*`, never the reverse.
`contracts/` sits outside the pnpm workspace because Foundry has its own toolchain; it is
driven from root scripts (`pnpm contracts:build`, `pnpm contracts:test`).

---

## Build Order

Modules ship in dependency order across four phases, gated by milestones:

| Phase | Weeks | Modules | Gate |
|-------|-------|---------|------|
| 1 — Foundation & crypto core | 1–6 | M0, M1, M2, M3, M4 | MS1: gold lot registered and tokenised |
| 2 — Investment path | 7–11 | M5, M8, M9 | MS2: FYP-I deliverable, offline proof |
| 3 — Lending & risk | 12–19 | M6, M7, M10 | MS3: end-to-end lend and liquidate |
| 4 — Evaluation | 20–24 | M11 | MS4: every RQ answered from measurement |

See the module build plan for the full task breakdown.

---

## CI Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs **three parallel jobs** on
every push to `main` and every PR:

1. **node** — Lint, typecheck, build, test, and format-check all TS/JS workspace packages.
2. **contracts** — Compile, format-check, and run Forge tests (1K fuzz runs).
3. **contracts-invariants** — Invariant and property-based fuzz tests at 1M runs.

All three must pass before a PR can merge.

---

## Status

M0 in progress. No protocol code is implemented yet — packages currently hold
interfaces and constants only, per the "interfaces before implementations" rule in
[`CONTRIBUTING.md`](CONTRIBUTING.md).
