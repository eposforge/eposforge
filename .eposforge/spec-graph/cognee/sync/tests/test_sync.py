"""Phase 5 integration tests — the sync engine (state.py + sync.py).

Tests sync_add, sync_update, and sync_delete end-to-end against the live
Cognee API with an in-memory state store so there is no cross-test contamination.

Each test registers its dataset for cleanup via dataset_lifecycle so teardown
calls delete_dataset and leaves no residual state in Cognee.

Run via the secrets resolver::

    python.eposforge/secrets-key-management/bin/epos-secrets \\
        uv run pytest tests/test_sync.py -m integration -v -s
"""

from __future__ import annotations

import uuid
from collections.abc import Callable
from typing import Any

import pytest

from cognee_sync.client import CogneeClient
from cognee_sync.state import StateStore, sha256
from cognee_sync import sync as _sync


def _state() -> StateStore:
    return StateStore(":memory:")


def _tok() -> str:
    return f"phase5-{uuid.uuid4().hex[:8]}"


def _doc_ids(docs: list[dict[str, Any]]) -> set[str]:
    return {str(d["id"]) for d in docs if isinstance(d, dict) and d.get("id")}


@pytest.mark.integration
def test_sync_add(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """sync_add stores a file in Cognee and writes a state record."""
    state = _state()
    token = _tok()
    file_path = f"test/sync-add-{token}.md"
    content = f"# sync add test\n\n{token}\n"

    # Prime dataset via dataset_lifecycle so teardown fires delete_dataset.
    prime = dataset_lifecycle(dataset_name, "# prime\n", "prime.md")
    dataset_id_expected = prime["dataset_id"]

    result = _sync.sync_add(client, state, dataset_name, file_path, content)

    print(f"\n[Phase 5] sync_add result: {result!r}")

    assert result["action"] == "add"
    assert result["dataset_id"] == dataset_id_expected
    assert result["data_id"]

    record = state.get(file_path)
    assert record is not None, "no state record after sync_add"
    assert record.data_id == result["data_id"]
    assert record.dataset_id == result["dataset_id"]
    assert record.content_hash == sha256(content)

    docs = client.list_documents(result["dataset_id"])
    assert result["data_id"] in _doc_ids(docs), (
        f"data_id {result['data_id']!r} not in list_documents after sync_add"
    )


@pytest.mark.integration
def test_sync_add_is_idempotent(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """sync_add with identical content skips the API call on the second call."""
    state = _state()
    token = _tok()
    file_path = f"test/idempotent-{token}.md"
    content = f"# idempotent test\n\n{token}\n"

    dataset_lifecycle(dataset_name, "# prime\n", "prime.md")

    result1 = _sync.sync_add(client, state, dataset_name, file_path, content)
    result2 = _sync.sync_add(client, state, dataset_name, file_path, content)

    print(f"\n[Phase 5] first  sync_add action: {result1['action']!r}")
    print(f"[Phase 5] second sync_add action: {result2['action']!r}")

    assert result1["action"] == "add"
    assert result2["action"] == "skip", (
        f"Expected 'skip' on second identical sync_add, got {result2['action']!r}"
    )
    assert result2["data_id"] == result1["data_id"], "data_id changed on idempotent re-add"

    # State record must match first add — unchanged.
    record = state.get(file_path)
    assert record is not None
    assert record.data_id == result1["data_id"]


@pytest.mark.integration
def test_sync_update(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """sync_update deletes the old data_id and stores new content."""
    state = _state()
    tok_v1 = _tok()
    tok_v2 = _tok()
    file_path = f"test/sync-update-{tok_v1}.md"

    dataset_lifecycle(dataset_name, "# prime\n", "prime.md")

    r1 = _sync.sync_add(client, state, dataset_name, file_path, f"# v1\n\n{tok_v1}\n")
    old_data_id = r1["data_id"]
    dataset_id = r1["dataset_id"]

    r2 = _sync.sync_update(client, state, dataset_name, file_path, f"# v2\n\n{tok_v2}\n")

    print(f"\n[Phase 5] sync_update action: {r2['action']!r}")
    print(f"[Phase 5] old data_id: {old_data_id!r}")
    print(f"[Phase 5] new data_id: {r2['data_id']!r}")

    assert r2["action"] == "update"
    assert r2["data_id"] != old_data_id, "data_id unchanged after sync_update"

    record = state.get(file_path)
    assert record is not None
    assert record.data_id == r2["data_id"], "state record not updated after sync_update"

    docs = client.list_documents(dataset_id)
    doc_ids = _doc_ids(docs)
    assert old_data_id not in doc_ids, "old data_id still in Cognee after sync_update"
    assert r2["data_id"] in doc_ids, "new data_id not in Cognee after sync_update"


@pytest.mark.integration
def test_sync_delete(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """sync_delete removes the document from Cognee and erases the state record."""
    state = _state()
    token = _tok()
    file_path = f"test/sync-delete-{token}.md"

    dataset_lifecycle(dataset_name, "# prime\n", "prime.md")

    r_add = _sync.sync_add(client, state, dataset_name, file_path, f"# del test\n\n{token}\n")
    dataset_id = r_add["dataset_id"]
    data_id = r_add["data_id"]

    r_del = _sync.sync_delete(client, state, file_path)

    print(f"\n[Phase 5] sync_delete action: {r_del['action']!r}")

    assert r_del["action"] == "delete"
    assert state.get(file_path) is None, "state record still present after sync_delete"

    docs = client.list_documents(dataset_id)
    assert data_id not in _doc_ids(docs), (
        f"data_id {data_id!r} still in Cognee after sync_delete"
    )
