#!/usr/bin/env python3
"""check-doc-classification.py — Validate EposForge doc classification metadata.

Checks that Markdown files in regulated directories declare the required
classification fields (doc_kind, scope, maturity, source_of_truth) as either
YAML frontmatter or a metadata table row, as defined in SPEC.md.

Behaviour
---------
- Without arguments: checks all .md files changed relative to origin/main
  (suitable for CI on PRs).
- With explicit path arguments: checks those files/directories directly
  (suitable for local validation).
- Skips exempt files (READMEs, root housekeeping docs, generated output).

Exit codes
----------
- 0  All checked files pass.
- 1  One or more checked files are missing required fields.

Usage
-----
    python instance/scripts/check-doc-classification.py
    python instance/scripts/check-doc-classification.py 01-architecture/02-components/
    python instance/scripts/check-doc-classification.py instance/SPEC.md 01-architecture/
    python instance/scripts/check-doc-classification.py --all
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REQUIRED_FIELDS = ["doc_kind", "scope", "maturity", "source_of_truth"]

# Regulated directories: .md files here are subject to the classification check
# when they appear in a diff or when --all is used.
REGULATED_DIRS = [
    "00-vision",
    "01-architecture",
    "02-roadmap",
    "03-research",
    "instance",
]

# Files always checked regardless of diff (core normative docs).
ALWAYS_CHECK = [
    "instance/SPEC.md",
]

# Patterns for files exempt from classification checks.
EXEMPT_PATTERNS = [
    r"(^|/)README\.md$",
    r"(^|/)CONTRIBUTING\.md$",
    r"(^|/)CODE_OF_CONDUCT\.md$",
    r"(^|/)AGENTS\.md$",
    r"(^|/)CLAUDE\.md$",
    r"(^|/)GEMINI\.md$",
]

REPO_ROOT = Path(__file__).resolve().parent.parent.parent


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def is_exempt(rel_path: str) -> bool:
    return any(re.search(pat, rel_path) for pat in EXEMPT_PATTERNS)


def is_regulated(rel_path: str) -> bool:
    return any(rel_path.startswith(d + "/") or rel_path == d for d in REGULATED_DIRS)


def check_file(path: Path) -> list[str]:
    """Return list of missing required classification fields for a file."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    missing = []
    for field in REQUIRED_FIELDS:
        # YAML frontmatter: "field: value" at start of line
        yaml_pat = rf"(?m)^{re.escape(field)}\s*:[ \t]*\S"
        # Markdown table: | `field` | value | or | field | value |
        table_pat = rf"\|\s*`?{re.escape(field)}`?\s*\|"
        if not (re.search(yaml_pat, text) or re.search(table_pat, text)):
            missing.append(field)
    return missing


def get_changed_files() -> list[Path]:
    """Return .md files changed relative to origin/main in the current branch."""
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=ACM", "origin/main...HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        changed = result.stdout.strip().splitlines()
    except subprocess.CalledProcessError:
        # Fallback: try HEAD~1 (useful on the default branch itself)
        try:
            result = subprocess.run(
                ["git", "diff", "--name-only", "--diff-filter=ACM", "HEAD~1"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=True,
            )
            changed = result.stdout.strip().splitlines()
        except subprocess.CalledProcessError:
            return []

    paths = []
    for f in changed:
        if f.endswith(".md"):
            p = REPO_ROOT / f
            if p.exists():
                paths.append(p)
    return paths


def collect_all_regulated() -> list[Path]:
    """Return all .md files in regulated directories."""
    paths = []
    for d in REGULATED_DIRS:
        target = REPO_ROOT / d
        if target.exists():
            paths.extend(target.rglob("*.md"))
    return paths


def resolve_targets(args_paths: list[str]) -> list[Path]:
    """Expand a mix of files and directories to a flat list of .md paths."""
    result = []
    for raw in args_paths:
        p = Path(raw)
        if not p.is_absolute():
            p = REPO_ROOT / p
        if p.is_dir():
            result.extend(p.rglob("*.md"))
        elif p.is_file() and p.suffix == ".md":
            result.append(p)
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "paths",
        nargs="*",
        help="Files or directories to check. Omit to check only changed files (CI mode).",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        dest="check_all",
        help="Check all .md files in regulated directories (not just changed ones).",
    )
    args = parser.parse_args()

    # Determine which files to check
    if args.paths:
        targets = resolve_targets(args.paths)
        mode = "explicit"
    elif args.check_all:
        targets = collect_all_regulated()
        mode = "all"
    else:
        targets = get_changed_files()
        mode = "changed"

    # Always include ALWAYS_CHECK entries
    for rel in ALWAYS_CHECK:
        p = REPO_ROOT / rel
        if p.exists() and p not in targets:
            targets.append(p)

    # Filter: only regulated, non-exempt files
    to_check: list[Path] = []
    for p in targets:
        try:
            rel = p.resolve().relative_to(REPO_ROOT).as_posix()
        except ValueError:
            continue
        if is_exempt(rel):
            continue
        if mode == "explicit" or mode == "all" or rel in ALWAYS_CHECK or is_regulated(rel):
            to_check.append(p)

    if not to_check:
        print("doc-classification: no regulated files to check.")
        return 0

    print(f"doc-classification: checking {len(to_check)} file(s) [{mode} mode]")
    failures: list[tuple[str, list[str]]] = []

    for p in sorted(to_check):
        try:
            rel = p.resolve().relative_to(REPO_ROOT).as_posix()
        except ValueError:
            rel = str(p)
        missing = check_file(p)
        if missing:
            failures.append((rel, missing))
        else:
            print(f"  OK  {rel}")

    if failures:
        print()
        print("FAIL — the following files are missing required classification fields:")
        for rel, missing in failures:
            print(f"  {rel}")
            for field in missing:
                print(f"    - missing: {field}")
        print()
        print("Add a YAML frontmatter block or metadata table to each file.")
        print("Required fields: doc_kind, scope, maturity, source_of_truth")
        print("See instance/SPEC.md §Document classification convention for format details.")
        return 1

    print("doc-classification: all files OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
