#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BACKLOG_DIR="${REPO_ROOT}/backlog"
ACTIVE_FILE="${BACKLOG_DIR}/backlog.md"
SLATED_FILE="${BACKLOG_DIR}/backlog-slated.md"
ARCHIVE_FILE="${BACKLOG_DIR}/backlog-archive.md"
CONFIG_FILE="${BACKLOG_DIR}/config.toml"

staged_only=0
if [[ "${1:-}" == "--staged" ]]; then
  staged_only=1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: missing config file: ${CONFIG_FILE}" >&2
  exit 1
fi

workspace_file="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"

python3 - "$REPO_ROOT" "$ACTIVE_FILE" "$SLATED_FILE" "$ARCHIVE_FILE" "$CONFIG_FILE" "$staged_only" "$workspace_file" "${BACKLOG_ROOTS:-}" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
active_file = Path(sys.argv[2])
slated_file = Path(sys.argv[3])
archive_file = Path(sys.argv[4])
config_file = Path(sys.argv[5])
staged_only = sys.argv[6] == "1"
workspace_file = sys.argv[7].strip()
backlog_roots_env = sys.argv[8].strip()

status_values = {"open", "in-progress", "blocked", "slated", "resolved"}
effort_values = {"S", "M", "L", "XL"}
required_fields = [
    "ID",
    "Title",
    "Date",
    "Status",
    "Effort",
    "Fix surface",
    "Verify with",
]
id_pattern = re.compile(r"^[A-Z]+-[0-9]{3,}$")
date_pattern = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
header_pattern = re.compile(r"^## Issue ([A-Z]+-[0-9]{3,}) — (.+)$")


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def parse_config(path: Path):
    text = read_text(path)
    prefix_match = re.search(r'^\s*prefix\s*=\s*"([A-Z]+)"\s*$', text, re.M)
    if not prefix_match:
        raise SystemExit(f"ERROR: could not parse prefix from {path}")
    prefix = prefix_match.group(1)
    surfaces_match = re.search(r"^\s*fix_surfaces\s*=\s*\[(.*?)\]\s*$", text, re.M)
    surfaces = []
    if surfaces_match:
        surfaces = [s.strip().strip('"') for s in surfaces_match.group(1).split(",") if s.strip()]
    return prefix, surfaces


def parse_issues(path: Path):
    text = read_text(path)
    lines = text.splitlines()
    prefix_lines = []
    issues = []
    current = None

    for line in lines:
        header = header_pattern.match(line)
        if header:
            if current:
                issues.append(current)
            current = {
                "header_id": header.group(1),
                "header_title": header.group(2),
                "fields": {},
                "raw": [line],
            }
            continue

        if current is None:
            prefix_lines.append(line)
            continue

        current["raw"].append(line)
        field_match = re.match(r"^([A-Za-z][A-Za-z\- ]+):\s*(.*)$", line)
        if field_match:
            current["fields"][field_match.group(1).strip()] = field_match.group(2).strip()

    if current:
        issues.append(current)

    return {
        "prefix": prefix_lines,
        "issues": issues,
        "text": text,
    }


def discover_roots(current_repo: Path):
    roots = []
    if workspace_file:
        ws_path = Path(workspace_file).expanduser().resolve()
        if ws_path.exists():
            try:
                data = json.loads(ws_path.read_text(encoding="utf-8"))
                ws_dir = ws_path.parent
                for folder in data.get("folders", []):
                    folder_path = folder.get("path")
                    if not folder_path:
                        continue
                    p = Path(folder_path)
                    if not p.is_absolute():
                        p = (ws_dir / p).resolve()
                    else:
                        p = p.resolve()
                    roots.append(p)
            except Exception:
                pass
    if roots:
        return dedupe_roots(roots)

    if backlog_roots_env:
        env_roots = [Path(p).expanduser().resolve() for p in backlog_roots_env.split(":") if p.strip()]
        if env_roots:
            return dedupe_roots(env_roots)

    return [current_repo]


def dedupe_roots(roots):
    seen = set()
    out = []
    for root in roots:
        key = str(root)
        if key in seen:
            continue
        seen.add(key)
        out.append(root)
    return out


def collect_all_issue_ids(roots):
    all_ids = set()
    for root in roots:
        backlog_root = root / "backlog"
        config = backlog_root / "config.toml"
        if not config.exists():
            continue
        for rel in ["backlog.md", "backlog-slated.md", "backlog-archive.md"]:
            data = parse_issues(backlog_root / rel)
            for issue in data["issues"]:
                issue_id = issue["fields"].get("ID", issue["header_id"])
                all_ids.add(issue_id)
    return all_ids


