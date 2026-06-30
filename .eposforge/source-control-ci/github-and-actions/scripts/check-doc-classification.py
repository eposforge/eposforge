#!/usr/bin/env python3
"""check-doc-classification.py — Validate EposForge doc classification metadata
and installed-adapter folder structure.

Two checks are performed:

1. Classification metadata check — every .md in regulated directories must
   declare doc_kind, scope, maturity, source_of_truth as YAML frontmatter
   or a metadata table row.

2. Installed-adapter layout check (--check-layout / CI always) — each entry
   under.eposforge/<component>/<adapter>/ must satisfy:
   - The adapter directory must contain exactly one <adapter>.md Living Spec.
   - scripts/ is the only permitted direct subdirectory of an adapter folder
     (besides sub-adapter folders that themselves follow this pattern).
   - No bare .md Living Specs directly under a component folder (except
     intentional _index.md files, README.md, and component-level specs
     explicitly named the same as the component folder).

The adapter-script placement convention (no files permitted under
.eposforge/scripts/) is enforced separately by check-installed-scripts-layout.sh,
which is run from the pre-commit hook fragment and the
installed-scripts-layout GitHub Actions workflow.

Behaviour
---------
- Without arguments: checks all .md files changed relative to origin/main
  (suitable for CI on PRs) plus always runs the layout check.
- With explicit path arguments: checks those files/directories directly
  (suitable for local validation).
- Skips exempt files (READMEs, root housekeeping docs, generated output).

Exit codes
----------
- 0  All checked files pass.
- 1  One or more checked files are missing required fields, or layout
     violations found.

Usage
-----
    python.eposforge/source-control-ci/github-and-actions/scripts/check-doc-classification.py
    python.eposforge/source-control-ci/github-and-actions/scripts/check-doc-classification.py 01-architecture/02-components/
    python.eposforge/source-control-ci/github-and-actions/scripts/check-doc-classification.py.eposforge/SPEC.md 01-architecture/
    python.eposforge/source-control-ci/github-and-actions/scripts/check-doc-classification.py --all
    python.eposforge/source-control-ci/github-and-actions/scripts/check-doc-classification.py --check-layout
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
    ".eposforge/SPEC.md",
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

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent.parent.parent

INSTALLED_DIR = REPO_ROOT / "instance" / "installed"

# Component folder names that are known to have a sub-adapter pattern.
# Any directory directly under INSTALLED_DIR is considered a component folder.
# Files (not folders) directly under a component folder are violations
# (except _index.md, README.md).
COMPONENT_LEVEL_EXEMPT_NAMES = {"_index.md", "README.md"}

# Directory names directly under a component folder that are component-level
# utilities rather than adapter folders.  These are skipped during layout checks.
COMPONENT_LEVEL_SKIP_DIRS = {"scripts", "hooks", "docs", "examples"}

# Permitted direct subdirectories within an adapter folder.
PERMITTED_ADAPTER_SUBDIRS = {"scripts", "docs", "examples", "tests", "prompts"}


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


def check_installed_layout() -> list[str]:
    """Validate.eposforge/<component>/<adapter>/<adapter>.md convention.

    Returns a list of human-readable violation strings (empty = no violations).
    """
    violations: list[str] = []

    if not INSTALLED_DIR.exists():
        return violations  # Nothing to check yet.

    for component_dir in sorted(INSTALLED_DIR.iterdir()):
        if not component_dir.is_dir():
            continue  # Top-level files under installed/ are tolerated.

        for item in sorted(component_dir.iterdir()):
            rel = item.relative_to(REPO_ROOT).as_posix()

            if item.is_file():
                # A bare .md file directly under a component folder is a violation
                # unless it is an explicitly permitted component-level file.
                if item.suffix == ".md" and item.name not in COMPONENT_LEVEL_EXEMPT_NAMES:
                    violations.append(
                        f"LAYOUT: bare spec at component level (should be in adapter subfolder): {rel}"
                    )
                # Non-.md files directly under component dir are always a violation.
                elif item.suffix != ".md":
                    violations.append(
                        f"LAYOUT: unexpected file directly under component folder: {rel}"
                    )
                continue

            # Skip known component-level utility directories.
            if item.name in COMPONENT_LEVEL_SKIP_DIRS:
                continue

            # item is a directory — treat as an adapter folder.
            adapter_dir = item
            adapter_name = adapter_dir.name
            expected_spec = adapter_dir / f"{adapter_name}.md"

            if not expected_spec.exists():
                # Check if any .md exists at all; if so, name mismatch.
                any_md = list(adapter_dir.glob("*.md"))
                if any_md:
                    found = ", ".join(f.name for f in any_md)
                    violations.append(
                        f"LAYOUT: adapter spec name mismatch in {rel}/ "
                        f"— expected {adapter_name}.md, found: {found}"
                    )
                else:
                    violations.append(
                        f"LAYOUT: no adapter spec found in {rel}/ "
                        f"— expected {adapter_name}.md"
                    )

            # Check that only permitted subdirs exist under adapter folder.
            for sub in sorted(adapter_dir.iterdir()):
                if sub.is_dir() and sub.name not in PERMITTED_ADAPTER_SUBDIRS:
                    violations.append(
                        f"LAYOUT: unexpected subdirectory in adapter folder "
                        f"{rel}/{sub.name} — only {sorted(PERMITTED_ADAPTER_SUBDIRS)} permitted"
                    )

    return violations


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
    parser.add_argument(
        "--check-layout",
        action="store_true",
        dest="check_layout_only",
        help="Run only the installed-adapter folder layout check (skips classification check).",
    )
    args = parser.parse_args()

    exit_code = 0

    # -----------------------------------------------------------------------
    # Layout check — always runs unless --check-layout-only with no doc check
    # -----------------------------------------------------------------------
    layout_violations = check_installed_layout()
    if layout_violations:
        print("FAIL — installed adapter layout violations:")
        for v in layout_violations:
            print(f"  {v}")
        print()
        print("Convention:.eposforge/<component>/<adapter>/<adapter>.md")
        print("  Scripts go in:.eposforge/<component>/<adapter>/scripts/")
        print("  See.eposforge/README.md for the adapter registry.")
        exit_code = 1
    else:
        print("installed-layout: all adapter folders OK.")


    if args.check_layout_only:
        return exit_code

    # -----------------------------------------------------------------------
    # Classification metadata check
    # -----------------------------------------------------------------------

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
        return exit_code

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
        print("See.eposforge/SPEC.md §Document classification convention for format details.")
        exit_code = 1
    else:
        print("doc-classification: all files OK.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
