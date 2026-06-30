#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
SCRIPT_DIR_LINT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
lint-backlog.sh — structural + boundary lint for a file-based backlog.

USAGE
  lint-backlog.sh            Lint active + slated backlog files at the resolved root.
  lint-backlog.sh --staged   Lint only the backlog files staged in git (pre-commit use).
  lint-backlog.sh --help     Show this help.

WHAT IT CHECKS
  - Required fields, ID/date/status/effort format, supersede + dependency integrity.
  - Public/private boundary (eposforge:EF-047): a repo whose config.toml declares
    `visibility = "public"` may NOT carry an outbound cross-repo `Depends on:` /
    `Blocks:` edge to a private (or unknown) repo. Cross-repo edges are directional:
    the PRIVATE/adopter item declares `Depends on: <public-repo>:<ID>`; the public
    item never names a private ID. Violations are ERRORS.

VISIBILITY MODEL
  Each backlog `config.toml` may declare `visibility = "public" | "private"`.
  Unset is treated as `private` (fail-safe — only an explicit `public` opts a repo
  into outbound-reference scrutiny). Visibility is resolved per repo prefix by
  scanning every discovered root's config (see resolution precedence below).

SINGLE-ROOT DEGRADATION
  When lint runs against a single root, foreign-prefix visibility cannot be
  resolved. In that mode any outbound cross-repo (foreign-prefix) edge from a
  public repo is flagged as an ERROR — the safe default, since the framework is
  typically the only public repo present. To resolve foreign visibility instead,
  run with multi-root context via `BACKLOG_ROOTS` (colon-separated backlog-parent
  dirs) or a VS Code workspace file enumerating the sibling repos.

WHOLE-FILE LEAK SCAN (ERRORS — a public repo must leak nothing)
  In public repos every line of the active, slated, AND archive backlog files —
  including file headers and operational notes, not just issue bodies — is scanned
  for private markers. Any match is a blocking ERROR; private repos are not scanned.
  Markers:
    - References to private-repo backlog items: an ID-shaped token (`PREFIX-NNN`,
      optionally `<repo>:`-qualified) whose PREFIX resolves to a `private` repo in
      the visibility map. This is map-driven, not a hardcoded name list — it
      generalizes to any prefix any config declares and matches only real item IDs,
      so prose like "UTF-8" or a bare repo name never false-positives. (Resolving
      foreign visibility needs multi-root context — see SINGLE-ROOT DEGRADATION.)
    - Private infrastructure: absolute host paths (/mnt/..., /home/..., /root/...,
      /srv/...), `*.lan` hostnames, and private IPv4 ranges (10/8, 192.168/16,
      172.16/12).
  This catches leaks the structural edge check can't see (prose, notes, headers).

ROOT RESOLUTION PRECEDENCE
  BACKLOG_ROOTS env → cwd walk-up → VS Code workspace file → <git-root>/backlog.
HELP
  exit 0
fi

# shellcheck source=resolve-backlog.sh
source "${SCRIPT_DIR_LINT}/resolve-backlog.sh"
ACTIVE_FILE="${BACKLOG_DIR}/backlog.md"
SLATED_FILE="${BACKLOG_DIR}/backlog-slated.md"
ARCHIVE_FILE="${BACKLOG_DIR}/backlog-archive.md"
CONFIG_FILE="${BACKLOG_DIR}/config.toml"

staged_only=0
if [[ "${1:-}" == "--staged" ]]; then
  staged_only=1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: no backlog found at ${CONFIG_FILE}." >&2
  echo "  Bootstrap: create ${BACKLOG_DIR}/config.toml with:" >&2
  echo '    prefix = "XX"' >&2
  echo "  Resolution order tried: BACKLOG_ROOTS env → cwd walk-up → VS Code workspace file → <git-root>/backlog" >&2
  exit 1
fi

workspace_file="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"
[[ -z "$REPO_ROOT" ]] && REPO_ROOT="$(realpath "${BACKLOG_DIR}/..")"

