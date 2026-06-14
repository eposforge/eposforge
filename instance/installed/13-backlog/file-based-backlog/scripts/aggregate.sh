#!/usr/bin/env bash
set -euo pipefail

MODE="plan"
KEYWORD=""
TARGET_ID=""
JSON=0
ROOTS_CLI=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      MODE="plan"
      shift
      ;;
    --regressions)
      MODE="regressions"
      KEYWORD="${2:-}"
      if [[ -z "${KEYWORD}" ]]; then
        echo "ERROR: --regressions requires a keyword" >&2
        exit 2
      fi
      shift 2
      ;;
    --graph)
      MODE="graph"
      shift
      ;;
    --themes)
      MODE="themes"
      shift
      ;;
    --critical-path)
      MODE="critical-path"
      TARGET_ID="${2:-}"
      if [[ -z "${TARGET_ID}" ]]; then
        echo "ERROR: --critical-path requires a target ID" >&2
        exit 2
      fi
      shift 2
      ;;
    --mermaid)
      MODE="mermaid"
      shift
      ;;
    --json)
      JSON=1
      shift
      ;;
    --roots)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        ROOTS_CLI+=("$1")
        shift
      done
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKSPACE_FILE="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"

python3 - "$REPO_ROOT" "$MODE" "${KEYWORD:-}" "$WORKSPACE_FILE" "${BACKLOG_ROOTS:-}" "${ROOTS_CLI[*]:-}" "$JSON" "${TARGET_ID:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
mode = sys.argv[2]
keyword = sys.argv[3]
workspace_file = sys.argv[4].strip()
backlog_roots_env = sys.argv[5].strip()
roots_cli = [p for p in sys.argv[6].split() if p.strip()]
emit_json = sys.argv[7].strip() == "1"
target_id = sys.argv[8].strip() if len(sys.argv) > 8 else ""

header_pattern = re.compile(r"^## Issue ([A-Z]+-[0-9]{3,}) — (.+)$")


def parse_config(path: Path):
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    prefix_match = re.search(r'^\s*prefix\s*=\s*"([A-Z]+)"\s*$', text, re.M)
    prefix = prefix_match.group(1) if prefix_match else ""
    themes_match = re.search(r"^\s*themes\s*=\s*\[(.*?)\]\s*$", text, re.M)
    themes = []
    if themes_match:
        themes = [s.strip().strip('"') for s in themes_match.group(1).split(",") if s.strip()]
    return prefix, themes


def parse_issues(path: Path):
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    issues = []
    current = None
    for line in lines:
        m = header_pattern.match(line)
        if m:
            if current:
                issues.append(current)
            current = {
                "header_id": m.group(1),
                "header_title": m.group(2),
                "fields": {},
                "raw": [line],
            }
            continue
        if current is None:
            continue
        current["raw"].append(line)
        fm = re.match(r"^([A-Za-z][A-Za-z\- ]+):\s*(.*)$", line)
        if fm:
            current["fields"][fm.group(1).strip()] = fm.group(2).strip()
    if current:
        issues.append(current)
    return issues


def csv_ids(raw):
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


def dedupe(paths):
    seen = set()
    out = []
    for p in paths:
        rp = p.resolve()
        key = str(rp)
        if key in seen:
            continue
        seen.add(key)
        out.append(rp)
    return out


def discover_roots():
    if workspace_file:
        ws = Path(workspace_file).expanduser().resolve()
        if ws.exists():
            try:
                data = json.loads(ws.read_text(encoding="utf-8"))
                ws_dir = ws.parent
                roots = []
                for folder in data.get("folders", []):
                    path = folder.get("path")
                    if not path:
                        continue
                    p = Path(path)
                    if not p.is_absolute():
                        p = (ws_dir / p).resolve()
                    roots.append(p)
                if roots:
                    return dedupe(roots)
            except Exception:
                pass

    if backlog_roots_env:
        roots = [Path(p).expanduser().resolve() for p in backlog_roots_env.split(":") if p.strip()]
        if roots:
            return dedupe(roots)

    if roots_cli:
        roots = [Path(p).expanduser().resolve() for p in roots_cli]
        if roots:
            return dedupe(roots)

    return [repo_root]


