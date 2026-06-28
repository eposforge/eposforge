#!/usr/bin/env bash
# Syncs file-based-backlog scripts from a framework clone into an adopter repo.
# Usage:
#   sync-tooling.sh <target-repo-root>          # copy + report changes
#   sync-tooling.sh --check <target-repo-root>  # report drift, exit non-zero if stale
#
# BACKLOG_HOME env or the directory containing this script is the source.
set -euo pipefail

CHECK_ONLY=0
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo "ERROR: multiple target paths given" >&2
        exit 2
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: sync-tooling.sh [--check] <target-repo-root>" >&2
  exit 2
fi

# Resolve source: BACKLOG_HOME env, or the directory containing this script
if [[ -n "${BACKLOG_HOME:-}" ]]; then
  SRC_DIR="$(realpath "${BACKLOG_HOME}/scripts")"
else
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ ! -f "${SRC_DIR}/VERSION" ]]; then
  echo "ERROR: source VERSION file not found at ${SRC_DIR}/VERSION" >&2
  exit 1
fi

SRC_VERSION="$(cat "${SRC_DIR}/VERSION" | tr -d '[:space:]')"

# Target scripts path mirrors the source layout convention.
# For adopters this lands under their eposforge/ container (adopter layout).
DEST_DIR="${TARGET}/eposforge/backlog/file-based-backlog/scripts"

if [[ ! -d "$DEST_DIR" ]]; then
  echo "ERROR: target scripts directory not found: ${DEST_DIR}" >&2
  echo "  Is ${TARGET} an EposForge adopter repo with file-based-backlog installed?" >&2
  echo "  (expected under eposforge/backlog/file-based-backlog/ per current layout)" >&2
  exit 1
fi

DEST_VERSION=""
if [[ -f "${DEST_DIR}/VERSION" ]]; then
  DEST_VERSION="$(cat "${DEST_DIR}/VERSION" | tr -d '[:space:]')"
fi

echo "Source version : ${SRC_VERSION}"
echo "Target version : ${DEST_VERSION:-<missing>}"
echo ""

drift=0
for src_file in "${SRC_DIR}"/*; do
  fname="$(basename "$src_file")"
  dest_file="${DEST_DIR}/${fname}"
  if [[ ! -e "$dest_file" ]]; then
    echo "  MISSING   ${fname}"
    drift=1
    continue
  fi
  if [[ -d "$src_file" ]]; then
    if ! diff -rq "$src_file" "$dest_file" > /dev/null 2>&1; then
      echo "  DIFFERS   ${fname}/  (directory)"
      drift=1
    fi
  elif ! diff -q "$src_file" "$dest_file" > /dev/null 2>&1; then
    src_lines="$(wc -l < "$src_file")"
    dest_lines="$(wc -l < "$dest_file")"
    delta=$(( src_lines - dest_lines ))
    echo "  DIFFERS   ${fname}  (source: ${src_lines} lines, target: ${dest_lines} lines, delta: ${delta:+"+"}${delta})"
    drift=1
  fi
done

if [[ $drift -eq 0 ]]; then
  echo "Target is up to date (${SRC_VERSION})."
  exit 0
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo ""
  echo "Drift detected. Run without --check to sync."
  exit 1
fi

echo ""
echo "Copying scripts from ${SRC_DIR} -> ${DEST_DIR}"
for src_file in "${SRC_DIR}"/*; do
  fname="$(basename "$src_file")"
  dest_file="${DEST_DIR}/${fname}"
  if [[ -d "$src_file" ]]; then
    rm -rf "$dest_file"
    cp -r "$src_file" "$dest_file"
  else
    cp "$src_file" "$dest_file"
    if [[ "$fname" == *.sh ]]; then
      chmod +x "$dest_file"
    fi
  fi
  echo "  updated   ${fname}"
done

echo ""
echo "Sync complete. Target now at ${SRC_VERSION}."
