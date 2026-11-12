#!/usr/bin/env bash
# vendor-onchain-id.sh — Copy-vendor onchain-id from upstream, rewrite pragma,
# record SHA-256 digests. Re-running on a clean tree reproduces byte-for-byte
# (AC-T1-20). Modelled on the PQ-Clean vendor tooling.
set -euo pipefail

REPO="https://github.com/onchain-id/solidity"
COMMIT="a483cda6821e3883497972d36d0c4c1e1693e483"
RELEASE="2.2.1"
ORIGINAL_PRAGMA="pragma solidity 0.8.17;"
REWRITTEN_PRAGMA="pragma solidity ^0.8.20;"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTRACTS_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$CONTRACTS_DIR/src/vendor/onchain-id"

# Files to vendor: upstream_path -> local_path (relative to vendor dir)
declare -A FILES=(
  ["contracts/Identity.sol"]="Identity.sol"
  ["contracts/ClaimIssuer.sol"]="ClaimIssuer.sol"
  ["contracts/interface/IIdentity.sol"]="interface/IIdentity.sol"
  ["contracts/interface/IClaimIssuer.sol"]="interface/IClaimIssuer.sol"
  ["contracts/interface/IERC734.sol"]="interface/IERC734.sol"
  ["contracts/interface/IERC735.sol"]="interface/IERC735.sol"
  ["contracts/storage/Storage.sol"]="storage/Storage.sol"
  ["contracts/storage/Structs.sol"]="storage/Structs.sol"
  ["contracts/version/Version.sol"]="version/Version.sol"
)

# Import path rewrites: upstream uses relative paths from contracts/,
# we flatten into vendor dir with subdirectories preserved.
declare -A IMPORT_REWRITES=(
  ['import "./interface/']='import "./interface/'
  ['import "./version/']='import "./version/'
  ['import "./storage/']='import "./storage/'
  ['import "./Identity.sol"]='import "./Identity.sol"'
)

echo "=== vendor-onchain-id.sh ==="
echo "Upstream: $REPO @ $COMMIT ($RELEASE)"
echo "Target:   $VENDOR_DIR"
echo ""

# Create directory structure
mkdir -p "$VENDOR_DIR/interface" "$VENDOR_DIR/storage" "$VENDOR_DIR/version"

# Temporary directory for upstream downloads
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading upstream files..."
for upstream_path in "${!FILES[@]}"; do
  local_path="${FILES[$upstream_path]}"
  url="https://raw.githubusercontent.com/onchain-id/solidity/$COMMIT/$upstream_path"
  echo "  $upstream_path -> $local_path"
  curl -sS -f -o "$TMPDIR/$local_path" --create-dirs "$url"
done

echo ""
echo "Rewriting pragma and recording digests..."
DIGEST_FILE="$VENDOR_DIR/DIGESTS.sha256"
> "$DIGEST_FILE"

for upstream_path in "${!FILES[@]}"; do
  local_path="${FILES[$upstream_path]}"
  src="$TMPDIR/$local_path"
  dst="$VENDOR_DIR/$local_path"

  # Record upstream digest BEFORE pragma rewrite
  upstream_sha=$(sha256sum "$src" | cut -d' ' -f1)

  # Rewrite pragma (mechanical, one occurrence per file)
  sed -i "s|$ORIGINAL_PRAGMA|$REWRITTEN_PRAGMA|g" "$src"

  # Record post-rewrite digest (what we ship)
  local_sha=$(sha256sum "$src" | cut -d' ' -f1)

  # Copy to vendor directory
  cp "$src" "$dst"

  echo "$upstream_sha  upstream:$upstream_path" >> "$DIGEST_FILE"
  echo "$local_sha  vendored:$local_path" >> "$DIGEST_FILE"
done

# Sort digest file for deterministic output
sort -k2 "$DIGEST_FILE" -o "$DIGEST_FILE"

echo ""
echo "Digests recorded in $DIGEST_FILE"
echo ""
echo "Done. Run scripts/verify-vendor-onchain-id.sh to verify."