roots = discover_roots()
repo_sets = []
all_active = []
all_slated = []
all_archive = []

for root in roots:
    backlog_dir = root / "backlog"
    config = backlog_dir / "config.toml"
    if not config.exists():
        continue

    prefix, themes = parse_config(config)
    active = parse_issues(backlog_dir / "backlog.md")
    slated = parse_issues(backlog_dir / "backlog-slated.md")
    archive = parse_issues(backlog_dir / "backlog-archive.md")

    for issue in active:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        issue["themes_vocab"] = themes
        all_active.append(issue)
    for issue in slated:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        all_slated.append(issue)
    for issue in archive:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        all_archive.append(issue)

    repo_sets.append(root)

if not repo_sets:
    print("No backlog adapters discovered in the selected roots.")
    raise SystemExit(0)

if mode == "regressions":
    q = keyword.lower()
    hits = []
    for issue in all_archive:
        blob = "\n".join(issue["raw"]).lower()
        if q in blob:
            fields = issue["fields"]
            hits.append(
                (
                    fields.get("ID", issue["header_id"]),
                    issue["repo"],
                    fields.get("Resolved", ""),
                    fields.get("Title", issue["header_title"]),
                    fields.get("Validation", ""),
                )
            )
    if not hits:
        print(f"No archive matches for keyword: {keyword}")
        raise SystemExit(0)
    hits.sort(key=lambda x: (x[2], x[0]))
    print(f"Archive matches for '{keyword}':")
    for issue_id, repo, resolved, title, validation in hits:
        print(f"- {issue_id} [{repo}] ({resolved}) {title}")
        if validation:
            print(f"  Validation: {validation}")
    raise SystemExit(0)

if mode == "graph":
    print("Active dependency graph")
    print("")
    index = {i["fields"].get("ID", i["header_id"]): i for i in all_active}
    for issue_id in sorted(index):
        issue = index[issue_id]
        title = issue["fields"].get("Title", issue["header_title"])
        depends = csv_ids(issue["fields"].get("Depends on", ""))
        print(f"{issue_id} [{issue['repo']}] - {title}")
        if not depends:
            print("  -> (no dependencies)")
            continue
        for dep in depends:
            dep_issue = index.get(dep)
            if dep_issue:
                dep_title = dep_issue["fields"].get("Title", dep_issue["header_title"])
                print(f"  -> {dep} [{dep_issue['repo']}] - {dep_title}")
            else:
                print(f"  -> {dep} [external or archived]")
    raise SystemExit(0)

# Build a cross-repo issue index for portfolio modes
all_issues_index = {}
for issue in all_active + all_slated + all_archive:
    fields = issue["fields"]
    iid = fields.get("ID", issue["header_id"])
    all_issues_index[iid] = {
        "status": fields.get("Status", "").strip().lower(),
        "title": fields.get("Title", issue["header_title"]),
        "theme": fields.get("Theme", "").strip(),
        "effort": fields.get("Effort", "").strip(),
        "depends_on": csv_ids(fields.get("Depends on", "")),
        "blocks": csv_ids(fields.get("Blocks", "")),
        "bundle_hint": fields.get("Bundle hint", "").strip(),
        "repo": issue["repo"],
    }

OPEN_STATUSES = {"open", "in-progress", "blocked", "slated"}


def resolve_id(dep_id: str) -> str:
    if dep_id in all_issues_index:
        return dep_id
    if ":" in dep_id:
        bare = dep_id.split(":", 1)[1]
        if bare in all_issues_index:
            return bare
    return dep_id


