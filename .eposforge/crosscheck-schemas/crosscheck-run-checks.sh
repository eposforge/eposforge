#!/usr/bin/env bash
# crosscheck-run-checks.sh — execute every mechanical claim before the reviewer spawns.
#
#   crosscheck-run-checks.sh --handoff <file> [--out-dir <dir>] [--cwd <path>] [--strict]
#
# Each mechanical claim runs in its own directory: claim.cwd if set, otherwise
# the unique scope repo that contains its files[], otherwise --cwd, otherwise
# the only scope entry. A multi-repo claim that does not resolve is recorded
# as a failed check, not executed in scope[0].
#
# A mechanical claim carries a command and an expected result, which makes it a
# test. Running the tests here, not in the reviewer, is what keeps the reviewer's
# context on the half that actually needs a mind: failures, judgment-class
# claims, and what nobody claimed at all. The reviewer never re-runs a passing
# mechanical claim.
#
# Check types:
#   exit0      the command exits 0
#   equals     trimmed output equals value
#   regex      output matches value (jq/oniguruma regex, applied to the whole output)
#   absent     with a value: the value does not appear in the output
#              without one: the command produced no output at all
#   count-eq   the last non-empty output line parses as a number equal to value
#   count-lt   ... strictly less than value
#
# Output goes to <out-dir>/checks/<claim-id>.out and the payload carries the
# pointer, never the bytes.
#
# Exit: 0 all mechanical claims matched · 10 at least one did not (--strict)
#       · 2 usage / IO. Without --strict a mismatch is recorded, not fatal: a
#       failing claim is exactly the thing the reviewer needs to see.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/budget.sh
. "$SCRIPT_DIR/lib/budget.sh"
# shellcheck source=lib/claim-cwd.sh
. "$SCRIPT_DIR/lib/claim-cwd.sh"

TIMEOUT="${CROSSCHECK_CMD_TIMEOUT:-120}"
OUTPUT_MAX="${CROSSCHECK_CHECK_OUTPUT_MAX:-65536}"
HANDOFF=""; OUT_DIR=""; CWD=""; STRICT=0
usage() { sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "crosscheck-run-checks: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --handoff) HANDOFF="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --cwd)     CWD="$2"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$HANDOFF" ]] || usage
command -v jq >/dev/null 2>&1 || die "jq not found"
[[ -r "$HANDOFF" ]] || die "cannot read $HANDOFF"

[[ -n "$OUT_DIR" ]] || OUT_DIR="$(cd "$(dirname "$HANDOFF")" && pwd)"
mkdir -p "$OUT_DIR/checks" || die "cannot create $OUT_DIR/checks"

# --cwd is an operator fallback, not the directory every claim runs in.
# Per-claim resolution is below; a missing fallback is fine.
if [[ -n "$CWD" && ! -d "$CWD" ]]; then
  die "working directory not found: $CWD"
fi
FALLBACK_CWD="$CWD"

RESULTS="$(mktemp)" || die "cannot create temp file"
trap 'rm -f "$RESULTS"' EXIT
echo '[]' > "$RESULTS"

ANY_FAIL=0

record_result() {
  local id="$1" rc="$2" matched="$3" ref="$4" run_cwd="${5:-}"
  jq --arg id "$id" --argjson rc "$rc" --argjson m "$matched" --arg ref "$ref" --arg cwd "$run_cwd" \
     '. += [{claim_id:$id, ran:true, exit_code:$rc, matched:$m, output_ref:$ref}
            + (if $cwd == "" then {} else {cwd:$cwd} end)]' \
     "$RESULTS" > "$RESULTS.tmp" && mv "$RESULTS.tmp" "$RESULTS"
}

