#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
tmp_output="$(mktemp)"
trap 'rm -f "$tmp_output"' EXIT

python3 "${repo_root}/instance/agent-policy/tier-yaml/scripts/generate-claude-settings.py" \
  --policy "${repo_root}/instance/agent-policy/tier-yaml/policy.tiers.yaml" \
  --output "$tmp_output"

diff -u \
  "${repo_root}/instance/agent-policy/tier-yaml/baseline/settings.expected.json" \
  "$tmp_output"

echo "ok: generated settings match baseline"
