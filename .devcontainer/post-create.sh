#!/usr/bin/env bash
# Runs once, automatically, after the Dev Container is built — a developer
# never types any of these commands themselves. Node, Rust and Python are
# already installed by the devcontainer.json "features" block by the time
# this runs; this script covers the two tools with no official feature
# (Foundry, wasm-pack) plus project-level setup (pnpm install, the Python
# venv for eval/).
set -euo pipefail

echo "==> Enabling corepack (pins pnpm to the packageManager field in package.json)"
corepack enable

echo "==> Installing Foundry (stable channel — matches .github/workflows/ci.yml)"
# This is the same command CONTRIBUTING.md tells a non-container developer to
# run locally. One documented install path, not two that can drift apart.
curl -L https://foundry.paradigm.xyz | bash
export PATH="$HOME/.foundry/bin:$PATH"
foundryup

echo "==> Adding the wasm32 target and wasm-pack (pq-core browser build, M1)"
rustup target add wasm32-unknown-unknown
cargo install wasm-pack --locked

echo "==> Installing JS/TS workspace dependencies"
pnpm install --frozen-lockfile

echo "==> Bootstrapping the Python eval harness (M11), if requirements.txt exists yet"
if [ -f eval/requirements.txt ]; then
  python3 -m venv eval/.venv
  eval/.venv/bin/pip install -r eval/requirements.txt
else
  echo "    eval/requirements.txt not generated yet — see eval/README.md"
fi

cat <<'EOF'

==> Dev Container ready.

Anvil, PostgreSQL and Redis are SIBLING containers, not localhost, from inside
this container. In .env, use the compose service names instead of localhost:

  ANVIL_RPC_URL=http://anvil:8545
  DATABASE_URL=postgresql://rwa:rwa@postgres:5432/rwa_vault
  REDIS_URL=redis://redis:6379

(From your HOST machine's browser, http://localhost:8545 etc. still work —
forwardPorts in devcontainer.json publishes them there.)
EOF