# Drift check: warn if the installed scripts are older than the framework source.
LOCAL_VERSION=""
if [[ -f "${SCRIPT_DIR_LINT}/VERSION" ]]; then
  LOCAL_VERSION="$(cat "${SCRIPT_DIR_LINT}/VERSION" | tr -d '[:space:]')"
fi
if [[ -n "${BACKLOG_HOME:-}" && -f "${BACKLOG_HOME}/scripts/VERSION" ]]; then
  FRAMEWORK_VERSION="$(cat "${BACKLOG_HOME}/scripts/VERSION" | tr -d '[:space:]')"
  if [[ -z "$LOCAL_VERSION" ]]; then
    echo "WARNING: installed backlog tooling has no VERSION stamp; run sync-tooling.sh to update" >&2
  elif [[ "$LOCAL_VERSION" != "$FRAMEWORK_VERSION" ]]; then
    echo "WARNING: installed tooling ${LOCAL_VERSION} differs from framework ${FRAMEWORK_VERSION}; run sync-tooling.sh to update" >&2
  fi
fi

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
    tags_match = re.search(r"^\s*tags\s*=\s*\[(.*?)\]\s*$", text, re.M)
    themes_match = re.search(r"^\s*themes\s*=\s*\[(.*?)\]\s*$", text, re.M)
    tags = []
    if tags_match:
        tags = [s.strip().strip('"') for s in tags_match.group(1).split(",") if s.strip()]
    elif themes_match:
        tags = [s.strip().strip('"') for s in themes_match.group(1).split(",") if s.strip()]
    visibility = parse_visibility(text)
    return prefix, surfaces, tags, visibility


def parse_visibility(text: str) -> str:
    # Unset is treated as "private" (fail-safe): only an explicit `public` opts a
    # repo into outbound-reference scrutiny (eposforge:EF-047).
    m = re.search(r'^\s*visibility\s*=\s*"(public|private)"\s*$', text, re.M)
    return m.group(1) if m else "private"


def build_visibility_map(roots):
    # Maps repo prefix -> visibility ("public"/"private") across all discovered
    # roots. A prefix absent from the map is "unknown" (single-root degradation).
    vis_map = {}
    for root in roots:
        cfg = root / "backlog" / "config.toml"
        if not cfg.exists():
            continue
        text = read_text(cfg)
        pm = re.search(r'^\s*prefix\s*=\s*"([A-Z]+)"\s*$', text, re.M)
        if not pm:
            continue
        vis_map[pm.group(1)] = parse_visibility(text)
    return vis_map


def ref_prefix(dep_id: str):
    # A cross-repo reference may be "PREFIX-NNN" (bare, foreign prefix) or
    # "<repo>:PREFIX-NNN" (repo-qualified). Return the PREFIX, or None if the
    # token is not an issue ID.
    tail = dep_id.split(":")[-1].strip()
    m = re.match(r"^([A-Z]+)-[0-9]+$", tail)
    return m.group(1) if m else None


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
    # Roots are normalized to the directory CONTAINING `backlog/` so that
    # `collect_all_issues` can resolve `<root>/backlog` for both the flat
    # (`<repo>/backlog`) and the adapter-mirror (`<repo>/eposforge/backlog`)
    # layouts. Precedence matches aggregate.sh / ready.sh.

    # 1. BACKLOG_ROOTS env (each entry is a backlog-parent dir)
    if backlog_roots_env:
        env_roots = [Path(p).expanduser().resolve() for p in backlog_roots_env.split(":") if p.strip()]
        if env_roots:
            return dedupe_roots(env_roots)

    # 2. cwd walk-up — probes <dir>/backlog/ then <dir>/eposforge/backlog/ (D1: depth-tolerant)
    cwd = Path.cwd()
    while cwd != cwd.parent:
        if (cwd / "backlog" / "config.toml").exists():
            return [cwd]
        if (cwd / "eposforge" / "backlog" / "config.toml").exists():
            return [cwd / "eposforge"]
        cwd = cwd.parent

    # 3. VS Code workspace file
    if workspace_file:
        ws_path = Path(workspace_file).expanduser().resolve()
        if ws_path.exists():
            try:
                data = json.loads(ws_path.read_text(encoding="utf-8"))
                ws_dir = ws_path.parent
                roots = []
                for folder in data.get("folders", []):
                    folder_path = folder.get("path")
                    if not folder_path:
                        continue
                    p = Path(folder_path)
                    if not p.is_absolute():
                        p = (ws_dir / p).resolve()
                    else:
                        p = p.resolve()
                    if (p / "backlog" / "config.toml").exists():
                        roots.append(p)
                    elif (p / "eposforge" / "backlog" / "config.toml").exists():
                        roots.append(p / "eposforge")
                if roots:
                    return dedupe_roots(roots)
            except Exception:
                pass

    # 4. git-root fallback
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