def csv_ids(raw: str):
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


prefix, fix_surfaces = parse_config(config_file)
roots = discover_roots(repo_root)
all_ids = collect_all_issue_ids(roots)

check_files = [active_file, slated_file]
if staged_only:
    proc = subprocess.run(
        ["git", "-C", str(repo_root), "diff", "--cached", "--name-only"],
        capture_output=True,
        text=True,
        check=False,
    )
    staged = set(proc.stdout.splitlines())
    candidate = []
    for path in check_files:
        rel = path.resolve().relative_to(repo_root)
        if str(rel).replace("\\", "/") in staged:
            candidate.append(path)
    if not candidate:
        print("backlog lint: no staged backlog files, skipping")
        sys.exit(0)
    check_files = candidate

errors = []
warnings = []

for path in check_files:
    parsed = parse_issues(path)
    issues = parsed["issues"]

    for issue in issues:
        issue_ref = f"{path.relative_to(repo_root)}:{issue['header_id']}"
        fields = issue["fields"]

        for req in required_fields:
            if not fields.get(req, "").strip():
                errors.append(f"{issue_ref} missing required field `{req}:`")

        issue_id = fields.get("ID", "").strip()
        if issue_id and not id_pattern.match(issue_id):
            errors.append(f"{issue_ref} invalid ID format `{issue_id}` (expected PREFIX-NNN)")
        if issue_id and not issue_id.startswith(f"{prefix}-"):
            errors.append(f"{issue_ref} ID `{issue_id}` does not use repo prefix `{prefix}`")
        if issue_id and issue_id != issue["header_id"]:
            errors.append(f"{issue_ref} header ID `{issue['header_id']}` does not match `ID: {issue_id}`")

        title = fields.get("Title", "").strip()
        if title and title != issue["header_title"]:
            warnings.append(f"{issue_ref} header title and `Title:` differ")

        date_value = fields.get("Date", "").strip()
        if date_value and not date_pattern.match(date_value):
            errors.append(f"{issue_ref} invalid `Date:` `{date_value}` (expected YYYY-MM-DD)")

        status = fields.get("Status", "").strip()
        if status and status not in status_values:
            errors.append(f"{issue_ref} invalid `Status:` `{status}`")

        effort = fields.get("Effort", "").strip()
        if effort and effort not in effort_values:
            errors.append(f"{issue_ref} invalid `Effort:` `{effort}`")

        surface = fields.get("Fix surface", "").strip()
        if fix_surfaces and surface and surface not in fix_surfaces:
            errors.append(
                f"{issue_ref} invalid `Fix surface:` `{surface}` (expected one of: {', '.join(fix_surfaces)})"
            )

        if status == "slated":
            if not fields.get("Slated", "").strip():
                errors.append(f"{issue_ref} missing `Slated:` for slated issue")
            if not fields.get("Re-evaluate by", "").strip():
                errors.append(f"{issue_ref} missing `Re-evaluate by:` for slated issue")
            else:
                reevaluate = fields.get("Re-evaluate by", "").strip()
                if reevaluate and not date_pattern.match(reevaluate):
                    errors.append(f"{issue_ref} invalid `Re-evaluate by:` `{reevaluate}`")

        if status == "resolved":
            if not fields.get("Validation", "").strip():
                errors.append(f"{issue_ref} missing `Validation:` for resolved issue")
            if not fields.get("Resolved", "").strip():
                errors.append(f"{issue_ref} missing `Resolved:` for resolved issue")
            else:
                resolved = fields.get("Resolved", "").strip()
                if resolved and not date_pattern.match(resolved):
                    errors.append(f"{issue_ref} invalid `Resolved:` `{resolved}`")
            warnings.append(
                f"{issue_ref} is resolved in active/slated file; run sweep-resolved.sh to archive it"
            )

        for link_field in ["Depends on", "Blocks"]:
            for dep_id in csv_ids(fields.get(link_field, "")):
                if dep_id not in all_ids:
                    errors.append(
                        f"{issue_ref} {link_field} references unknown issue ID `{dep_id}`"
                    )

    if path.name == "backlog-slated.md":
        for issue in issues:
            status = issue["fields"].get("Status", "").strip()
            if status and status != "slated":
                errors.append(
                    f"{path.relative_to(repo_root)}:{issue['header_id']} has status `{status}` in backlog-slated.md"
                )

if warnings:
    print("WARNINGS:")
    for warning in warnings:
        print(f"- {warning}")

if errors:
    print("ERRORS:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("backlog lint: OK")
PY