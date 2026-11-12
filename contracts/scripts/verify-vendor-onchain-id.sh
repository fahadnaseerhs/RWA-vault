#!/usr/bin/env bash
# verify-vendor-onchain-id.sh — Verify that vendored onchain-id files match
# their recorded digests. Fails if ANY vendored file was edited by hand
# (AC-T1-21). Intended for CI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTRACTS_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$CONTRACTS_DIR/src/vendor/onchain-id"
DIGEST_FILE="$VENDOR_DIR/DIGESTS.sha256"

if [ ! -f "$DIGEST_FILE" ]; then
  echo "ERROR: $DIGEST_FILE not found. Run scripts/vendor-onchain-id.sh first."
  exit 1
fi

echo "=== verify-vendor-onchain-id.sh ==="
echo "Checking vendored files against recorded digests..."
echo ""

FAIL=0

while IFS= read -r line; do
  expected_sha=$(echo "$line" | awk '{print $1}')
  entry=$(echo "$line" | awk '{print $2}')

  # Only check vendored: entries (not upstream: entries)
  case "$entry" in
    vendored:*)
      local_path="${entry#vendored:}"
      full_path="$VENDOR_DIR/$local_path"

      if [ ! -f "$full_path" ]; then
        echo "FAIL: $local_path — file missing"
        FAIL=1
        continue
      fi

      actual_sha=$(sha256sum "$full_path" | cut -d' ' -f1)
      if [ "$actual_sha" != "$expected_sha" ]; then
        echo "FAIL: $local_path — digest mismatch"
        echo "  expected: $expected_sha"
        echo "  actual:   $actual_sha"
        FAIL=1
      else
        echo "  OK: $local_path"
      fi
      ;;
  esac
done < "$DIGEST_FILE"

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "VERIFICATION FAILED — one or more vendored files were modified."
  echo "Re-run scripts/vendor-onchain-id.sh to restore them."
  exit 1
else
  echo "All vendored files match their recorded digests."
  exit 0
fi