def is_ready(iid, visited=None):
    if visited is None:
        visited = set()
    resolved = resolve_id(iid)
    if resolved in visited:
        return True
    visited.add(resolved)
    entry = all_issues_index.get(resolved)
    if not entry:
        return True
    if entry["status"] in OPEN_STATUSES:
        return False
    return True


def item_is_ready(iid):
    entry = all_issues_index.get(iid)
    if not entry or entry["status"] != "open":
        return False
    return all(is_ready(dep, set()) for dep in entry["depends_on"])


if mode == "themes":
    # Collect known themes vocabulary from any root's config
    all_themes_vocab = []
    for issue in all_active:
        for t in issue.get("themes_vocab", []):
            if t not in all_themes_vocab:
                all_themes_vocab.append(t)

    active_open = [
        iid for iid, e in all_issues_index.items()
        if e["status"] in {"open", "in-progress", "blocked"}
    ]

    # Group by theme
    themed: dict[str, list] = {}
    unanchored = []
    for iid in sorted(active_open):
        e = all_issues_index[iid]
        theme = e["theme"]
        if theme:
            themed.setdefault(theme, []).append(iid)
        else:
            # Unanchored: no theme and no Blocks: link toward any item
            unanchored.append(iid)

    if emit_json:
        out = {
            "themes": {
                t: [
                    {
                        "id": i,
                        "repo": all_issues_index[i]["repo"],
                        "status": all_issues_index[i]["status"],
                        "effort": all_issues_index[i]["effort"],
                        "title": all_issues_index[i]["title"],
                        "ready": item_is_ready(i),
                        "bundle_hint": all_issues_index[i]["bundle_hint"],
                    }
                    for i in ids
                ]
                for t, ids in themed.items()
            },
            "unanchored": [
                {
                    "id": i,
                    "repo": all_issues_index[i]["repo"],
                    "status": all_issues_index[i]["status"],
                    "effort": all_issues_index[i]["effort"],
                    "title": all_issues_index[i]["title"],
                }
                for i in unanchored
            ],
        }
        print(json.dumps(out, indent=2))
    else:
        for theme in all_themes_vocab:
            ids = themed.get(theme, [])
            if not ids:
                continue
            print(f"## {theme}")
            print("")
            bundles: dict[str, list] = {}
            solo = []
            for iid in ids:
                hint = all_issues_index[iid]["bundle_hint"]
                if hint:
                    bundles.setdefault(hint, []).append(iid)
                else:
                    solo.append(iid)
            for iid in solo:
                e = all_issues_index[iid]
                ready_mark = " [ready]" if item_is_ready(iid) else ""
                print(f"  {iid} [{e['status']}][{e['effort']}]{ready_mark} {e['title']}  ({e['repo']})")
            for hint, bids in bundles.items():
                print(f"  bundle: {hint}")
                for iid in bids:
                    e = all_issues_index[iid]
                    ready_mark = " [ready]" if item_is_ready(iid) else ""
                    print(f"    {iid} [{e['status']}][{e['effort']}]{ready_mark} {e['title']}  ({e['repo']})")
            print("")

        # Any themes not in vocab (items with non-vocab theme values)
        extra_themes = [t for t in themed if t not in all_themes_vocab]
        for theme in sorted(extra_themes):
            ids = themed[theme]
            print(f"## {theme} (not in vocab)")
            print("")
            for iid in ids:
                e = all_issues_index[iid]
                ready_mark = " [ready]" if item_is_ready(iid) else ""
                print(f"  {iid} [{e['status']}][{e['effort']}]{ready_mark} {e['title']}  ({e['repo']})")
            print("")

        if unanchored:
            print(f"## (unanchored — no Theme and no Blocks: path to an anchor)")
            print("")
            for iid in unanchored:
                e = all_issues_index[iid]
                print(f"  {iid} [{e['status']}][{e['effort']}] {e['title']}  ({e['repo']})")
            print("")

    raise SystemExit(0)

