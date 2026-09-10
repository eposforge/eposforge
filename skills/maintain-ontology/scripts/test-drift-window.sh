#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# test-drift-window.sh — no LLM, no network. The drift window is the last
# full KG rebuild, never the last TTL edit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIFT="${SCRIPT_DIR}/drift-window.sh"
PASS=0
FAIL=0
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }

mk_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email "drift-test@example.test"
  git -C "$d" config user.name "drift-test"
  git -C "$d" config commit.gpgsign false
  git -C "$d" checkout -q -b main
}

seed_state_db() {
  local db="$1" day="$2"
  python3 - "$db" "$day" <<'PY'
import sqlite3, sys
db, day = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db)
con.execute(
    "CREATE TABLE tracked_files (file_path TEXT PRIMARY KEY, dataset_id TEXT, "
    "data_id TEXT, content_hash TEXT, synced_at TEXT NOT NULL)"
)
for i in range(10):
    con.execute(
        "INSERT INTO tracked_files VALUES (?,?,?,?,?)",
        (f"/tmp/doc{i}.md", "ds", f"id{i}", f"h{i}", f"{day}T12:00:0{i}+00:00"),
    )
con.commit()
PY
}

echo "== stamp commit wins over a later TTL edit"
REPO="$TMP/stamp"
mk_repo "$REPO"
mkdir -p "$REPO/.eposforge/spec-graph/cognee/sync" "$REPO/00-vision" "$REPO/01-architecture"
printf 'rebuild\n' > "$REPO/.eposforge/spec-graph/cognee/sync/.cognee-state.db"
printf 'old\n' > "$REPO/00-vision/01-ontology.ttl"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "KG Rebuild"
REBUILD="$(git -C "$REPO" rev-parse HEAD)"
printf 'commit=%s\ndate=2020-01-01T00:00:00Z\n' "$REBUILD" \
  > "$REPO/.eposforge/spec-graph/cognee/sync/last-full-rebuild"
printf 'new term\n' > "$REPO/00-vision/01-ontology.ttl"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "TTL only"
printf 'later\n' > "$REPO/01-architecture/foo.md"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "later md"
OUT="$(bash "$DRIFT" --repo "$REPO")"
if echo "$OUT" | grep -q "rebuild_commit=${REBUILD}"; then ok "stamp uses rebuild commit"; else bad "stamp uses rebuild commit" "$OUT"; fi
TTL_LAST="$(git -C "$REPO" log -1 --format=%H -- 00-vision/01-ontology.ttl)"
if echo "$OUT" | grep -q "rebuild_commit=${TTL_LAST}"; then bad "stamp must not report last TTL as rebuild" "$OUT"; else ok "stamp does not report last TTL as rebuild"; fi
if echo "$OUT" | grep -qx "01-architecture/foo.md"; then ok "stamp window lists later md"; else bad "stamp window lists later md" "$OUT"; fi

echo "== state-db majority date, no stamp, later TTL edit"
REPO="$TMP/infer"
mk_repo "$REPO"
mkdir -p "$REPO/.eposforge/spec-graph/cognee/sync" "$REPO/00-vision" "$REPO/04-standards"
seed_state_db "$REPO/.eposforge/spec-graph/cognee/sync/.cognee-state.db" "2020-02-02"
git -C "$REPO" add -A
GIT_COMMITTER_DATE="2020-02-02T12:00:00Z" GIT_AUTHOR_DATE="2020-02-02T12:00:00Z" \
  git -C "$REPO" commit -q -m "state after rebuild"
REBUILD="$(git -C "$REPO" rev-parse HEAD)"
printf 'ttl later\n' > "$REPO/00-vision/01-ontology.ttl"
git -C "$REPO" add -A
GIT_COMMITTER_DATE="2020-03-03T12:00:00Z" GIT_AUTHOR_DATE="2020-03-03T12:00:00Z" \
  git -C "$REPO" commit -q -m "TTL only"
printf 'std\n' > "$REPO/04-standards/new.md"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "new standard"
OUT="$(bash "$DRIFT" --repo "$REPO")"
if echo "$OUT" | grep -q "rebuild_commit=${REBUILD}"; then ok "infer uses state-db rebuild commit"; else bad "infer uses state-db rebuild commit" "$OUT"; fi
TTL_LAST="$(git -C "$REPO" log -1 --format=%H -- 00-vision/01-ontology.ttl)"
if [[ "$TTL_LAST" == "$REBUILD" ]]; then bad "fixture: TTL last should differ from rebuild"; fi
if echo "$OUT" | grep -q "rebuild_commit=${TTL_LAST}"; then bad "infer must not report last TTL as rebuild" "$OUT"; else ok "infer does not report last TTL as rebuild"; fi
if echo "$OUT" | grep -qx "04-standards/new.md"; then ok "infer window lists later md"; else bad "infer window lists later md" "$OUT"; fi

echo "== missing stamp and missing state db fails closed (no TTL fallback)"
REPO="$TMP/empty"
mk_repo "$REPO"
git -C "$REPO" commit -q --allow-empty -m "root"
rc=0
OUT="$(bash "$DRIFT" --repo "$REPO" 2>&1)" || rc=$?
if [[ "$rc" -eq 2 ]] && echo "$OUT" | grep -q "do not use the last TTL edit"; then
  ok "fails closed without TTL fallback"
else
  bad "fails closed without TTL fallback" "rc=$rc $OUT"
fi

echo
echo "passed=${PASS} failed=${FAIL}"
if [[ "$FAIL" -ne 0 ]]; then exit 1; fi