def collect_all_issues(roots):
    all_ids = set()
    id_status = {}
    # Maps: superseded_id -> list of superseding_ids (for bidirectional check)
    superseded_by: dict = {}
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
                id_status[issue_id] = issue["fields"].get("Status", "").strip().lower()
                for sup_id in csv_ids(issue["fields"].get("Supersedes", "")):
                    superseded_by.setdefault(sup_id, []).append(issue_id)
    return all_ids, id_status, superseded_by


def csv_ids(raw: str):
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


prefix, fix_surfaces, tags, local_visibility = parse_config(config_file)
roots = discover_roots(repo_root)
all_ids, id_status, superseded_by = collect_all_issues(roots)
visibility_map = build_visibility_map(roots)

# Private-marker patterns for the public-repo whole-file leak scan (ERRORS).
host_path_re = re.compile(r"/(?:mnt|home|root|srv)/[A-Za-z0-9._/-]+")
lan_host_re = re.compile(r"\b[a-z0-9][a-z0-9-]*\.lan\b")
private_ip_re = re.compile(
    r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}"
    r"|192\.168\.\d{1,3}\.\d{1,3}"
    r"|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"
)
# A reference to a private-repo backlog item: an ID-shaped token (`PREFIX-NNN`,
# optionally `<repo>:`-qualified) whose PREFIX resolves to a private repo in the
# visibility map. This is the right level of abstraction — driven by the map, not
# a hardcoded/guessed name list, so it generalizes to ANY prefix any config
# declares and matches only real item IDs (prose like "UTF-8" or a bare repo name
# never false-positives). Longest prefixes first so e.g. OAPI-041 isn't split as OA.
private_prefixes = sorted(
    (p for p, v in visibility_map.items() if v == "private" and p != prefix),
    key=len,
    reverse=True,
)
private_id_re = (
    re.compile(r"\b(?:[A-Za-z0-9_.-]+:)?((?:" + "|".join(private_prefixes) + r")-[0-9]+)\b")
    if private_prefixes
    else None
)

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
        try:
            _display_path = str(path.relative_to(repo_root))
        except ValueError:
            _display_path = str(path)
        issue_ref = f"{_display_path}:{issue['header_id']}"
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

        # Tags (multi) with Theme fallback + deprecation (EF-046)
        raw_tags = fields.get("Tags", fields.get("Theme", "")).strip()
        tag_list = [t.strip() for t in raw_tags.split(",") if t.strip()] if raw_tags else []
        for t in tag_list:
            if tags and t not in tags:
                errors.append(
                    f"{issue_ref} invalid tag `{t}` (expected one of: {', '.join(tags)})"
                )
        if fields.get("Theme") and not fields.get("Tags"):
            print(f"WARNING: {issue_ref} uses legacy `Theme:`; migrate to `Tags:` (EF-046)", file=sys.stderr)

        for sup_id in csv_ids(fields.get("Supersedes", "")):
            if sup_id not in all_ids:
                errors.append(
                    f"{issue_ref} Supersedes references unknown issue ID `{sup_id}`"
                )
            else:
                sup_status = id_status.get(sup_id, "")
                if sup_status in ("open", "in-progress"):
                    errors.append(
                        f"{issue_ref} supersedes `{sup_id}` which is still `{sup_status}`; "
                        "the superseded item must be resolved or slated before this link is valid"
                    )

        # If this item is superseded by another, it must carry a `Superseded by:` pointer back
        this_id = fields.get("ID", issue["header_id"])
        if this_id in superseded_by:
            sup_by_field = csv_ids(fields.get("Superseded by", ""))
            expected = superseded_by[this_id]
            missing = [s for s in expected if s not in sup_by_field]
            if missing:
                errors.append(
                    f"{issue_ref} is superseded by {missing} but lacks a `Superseded by:` "
                    f"pointer; add `Superseded by: {', '.join(missing)}`"
                )

        if status == "blocked":
            open_dep_statuses = {"open", "in-progress", "blocked", "slated"}
            dep_ids = csv_ids(fields.get("Depends on", ""))
            has_open_dep = any(
                id_status.get(d, "") in open_dep_statuses for d in dep_ids
            )
            if not has_open_dep:
                errors.append(
                    f"{issue_ref} `Status: blocked` requires at least one open `Depends on:` item (EF-042 blocker-record convention)"
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
                # Cross-repo edges use `<repo>:<ID>` notation (the directional form
                # eposforge:EF-047 prescribes for the private side); strip the
                # qualifier before resolving against the aggregated ID set.
                if dep_id.split(":")[-1].strip() not in all_ids:
                    errors.append(
                        f"{issue_ref} {link_field} references unknown issue ID `{dep_id}`"
                    )

        # Public/private boundary (eposforge:EF-047): a public repo must not carry
        # an outbound cross-repo edge to a private (or unknown) repo. Cross-repo
        # edges are directional — declared on the private side only.
        if local_visibility == "public":
            for link_field in ["Depends on", "Blocks"]:
                for dep_id in csv_ids(fields.get(link_field, "")):
                    rp = ref_prefix(dep_id)
                    if rp is None or rp == prefix:
                        continue
                    ref_vis = visibility_map.get(rp)
                    if ref_vis == "private":
                        errors.append(
                            f"{issue_ref} (public) references non-public `{dep_id}` in `{link_field}:`; "
                            f"declare the edge on the private side (`<private> Depends on: {prefix}:<ID>`), "
                            f"never the public side (eposforge:EF-047 boundary)"
                        )
                    elif ref_vis is None:
                        errors.append(
                            f"{issue_ref} (public) carries an outbound cross-repo edge `{dep_id}` in "
                            f"`{link_field}:` to unresolved prefix `{rp}`; declare it on the private side, or run "
                            f"with multi-root context (BACKLOG_ROOTS) to resolve visibility (single-root "
                            f"degradation — see `lint-backlog.sh --help`)"
                        )

    if path.name == "backlog-slated.md":
        for issue in issues:
            status = issue["fields"].get("Status", "").strip()
            if status and status != "slated":
                try:
                    _slated_path = str(path.relative_to(repo_root))
                except ValueError:
                    _slated_path = str(path)
                errors.append(
                    f"{_slated_path}:{issue['header_id']} has status `{status}` in backlog-slated.md"
                )

# Whole-file private-leak scan (eposforge:EF-047): in a public repo NO private
# marker may appear ANYWHERE — file headers / operational notes included, not just
# issue bodies. Covers active, slated, and the (also-public) archive. These are
# blocking ERRORS, not warnings: a public repo must leak nothing whatsoever.
if local_visibility == "public":
    leak_files = check_files if staged_only else [active_file, slated_file, archive_file]
    for path in leak_files:
        try:
            _display_path = str(path.resolve().relative_to(repo_root))
        except ValueError:
            _display_path = str(path)
        for lineno, line in enumerate(read_text(path).splitlines(), start=1):
            markers = []
            markers += host_path_re.findall(line)
            markers += lan_host_re.findall(line)
            markers += private_ip_re.findall(line)
            if private_id_re is not None:
                markers += private_id_re.findall(line)
            for marker in dict.fromkeys(markers):  # de-dupe, preserve order
                errors.append(
                    f"{_display_path}:{lineno} public-repo leak — private marker `{marker}`: a public "
                    f"repo must reference no private-repo backlog items, nor private host paths, `.lan` "
                    f"hostnames, or private IPs (eposforge:EF-047; see `lint-backlog.sh --help`)"
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