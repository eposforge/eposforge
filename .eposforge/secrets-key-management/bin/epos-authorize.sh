#!/bin/bash
# Authorize an sops-age recipient from a machine request or public key (Linux).
# Thin wrapper that locates and invokes the Python core.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# bin -> secrets-key-management -> installed -> instance -> eposforge (4 levels)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