if mode == "critical-path":
    resolved_target = resolve_id(target_id)
    if resolved_target not in all_issues_index:
        print(f"ERROR: target ID `{target_id}` not found in any backlog root")
        raise SystemExit(1)
    target_id = resolved_target

    # Build reverse: for each ID, what items does it block?
    reverse: dict[str, list] = {}
    for iid, e in all_issues_index.items():
        for dep in e["depends_on"]:
            rdep = resolve_id(dep)
            reverse.setdefault(rdep, []).append(iid)

    def find_all_ancestors(iid, memo=None):
        if memo is None:
            memo = {}
        if iid in memo:
            return memo[iid]
        entry = all_issues_index.get(iid, {})
        deps = [resolve_id(d) for d in entry.get("depends_on", [])]
        if not deps:
            memo[iid] = [[iid]]
            return [[iid]]
        paths = []
        for dep in deps:
            for sub_path in find_all_ancestors(dep, memo):
                paths.append(sub_path + [iid])
        if not paths:
            paths = [[iid]]
        memo[iid] = paths
        return paths

    all_paths = find_all_ancestors(target_id)
    # Longest path is the critical path
    critical = max(all_paths, key=len) if all_paths else [target_id]

    if emit_json:
        steps = []
        for iid in critical:
            e = all_issues_index.get(iid, {})
            steps.append({
                "id": iid,
                "repo": e.get("repo", ""),
                "status": e.get("status", ""),
                "effort": e.get("effort", ""),
                "title": e.get("title", iid),
                "workable_now": item_is_ready(iid),
            })
        print(json.dumps({"target": target_id, "critical_path": steps}, indent=2))
    else:
        print(f"Critical path to {target_id}")
        print("")
        for i, iid in enumerate(critical):
            e = all_issues_index.get(iid, {})
            status = e.get("status", "?")
            effort = e.get("effort", "?")
            title = e.get("title", iid)
            repo = e.get("repo", "")
            workable = item_is_ready(iid)
            marker = "[workable now]" if workable else f"[{status}]"
            indent = "  " * i
            arrow = "-> " if i > 0 else ""
            print(f"{indent}{arrow}{iid} {marker}[{effort}] {title}  ({repo})")
        print("")
        print(f"Path length: {len(critical)} steps")

    raise SystemExit(0)

if mode == "mermaid":
    # Collect themes vocab
    all_themes_vocab = []
    for issue in all_active:
        for t in issue.get("themes_vocab", []):
            if t not in all_themes_vocab:
                all_themes_vocab.append(t)

    active_open_ids = [
        iid for iid, e in all_issues_index.items()
        if e["status"] in {"open", "in-progress", "blocked"}
    ]

    # Build dependency edges (only among active items)
    active_set = set(active_open_ids)
    edges = []
    for iid in active_open_ids:
        for dep in all_issues_index[iid]["depends_on"]:
            if dep in active_set:
                edges.append((dep, iid))

    # Theme grouping for subgraph coloring
    theme_members: dict[str, list] = {}
    for iid in active_open_ids:
        t = all_issues_index[iid]["theme"]
        if t:
            theme_members.setdefault(t, []).append(iid)

    def node_id(iid):
        return re.sub(r"[^a-zA-Z0-9_-]", "_", iid)

    def node_label(iid):
        e = all_issues_index[iid]
        status = e["status"]
        effort = e["effort"]
        title = e["title"][:40].replace('"', "'")
        marker = "✓" if item_is_ready(iid) else ""
        nid = node_id(iid)
        return f'{nid}["{iid} {marker}\\n{title}\\n[{status}][{effort}]"]'

    lines = ["# Portfolio diagram", "", "Generated by `aggregate.sh --mermaid`. Do not edit manually.", "", "```mermaid", "flowchart TD"]

    # Subgraphs per theme
    for theme in all_themes_vocab:
        members = theme_members.get(theme, [])
        if not members:
            continue
        safe_theme = re.sub(r"[^a-zA-Z0-9_]", "_", theme)
        lines.append(f"  subgraph {safe_theme}[\"{theme}\"]")
        for iid in sorted(members):
            lines.append(f"    {node_label(iid)}")
        lines.append("  end")

    # Unthemed nodes
    unthemed = [iid for iid in active_open_ids if not all_issues_index[iid]["theme"]]
    if unthemed:
        lines.append("  subgraph unanchored[\"(unanchored)\"]")
        for iid in sorted(unthemed):
            lines.append(f"    {node_label(iid)}")
        lines.append("  end")

    # Edges — use sanitized node IDs on both sides
    for src, dst in edges:
        lines.append(f"  {node_id(src)} --> {node_id(dst)}")

    lines.append("```")
    lines.append("")

    portfolio_path = repo_root / "backlog" / "portfolio.md"
    content = "\n".join(lines) + "\n"
    portfolio_path.write_text(content, encoding="utf-8")
    print(f"Written: {portfolio_path}")
    raise SystemExit(0)

