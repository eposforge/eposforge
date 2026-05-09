"""Sync engine: add / update / delete operations against Cognee via CogneeClient.

Each function is idempotent:
- sync_add with unchanged content -> skip (no API call)
- sync_update with unchanged content -> skip (no API call)
- sync_delete of an untracked path -> no-op

All functions return a result dict with at minimum ``action`` and ``file_path``.
``action`` is one of: "add", "update", "delete", "skip".
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .client import CogneeClient
from .state import StateStore, sha256

SyncResult = dict[str, Any]


def sync_add(
    client: CogneeClient,
    state: StateStore,
    dataset_name: str,
    file_path: str,
    content: str | bytes,
) -> SyncResult:
    """Add a file to Cognee and record it in the state store.

    If the file is already tracked with identical content, returns a "skip"
    result without calling the API.
    """
    chash = sha256(content)
    existing = state.get(file_path)
    if existing and existing.content_hash == chash:
        return {
            "action": "skip",
            "file_path": file_path,
            "dataset_id": existing.dataset_id,
            "data_id": existing.data_id,
            "reason": "identical content",
        }

    filename = Path(file_path).name
    resp = client.add_file(dataset_name=dataset_name, content=content, filename=filename)
    dataset_id: str = resp["dataset_id"]
    data_id: str = resp["data_ingestion_info"][0]["data_id"]
    state.upsert(file_path, dataset_id, data_id, chash)
    return {
        "action": "add",
        "file_path": file_path,
        "dataset_id": dataset_id,
        "data_id": data_id,
    }


def sync_update(
    client: CogneeClient,
    state: StateStore,
    dataset_name: str,
    file_path: str,
    content: str | bytes,
) -> SyncResult:
    """Update a tracked file: delete the old data_id then add the new content.

    If content is unchanged, returns "skip" without calling the API.
    If the file is not yet tracked, falls through to sync_add.
    """
    chash = sha256(content)
    existing = state.get(file_path)
    if existing:
        if existing.content_hash == chash:
            return {
                "action": "skip",
                "file_path": file_path,
                "dataset_id": existing.dataset_id,
                "data_id": existing.data_id,
                "reason": "identical content",
            }
        client.delete_document(existing.dataset_id, existing.data_id)

    result = sync_add(client, state, dataset_name, file_path, content)
    if result["action"] == "add":
        result["action"] = "update"
    return result


def sync_delete(
    client: CogneeClient,
    state: StateStore,
    file_path: str,
) -> SyncResult:
    """Remove a tracked file from Cognee and erase its state record.

    If the file is not tracked, returns "skip" without calling the API.
    """
    existing = state.get(file_path)
    if not existing:
        return {"action": "skip", "file_path": file_path, "reason": "not tracked"}

    client.delete_document(existing.dataset_id, existing.data_id)
    state.delete(file_path)
    return {
        "action": "delete",
        "file_path": file_path,
        "dataset_id": existing.dataset_id,
        "data_id": existing.data_id,
    }