# JSON lines, not TSV: bash read treats tab as IFS whitespace and collapses
# consecutive empty fields, which is exactly the exit0 + omitted cwd case.
while IFS= read -r row; do
  [[ -n "$row" ]] || continue
  id="$(jq -r '.id' <<<"$row")"
  cmd="$(jq -r '.evidence_cmd' <<<"$row")"
  ctype="$(jq -r '.type' <<<"$row")"
  cvalue="$(jq -r '.value' <<<"$row")"
  claim_cwd="$(jq -r '.cwd' <<<"$row")"
  claim_files="$(jq -r '.files' <<<"$row")"
  [[ -n "$id" && "$id" != "null" ]] || continue
  out="$OUT_DIR/checks/$id.out"
  run_cwd="$(resolve_claim_cwd "$HANDOFF" "$claim_cwd" "$claim_files" "$FALLBACK_CWD" || true)"
  if [[ -z "$run_cwd" ]]; then
    printf '%s\n' "[crosscheck: no cwd — set claim.cwd, or --files that exist in exactly one scope repo]" >"$out"
    rc=2
    matched=false
    ANY_FAIL=1
    printf '%-6s %-9s exit=%-3s matched=%s\n' "$id" "$ctype" "$rc" "$matched"
    record_result "$id" "$rc" false "checks/$id.out" ""
    continue
  fi
  # Bounded in time and in bytes. An unbounded evidence_cmd hangs the loop, and
  # an unbounded output turns the payload directory into the thing that fills
  # the disk. A timeout is not a result: it fails the check and says so.
  timeout --kill-after=10s "$TIMEOUT" bash -c "cd '$run_cwd' && $cmd" >"$out" 2>&1
  rc=$?
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    echo "[crosscheck: killed after ${TIMEOUT}s]" >>"$out"
  fi
  if [[ "$(wc -c <"$out")" -gt "$OUTPUT_MAX" ]]; then
    head -c "$OUTPUT_MAX" "$out" > "$out.trunc"
    printf '\n[crosscheck: truncated at %s bytes]\n' "$OUTPUT_MAX" >> "$out.trunc"
    mv "$out.trunc" "$out"
  fi

  matched=false
  case "$ctype" in
    exit0)
      [[ $rc -eq 0 ]] && matched=true ;;
    equals)
      [[ "$(tr -d '\n' <"$out" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')" == "$cvalue" ]] && matched=true ;;
    regex)
      # Whole output, Oniguruma, as the header documents. grep -Eq is ERE and
      # per-line; (?i)HELLO is true under jq test and a warning under grep.
      jq -Rse --arg p "$cvalue" 'test($p)' "$out" >/dev/null 2>&1 && matched=true ;;
    absent)
      if [[ -z "$cvalue" || "$cvalue" == "null" ]]; then
        [[ ! -s "$out" ]] && matched=true
      else
        grep -Fq -- "$cvalue" "$out" || matched=true
      fi ;;
    count-eq|count-lt)
      # Last non-empty line must itself be an optional-sign integer (grep -c /
      # wc -l shape). Stripping every non-digit turns '58 passed, 0 failed'
      # into 580 and would let count-eq:580 match.
      n="$(grep -v '^[[:space:]]*$' "$out" | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ "$n" =~ ^-?[0-9]+$ ]]; then
        if [[ "$ctype" == "count-eq" ]]; then
          [[ "$n" -eq "$cvalue" ]] && matched=true
        else
          [[ "$n" -lt "$cvalue" ]] && matched=true
        fi
      fi ;;
    *)
      echo "crosscheck-run-checks: $id: unknown check type '$ctype'" >&2 ;;
  esac

  [[ "$matched" == "true" ]] || ANY_FAIL=1
  printf '%-6s %-9s exit=%-3s matched=%s\n' "$id" "$ctype" "$rc" "$matched"
  record_result "$id" "$rc" "$matched" "checks/$id.out" "$run_cwd"
done < <(jq -c '
  .claims[]
  | select(.class == "mechanical")
  | {id, evidence_cmd,
     type: .check.type,
     value: ((.check.value // "") | tostring),
     cwd: (.cwd // ""),
     files: ((.files // []) | join(","))}' "$HANDOFF")

jq --slurpfile r "$RESULTS" '.check_results = $r[0]' "$HANDOFF" > "$HANDOFF.tmp" \
  && mv "$HANDOFF.tmp" "$HANDOFF" \
  || die "failed to write check_results into $HANDOFF"

refresh_budget "$HANDOFF" "$(jq -r '.budget.cap // 8000' "$HANDOFF")" \
  || die "failed to refresh the budget in $HANDOFF"

if (( STRICT )) && (( ANY_FAIL )); then exit 10; fi
exit 0
