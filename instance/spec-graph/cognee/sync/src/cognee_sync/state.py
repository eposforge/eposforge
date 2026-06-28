"""SQLite-backed state store mapping file paths to Cognee data_ids.

Schema: file_path (PK), dataset_id, data_id, content_hash (SHA-256 hex), synced_at.
The state store is the sync tool's source of truth for which version of each file
is currently in Cognee. All sync operations read and write through it.
"""

from __future__ import annotations

import hashlib
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class FileRecord:
    file_path: str
    dataset_id: str
    data_id: str
    content_hash: str
    synced_at: str


def sha256(content: str | bytes) -> str:
    """SHA-256 hex digest of content. Used to detect unchanged files."""
    if isinstance(content, str):
        content = content.encode("utf-8")
    return hashlib.sha256(content).hexdigest()


class StateStore:
    """Thin SQLite wrapper. Pass ``":memory:"`` for an isolated in-process store.

    Uses a single persistent connection so ``:memory:`` databases work correctly
    (each new ``sqlite3.connect(":memory:")`` would otherwise open a separate,
    empty database — losing all previously written data).
    """

    def __init__(self, db_path: str | Path = ".cognee-state.db") -> None:
        self._conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init()

    def _init(self) -> None:
        with self._conn:
            self._conn.execute("""
                CREATE TABLE IF NOT EXISTS tracked_files (
                    file_path    TEXT PRIMARY KEY,
                    dataset_id   TEXT NOT NULL,
                    data_id      TEXT NOT NULL,
                    content_hash TEXT NOT NULL,
                    synced_at    TEXT NOT NULL
                )
            """)

    def upsert(
        self,
        file_path: str,
        dataset_id: str,
        data_id: str,
        content_hash: str,
    ) -> None:
        synced_at = datetime.now(timezone.utc).isoformat()
        with self._conn:
            self._conn.execute(
                """
                INSERT INTO tracked_files
                    (file_path, dataset_id, data_id, content_hash, synced_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(file_path) DO UPDATE SET
                    dataset_id   = excluded.dataset_id,
                    data_id      = excluded.data_id,
                    content_hash = excluded.content_hash,
                    synced_at    = excluded.synced_at
                """,
                (file_path, dataset_id, data_id, content_hash, synced_at),
            )

    def get(self, file_path: str) -> FileRecord | None:
        row = self._conn.execute(
            "SELECT * FROM tracked_files WHERE file_path = ?", (file_path,)
        ).fetchone()
        return FileRecord(**dict(row)) if row else None

    def delete(self, file_path: str) -> None:
        with self._conn:
            self._conn.execute(
                "DELETE FROM tracked_files WHERE file_path = ?", (file_path,)
            )

    def list_all(self) -> list[FileRecord]:
        rows = self._conn.execute(
            "SELECT * FROM tracked_files ORDER BY file_path"
        ).fetchall()
        return [FileRecord(**dict(r)) for r in rows]
