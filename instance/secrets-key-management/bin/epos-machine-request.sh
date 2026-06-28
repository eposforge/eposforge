#!/bin/bash
# Generate a machine authorization request for sops-age recipients (Linux).
# Thin wrapper that locates and invokes the Python core.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# bin -> secrets-key-management -> installed -> instance -> eposforge (4 levels)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
CORE="$REPO_ROOT/instance/secrets-key-management/sops-age/scripts/setup_core.py"

if [[ ! -f "$CORE" ]]; then
    echo "ERROR: Could not find setup_core.py at $CORE" >&2
    exit 1
fi

python3 "$CORE" request "$@"
