#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
# shellcheck source=resolve-backlog.sh
source "${SCRIPTS_DIR}/resolve-backlog.sh"
[[ -z "${REPO_ROOT}" ]] && REPO_ROOT="$(realpath "${BACKLOG_DIR}/..")"
ACTIVE_FILE="${BACKLOG_DIR}/backlog.md"
ARCHIVE_FILE="${BACKLOG_DIR}/backlog-archive.md"
ARCHIVE_INDEX_FILE="${BACKLOG_DIR}/backlog-archive-index.md"

if [[ ! -f "${BACKLOG_DIR}/config.toml" ]]; then
  echo "ERROR: no backlog found at ${BACKLOG_DIR}/config.toml." >&2
  echo "  Bootstrap: create ${BACKLOG_DIR}/config.toml with:" >&2
  echo '    prefix = "XX"' >&2
  echo "  Resolution order tried: BACKLOG_ROOTS env → cwd walk-up → VS Code workspace file → <git-root>/backlog" >&2
  exit 1
fi

"${SCRIPTS_DIR}/lint-backlog.sh"

python3 - "$REPO_ROOT" "$ACTIVE_FILE" "$ARCHIVE_FILE" "$ARCHIVE_INDEX_FILE" <<'PY'
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
active_file = Path(sys.argv[2])
archive_file = Path(sys.argv[3])
archive_index_file = Path(sys.argv[4])

header_pattern = re.compile(r"^## Issue ([A-Z]+-[0-9]{3,}) — (.+)$")
year_month_pattern = re.compile(r"^## ([0-9]{4}-[0-9]{2})$")


def parse_issues(path: Path):
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    lines = text.splitlines()
    preface = []
    issues = []
    current = None
    for line in lines:
        m = header_pattern.match(line)
        if m:
            if current:
                issues.append(current)
            current = {
                "id": m.group(1),
                "title": m.group(2),
                "fields": {},
                "raw": [line],
            }
            continue
        if current is None:
            preface.append(line)
            continue
        current["raw"].append(line)
        fm = re.match(r"^([A-Za-z][A-Za-z\- ]+):\s*(.*)$", line)
        if fm:
            current["fields"][fm.group(1).strip()] = fm.group(2).strip()
    if current:
        issues.append(current)
    return preface, issues


def parse_archive_sections(path: Path):
    text = path.read_text(encoding="utf-8") if path.exists() else "# Backlog Archive\n\nResolved issues are grouped by month (`## YYYY-MM`).\n"
    lines = text.splitlines()
    preface = []
    sections = {}
    order = []
    current = None
    for line in lines:
        m = year_month_pattern.match(line)
        if m:
            current = m.group(1)
            if current not in sections:
                sections[current] = []
                order.append(current)
            continue
        if current is None:
            preface.append(line)
        else:
            sections[current].append(line)
    return preface, sections, order


def issue_block_text(issue):
    return "\n".join(issue["raw"]).rstrip() + "\n"


preface, issues = parse_issues(active_file)
kept = []
moved = []

for issue in issues:
    status = issue["fields"].get("Status", "").strip()
    if status != "resolved":
        kept.append(issue)
        continue
    resolved = issue["fields"].get("Resolved", "").strip()
    validation = issue["fields"].get("Validation", "").strip()
    if not resolved or not validation:
        raise SystemExit(
            f"ERROR: {issue['id']} is resolved but missing Resolved/Validation fields"
        )
    if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", resolved):
        raise SystemExit(f"ERROR: {issue['id']} has invalid Resolved date `{resolved}`")
    issue["resolved_month"] = resolved[:7]
    moved.append(issue)

if not moved:
    print("sweep-resolved: no resolved issues found in backlog.md")
    raise SystemExit(0)

# Rewrite backlog.md with non-resolved issues.
out_lines = preface[:]
while out_lines and out_lines[-1] == "":
    out_lines.pop()
out_lines.append("")
for issue in kept:
    out_lines.extend(issue["raw"])
    out_lines.append("")
active_file.write_text("\n".join(out_lines).rstrip() + "\n", encoding="utf-8")

# Merge moved issues into archive sections.
archive_preface, archive_sections, archive_order = parse_archive_sections(archive_file)
for issue in moved:
    ym = issue["resolved_month"]
    if ym not in archive_sections:
        archive_sections[ym] = []
        archive_order.append(ym)
    section_lines = archive_sections[ym]
    if section_lines and section_lines[-1] != "":
        section_lines.append("")
    section_lines.extend(issue["raw"])
    section_lines.append("")

archive_order = sorted(set(archive_order))
archive_out = archive_preface[:]
while archive_out and archive_out[-1] == "":
    archive_out.pop()
archive_out.append("")
for ym in archive_order:
    archive_out.append(f"## {ym}")
    archive_out.append("")
    section = archive_sections.get(ym, [])
    while section and section[-1] == "":
        section.pop()
    archive_out.extend(section)
    archive_out.append("")
archive_file.write_text("\n".join(archive_out).rstrip() + "\n", encoding="utf-8")

# Regenerate archive index.
_, archived_issues = parse_issues(archive_file)
rows = []
for issue in archived_issues:
    fields = issue["fields"]
    rows.append(
        {
            "id": fields.get("ID", issue["id"]),
            "title": fields.get("Title", issue["title"]),
            "surface": fields.get("Fix surface", ""),
            "resolved": fields.get("Resolved", ""),
            "summary": fields.get("Validation", "")[:120],
        }
    )
rows.sort(key=lambda r: (r["resolved"], r["id"]))

index_lines = [
    "# Backlog Archive Index",
    "",
    "Generated by `sweep-resolved.sh`. Do not edit manually.",
    "",
    "| ID | Title | Surface | Resolved | Summary |",
    "|---|---|---|---|---|",
]
for row in rows:
    index_lines.append(
        f"| {row['id']} | {row['title']} | {row['surface']} | {row['resolved']} | {row['summary']} |"
    )
archive_index_file.write_text("\n".join(index_lines) + "\n", encoding="utf-8")

print(f"sweep-resolved: moved {len(moved)} issue(s) to backlog archive")
PY