"""CLI entry point for cognee-sync.

Usage (invoked via epos-secrets for secret injection):

    epos-secrets uv run cognee-sync --added path/to/file.md
    epos-secrets uv run cognee-sync --modified path/a.md path/b.md
    epos-secrets uv run cognee-sync --deleted path/old.md
    epos-secrets uv run cognee-sync --status

Gitea Actions / post-receive hook pattern:

    ADDED=$(git diff --name-only --diff-filter=A $BASE..$HEAD -- '*.md')
    MODIFIED=$(git diff --name-only --diff-filter=M $BASE..$HEAD -- '*.md')
    DELETED=$(git diff --name-only --diff-filter=D $BASE..$HEAD -- '*.md')
    epos-secrets uv run cognee-sync \\
        ${ADDED:+--added $ADDED} \\
        ${MODIFIED:+--modified $MODIFIED} \\
        ${DELETED:+--deleted $DELETED}

Environment variables (injected by epos-secrets):
    COGNEE_API_URL         Base URL of the Cognee HTTP API (required)
    COGNEE_API_TOKEN       Bearer token (optional — anonymous if absent)
    COGNEE_TLS_VERIFY      false / path to CA bundle (optional)
    COGNEE_DATASET_NAME    Dataset to sync into (default: eposforge-sync)
    COGNEE_STATE_DB        Path to SQLite state store (default: .cognee-state.db)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from .client import CogneeClient
from .config import load_config
from .state import StateStore
from . import sync as _sync

# Default state DB lives alongside the sync project itself, committed to source.
# cli.py is at src/cognee_sync/cli.py; three parents up = sync/
_DEFAULT_STATE_DB = str(Path(__file__).parent.parent.parent / ".cognee-state.db")


def _state_store(args: argparse.Namespace) -> StateStore:
    db_path = args.db or os.environ.get("COGNEE_STATE_DB", _DEFAULT_STATE_DB)
    return StateStore(db_path)


def _dataset_name(args: argparse.Namespace) -> str:
    return args.dataset or os.environ.get("COGNEE_DATASET_NAME", "eposforge-sync")


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="cognee-sync",
        description="Sync EposForge Markdown files to the Cognee knowledge graph.",
    )
    parser.add_argument("--dataset", default=None, metavar="NAME",
                        help="Cognee dataset name (default: $COGNEE_DATASET_NAME or 'eposforge-sync')")
    parser.add_argument("--db", default=None, metavar="PATH",
                        help="State DB path (default: $COGNEE_STATE_DB or '.cognee-state.db')")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print planned actions without calling the API")
    parser.add_argument("--status", action="store_true",
                        help="List tracked files and exit")
    parser.add_argument("--added", nargs="*", default=[], metavar="FILE",
                        help="Files to add (new to Cognee)")
    parser.add_argument("--modified", nargs="*", default=[], metavar="FILE",
                        help="Files to update (delete old + add new)")
    parser.add_argument("--deleted", nargs="*", default=[], metavar="FILE",
                        help="Files to remove from Cognee")

    args = parser.parse_args()

    if args.status:
        state = _state_store(args)
        records = state.list_all()
        if not records:
            print("No files tracked.")
        else:
            print(f"{'file_path':<60}  {'data_id':>8}  synced_at")
            print("-" * 95)
            for r in records:
                print(f"{r.file_path:<60}  {r.data_id[:8]}...  {r.synced_at}")
        sys.exit(0)

    if not any([args.added, args.modified, args.deleted]):
        parser.print_help()
        sys.exit(0)

    if args.dry_run:
        for f in (args.added or []):
            print(f"[dry-run] add:    {f}")
        for f in (args.modified or []):
            print(f"[dry-run] update: {f}")
        for f in (args.deleted or []):
            print(f"[dry-run] delete: {f}")
        sys.exit(0)

    config = load_config()
    state = _state_store(args)
    dataset_name = _dataset_name(args)

    with CogneeClient(
        base_url=config.api_url,
        token=config.api_token,
        verify=config.tls_verify,
    ) as client:
        for file_path in (args.added or []):
            content = Path(file_path).read_bytes()
            result = _sync.sync_add(client, state, dataset_name, file_path, content)
            print(f"{result['action']:8} {file_path}")

        for file_path in (args.modified or []):
            content = Path(file_path).read_bytes()
            result = _sync.sync_update(client, state, dataset_name, file_path, content)
            print(f"{result['action']:8} {file_path}")

        for file_path in (args.deleted or []):
            result = _sync.sync_delete(client, state, file_path)
            print(f"{result['action']:8} {file_path}")

    sys.exit(0)