# Default: plan output
active_status_order = {"open": 0, "in-progress": 1, "blocked": 2}
effort_order = {"S": 0, "M": 1, "L": 2, "XL": 3}

active_rows = []
for issue in all_active:
    fields = issue["fields"]
    status = fields.get("Status", "")
    if status not in active_status_order:
        continue
    active_rows.append(
        {
            "repo": issue["repo"],
            "id": fields.get("ID", issue["header_id"]),
            "status": status,
            "effort": fields.get("Effort", ""),
            "surface": fields.get("Fix surface", ""),
            "title": fields.get("Title", issue["header_title"]),
            "depends": fields.get("Depends on", ""),
        }
    )

active_rows.sort(
    key=lambda r: (
        effort_order.get(r["effort"], 99),
        active_status_order.get(r["status"], 99),
        r["id"],
    )
)

print("Unified active queue")
print("")
print("| Repo | ID | Status | Effort | Surface | Title | Depends on |")
print("|---|---|---|---|---|---|---|")
for row in active_rows:
    print(
        f"| {row['repo']} | {row['id']} | {row['status']} | {row['effort']} | {row['surface']} | {row['title']} | {row['depends']} |"
    )

slated_rows = []
for issue in all_slated:
    fields = issue["fields"]
    if fields.get("Status", "") != "slated":
        continue
    slated_rows.append(
        {
            "repo": issue["repo"],
            "id": fields.get("ID", issue["header_id"]),
            "title": fields.get("Title", issue["header_title"]),
            "slated": fields.get("Slated", ""),
            "reevaluate": fields.get("Re-evaluate by", ""),
            "depends": fields.get("Depends on", ""),
        }
    )

if slated_rows:
    slated_rows.sort(key=lambda r: (r["reevaluate"], r["id"]))
    print("")
    print("Unified slated queue")
    print("")
    print("| Repo | ID | Slated | Re-evaluate by | Title | Depends on |")
    print("|---|---|---|---|---|---|")
    for row in slated_rows:
        print(
            f"| {row['repo']} | {row['id']} | {row['slated']} | {row['reevaluate']} | {row['title']} | {row['depends']} |"
        )

cross_repo = []
id_to_repo = {row["id"]: row["repo"] for row in active_rows}
for row in active_rows:
    for dep in csv_ids(row["depends"]):
        dep_repo = id_to_repo.get(dep)
        if dep_repo and dep_repo != row["repo"]:
            cross_repo.append((row["id"], row["repo"], dep, dep_repo))

if cross_repo:
    print("")
    print("Dependency-aware ordering notes")
    for issue_id, issue_repo, dep_id, dep_repo in cross_repo:
        print(f"- {issue_id} [{issue_repo}] depends on {dep_id} [{dep_repo}]")
else:
    print("")
    print("Dependency-aware ordering notes")
    print("- No cross-repo dependencies found in active issues.")
PY