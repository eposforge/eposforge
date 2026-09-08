#!/bin/bash
# Authorize an sops-age recipient from a machine request or public key (Linux).
# Thin wrapper that locates and invokes the Python core.
# vehicle-class: host-ci-glue

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/../sops-age/scripts/setup_core.py"

if [[ ! -f "$CORE" ]]; then
    echo "ERROR: Could not find setup_core.py at $CORE" >&2
    exit 1
fi

python3 "$CORE" authorize "$@"
