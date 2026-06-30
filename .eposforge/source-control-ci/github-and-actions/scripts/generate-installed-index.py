#!/usr/bin/env python3
"""generate-installed-index.py — Generate.eposforge/_index.json.

Crawls every installed adapter under.eposforge/<component>/<adapter>/
and extracts the machine-readable metadata declared in the adapter's Living
Spec (<adapter>.md).  Writes the result to.eposforge/_index.json.

The index is the canonical entry point for AI agents discovering what
adapters are installed, their capabilities, and where to find their specs
and scripts.  Agents should read _index.json BEFORE opening individual
adapter spec files.

Usage
-----
    python.eposforge/source-control-ci/github-and-actions/scripts/generate-installed-index.py
    python.eposforge/source-control-ci/github-and-actions/scripts/generate-installed-index.py --check

Options
-------
    --check     Verify that the committed _index.json is up to date (exit 1
                if it differs from what would be generated).  Used in CI.

Schema
------
The generated _index.json has the shape:

    {
      "generated_at": "<ISO-8601 UTC>",
      "adapters": [
        {
          "component":          "dev-product",
          "adapter":            "claude-code",
          "spec":               ".eposforge/dev-product/claude-code/claude-code.md",
          "scripts_dir":        ".eposforge/dev-product/claude-code/scripts",
          "name":               "claude-code",
          "status":             "approved",
          "privacy_posture":    "vendor-no-training",
          "cost_hint":          "consumer-paid",
          "capabilities":       ["multi-file-edit", "terminal-ops", ...],
          "invocation_surface": "CLI"
        },
        ...
      ]
    }

Fields are extracted by parsing the markdown metadata table in each adapter's
Living Spec.  Missing fields are emitted as null.
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent.parent  # scripts -> github-actions -> source-control-ci -> .eposforge -> eposforge (repo root)
INSTALLED_DIR = REPO_ROOT / ".eposforge"  # uniform container
INDEX_PATH = REPO_ROOT / ".eposforge" / "_index.json"

# Metadata table field → JSON key mappings
FIELD_MAP = {
    "name": "name",
    "component": "component",
    "status": "status",
    "privacy_posture": "privacy_posture",
    "cost_hint": "cost_hint",
    "capabilities": "capabilities",
    "invocation_surface": "invocation_surface",
}

# Fields whose values are comma-separated lists
LIST_FIELDS = {"capabilities"}

# Component folders that are intentionally skipped (no adapter subfolders).
SKIP_COMPONENTS: set[str] = {"adrs"}


def _extract_table_field(text: str, field: str) -> str | None:
    """Extract the value from a markdown metadata table row like:
    | `field` | value |
    or
    | field | value |
    Returns the raw cell string or None.
    """
    pattern = rf"\|\s*`?{re.escape(field)}`?\s*\|\s*(.*?)\s*\|"
    m = re.search(pattern, text)
    if not m:
        return None
    # Strip markdown backticks and trailing parenthetical prose
    raw = m.group(1).strip()
    # Remove surrounding backticks if the whole value is wrapped
    raw = re.sub(r"^`(.*)`$", r"\1", raw)
    return raw or None


def _parse_spec(spec_path: Path) -> dict:
    """Parse adapter metadata from a Living Spec markdown file."""
    try:
        text = spec_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}

    result: dict = {}
    for md_field, json_key in FIELD_MAP.items():
        raw = _extract_table_field(text, md_field)
        if raw is None:
            result[json_key] = None
            continue
        if json_key in LIST_FIELDS:
            # Split comma-separated values, strip backticks
            items = [re.sub(r"`", "", part).strip() for part in raw.split(",")]
            result[json_key] = [i for i in items if i]
        else:
            # Strip trailing parenthetical prose and any remaining backticks
            clean = re.sub(r"\s+\(.*$", "", raw)
            clean = re.sub(r"`", "", clean).strip()
            result[json_key] = clean
    return result


def build_index() -> dict:
    """Crawl.eposforge/ (flat component dirs) and build the full index dict."""
    adapters = []

    if not INSTALLED_DIR.exists():
        return {"generated_at": _now(), "adapters": adapters}

    for component_dir in sorted(INSTALLED_DIR.iterdir()):
        if not component_dir.is_dir():
            continue
        if component_dir.name in SKIP_COMPONENTS:
            continue

        for adapter_dir in sorted(component_dir.iterdir()):
            if not adapter_dir.is_dir():
                continue

            adapter_name = adapter_dir.name
            spec_path = adapter_dir / f"{adapter_name}.md"

            if not spec_path.exists():
                # Skip adapter folders without a canonical spec
                continue

            rel_spec = spec_path.relative_to(REPO_ROOT).as_posix()
            scripts_dir = adapter_dir / "scripts"
            rel_scripts = scripts_dir.relative_to(REPO_ROOT).as_posix() if scripts_dir.exists() else None

            entry: dict = {
                "component": component_dir.name,
                "adapter": adapter_name,
                "spec": rel_spec,
                "scripts_dir": rel_scripts,
            }

            parsed = _parse_spec(spec_path)
            entry.update(parsed)

            adapters.append(entry)

    return {"generated_at": _now(), "adapters": adapters}


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _stable_json(obj: dict) -> str:
    """Produce deterministic JSON, omitting generated_at for comparison."""
    comparable = {k: v for k, v in obj.items() if k != "generated_at"}
    return json.dumps(comparable, indent=2, sort_keys=True, ensure_ascii=False)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify _index.json is up to date without writing (CI mode). Exit 1 if stale.",
    )
    args = parser.parse_args()

    fresh = build_index()

    if args.check:
        if not INDEX_PATH.exists():
            print(f"FAIL: {INDEX_PATH.relative_to(REPO_ROOT)} does not exist.")
            print("Run: python.eposforge/source-control-ci/github-and-actions/scripts/generate-installed-index.py")
            return 1

        try:
            committed = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"FAIL: could not read existing _index.json: {exc}")
            return 1

        if _stable_json(committed) != _stable_json(fresh):
            print("FAIL:.eposforge/_index.json is stale.")
            print("Run: python.eposforge/source-control-ci/github-and-actions/scripts/generate-installed-index.py")
            # Show a diff hint
            committed_adapters = {e["adapter"]: e for e in committed.get("adapters", [])}
            fresh_adapters = {e["adapter"]: e for e in fresh.get("adapters", [])}
            added = set(fresh_adapters) - set(committed_adapters)
            removed = set(committed_adapters) - set(fresh_adapters)
            if added:
                print(f"  New adapters not in index: {sorted(added)}")
            if removed:
                print(f"  Adapters removed from.eposforge/: {sorted(removed)}")
            changed = [a for a in set(fresh_adapters) & set(committed_adapters)
                       if fresh_adapters[a] != committed_adapters[a]]
            if changed:
                print(f"  Adapters with changed metadata: {sorted(changed)}")
            return 1

        print("installed-index: _index.json is up to date.")
        return 0

    # Write mode
    INDEX_PATH.write_text(
        json.dumps(fresh, indent=2, sort_keys=False, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    count = len(fresh["adapters"])
    rel = INDEX_PATH.relative_to(REPO_ROOT).as_posix()
    print(f"Wrote {rel} ({count} adapter{'s' if count != 1 else ''}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
