#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Any


def load_policy(path: Path) -> dict[str, Any]:
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise SystemExit(f"ERROR: policy file not found: {path}")

    # YAML 1.2 is a superset of JSON. The repo contract uses JSON-compatible
    # YAML so generation has no external parser dependency.
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: policy file must be JSON-compatible YAML: {exc}")

    if not isinstance(data, dict):
        raise SystemExit("ERROR: policy root must be an object")

    return data


def collect_tier0_permissions(policy: dict[str, Any]) -> list[str]:
    tiers = policy.get("tiers", [])
    if not isinstance(tiers, list):
        raise SystemExit("ERROR: tiers must be a list")

    tier0 = None
    for tier in tiers:
        if isinstance(tier, dict) and tier.get("id") == "tier-0":
            tier0 = tier
            break

    if tier0 is None:
        raise SystemExit("ERROR: missing tier-0 policy")

    rules = tier0.get("rules", [])
    if not isinstance(rules, list):
        raise SystemExit("ERROR: tier-0 rules must be a list")

    permissions: list[str] = []
    for rule in rules:
        if not isinstance(rule, dict):
            continue
        permission = rule.get("permission")
        if isinstance(permission, str) and permission:
            permissions.append(permission)

    if not permissions:
        raise SystemExit("ERROR: tier-0 must declare at least one permission")

    # Preserve declaration order while deduplicating.
    seen: set[str] = set()
    deduped: list[str] = []
    for p in permissions:
        if p not in seen:
            deduped.append(p)
            seen.add(p)
    return deduped


def render_settings(policy: dict[str, Any], allow: list[str]) -> dict[str, Any]:
    generator = policy.get("generator", {})
    if not isinstance(generator, dict):
        generator = {}
    base = generator.get("base", {})
    if not isinstance(base, dict):
        base = {}

    rendered = dict(base)
    rendered["permissions"] = {"allow": allow}
    return rendered


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate .claude/settings.json from tier-yaml policy")
    parser.add_argument("--policy", default=".eposforge/agent-policy/tier-yaml/policy.tiers.yaml")
    parser.add_argument("--output", default=".claude/settings.json")
    parser.add_argument("--check-baseline", default="")
    parser.add_argument("--stdout", action="store_true")
    args = parser.parse_args()

    policy_path = Path(args.policy)
    policy = load_policy(policy_path)
    allow = collect_tier0_permissions(policy)
    rendered = render_settings(policy, allow)
    rendered_json = json.dumps(rendered, indent=2, sort_keys=False) + "\n"

    if args.stdout:
        print(rendered_json, end="")

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered_json, encoding="utf-8")
    print(f"wrote: {output_path}")

    if args.check_baseline:
        baseline_path = Path(args.check_baseline)
        baseline = baseline_path.read_text(encoding="utf-8")
        if baseline != rendered_json:
            raise SystemExit(f"ERROR: generated output differs from baseline: {baseline_path}")
        print(f"baseline-match: {baseline_path}")


if __name__ == "__main__":
    main()
