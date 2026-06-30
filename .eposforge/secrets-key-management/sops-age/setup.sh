#!/usr/bin/env bash
# setup.sh — Linux bootstrap helper for sops-age machine request flow.
# Run from repo root:
#   bash.eposforge/secrets-key-management/sops-age/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
CORE="${SCRIPT_DIR}/scripts/setup_core.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required." >&2
  exit 1
fi

python3 "${CORE}" request "$@"

echo ""
echo "Next: send the generated request JSON + fingerprint to the approving operator."
