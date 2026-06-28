"""Phase 3 integration tests — deletefile behavior.

Proves that delete_document evicts content from the dataset, characterises
shared-content behavior when one of two documents is deleted, and confirms
delete + re-add is a clean round-trip with no tombstones.

Assertion mechanism: ``list_documents`` for file-level presence/absence.
CHUNKS search is attempted for KG-level checks but treated as advisory —
Phase 2 established that semantic search for UUID-like tokens is unreliable;
results are printed rather than hard-asserted.

Run via the secrets resolver::

    python instance/secrets-key-management/bin/epos-secrets \\
        uv run pytest -m integration -v -s
"""

from __future__ import annotations

import uuid
from collections.abc import Callable
from typing import Any

import pytest

from cognee_sync.client import CogneeClient


def _doc_ids(docs: list[dict[str, Any]]) -> set[str]:
    ids: set[str] = set()
    for d in docs:
        if isinstance(d, dict):
            val = d.get("id") or d.get("data_id")
            if val:
                ids.add(str(val))
    return ids


def _tok() -> str:
    return f"phase3-{uuid.uuid4().hex[:10]}"


@pytest.mark.integration
def test_delete_removes_document_from_list(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """delete_document is reflected immediately in list_documents."""
    token = _tok()
    resp = dataset_lifecycle(dataset_name, f"# delete test\n\n{token}\n", "del-test.md")
    dataset_id: str = resp["dataset_id"]
    data_id: str = resp["data_ingestion_info"][0]["data_id"]

    docs_before = client.list_documents(dataset_id)
    assert data_id in _doc_ids(docs_before), "doc not in list before delete"

    client.delete_document(dataset_id, data_id)

    docs_after = client.list_documents(dataset_id)
    print(f"\n[Phase 3] docs after delete: {len(docs_after)}")
    for d in docs_after:
        print(f"  {d!r}")

    assert data_id not in _doc_ids(docs_after), (
        f"data_id {data_id!r} still in list_documents after delete"
    )
    assert len(docs_after) == 0, (
        f"Expected 0 docs after delete, got {len(docs_after)}"
    )


@pytest.mark.integration
def test_delete_is_synchronous(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """list_documents reflects delete immediately — no polling needed by Phase 5."""
    token = _tok()
    resp = dataset_lifecycle(dataset_name, f"# sync test\n\n{token}\n", "sync-test.md")
    dataset_id: str = resp["dataset_id"]
    data_id: str = resp["data_ingestion_info"][0]["data_id"]

    assert len(client.list_documents(dataset_id)) == 1

    client.delete_document(dataset_id, data_id)

    docs_after = client.list_documents(dataset_id)
    print(f"\n[Phase 3] docs immediately after delete (no sleep): {len(docs_after)}")

    assert len(docs_after) == 0, (
        f"Delete is NOT synchronous — doc still present immediately after.\n"
        f"Phase 5 will need to poll list_documents after delete."
    )


@pytest.mark.integration
def test_delete_and_readd_is_clean_roundtrip(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """delete_document + add_file is a clean round-trip — no tombstones block re-add."""
    token = _tok()
    resp = dataset_lifecycle(dataset_name, f"# roundtrip test\n\n{token}\n", "roundtrip.md")
    dataset_id: str = resp["dataset_id"]
    original_data_id: str = resp["data_ingestion_info"][0]["data_id"]

    client.delete_document(dataset_id, original_data_id)
    assert len(client.list_documents(dataset_id)) == 0, "not fully deleted before re-add"

    resp2 = client.add_file(
        dataset_name=dataset_name,
        content=f"# roundtrip test\n\n{token}\n",
        filename="roundtrip.md",
    )
    new_data_id: str = resp2["data_ingestion_info"][0]["data_id"]
    new_status: str = resp2.get("status", "")

    docs_final = client.list_documents(dataset_id)
    print(f"\n[Phase 3] re-add status: {new_status!r}")
    print(f"[Phase 3] original_data_id: {original_data_id!r}")
    print(f"[Phase 3] new_data_id:      {new_data_id!r}")
    print(f"[Phase 3] docs after re-add: {len(docs_final)}")

    assert len(docs_final) == 1, (
        f"Expected 1 doc after delete+readd, got {len(docs_final)}. Possible tombstone."
    )
    assert new_data_id in _doc_ids(docs_final), (
        f"new_data_id {new_data_id!r} not found in list_documents after re-add"
    )

    if new_data_id == original_data_id:
        print("[Phase 3 discovery] data_id SAME after delete+readd — content-hash dedup still active")
    else:
        print("[Phase 3 discovery] data_id NEW after delete+readd — clean re-ingestion, no tombstone")


@pytest.mark.integration
def test_shared_content_behavior_on_partial_delete(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Characterises what happens to doc B when doc A (sharing content) is deleted.

    File-level check (list_documents) is hard-asserted: B must remain after A deleted.
    KG-level check (CHUNKS search) is advisory and printed — semantic search for
    UUID tokens is unreliable. The finding informs whether Phase 5 needs
    shared-entity tracking.
    """
    token_shared = _tok()   # in both docs
    token_a_only = _tok()   # only in doc A
    token_b_only = _tok()   # only in doc B

    # Doc A through dataset_lifecycle (registers dataset_id for teardown).
    resp_a = dataset_lifecycle(
        dataset_name,
        f"# doc a\n\n{token_shared}\n\n{token_a_only}\n",
        "shared-a.md",
    )
    dataset_id: str = resp_a["dataset_id"]
    data_id_a: str = resp_a["data_ingestion_info"][0]["data_id"]

    # Doc B directly (same dataset — teardown via delete_dataset covers it).
    resp_b = client.add_file(
        dataset_name=dataset_name,
        content=f"# doc b\n\n{token_shared}\n\n{token_b_only}\n",
        filename="shared-b.md",
    )
    data_id_b: str = resp_b["data_ingestion_info"][0]["data_id"]

    assert len(client.list_documents(dataset_id)) == 2, "expected 2 docs before delete"

    # Delete only doc A
    client.delete_document(dataset_id, data_id_a)

    docs_after = client.list_documents(dataset_id)
    ids_after = _doc_ids(docs_after)
    a_gone = data_id_a not in ids_after
    b_present = data_id_b in ids_after

    print(f"\n[Phase 3] docs after deleting A: {len(docs_after)}")
    print(f"[Phase 3] A gone from list_documents: {a_gone}")
    print(f"[Phase 3] B present in list_documents: {b_present}")

    # Hard assertions: file-level behavior must be correct.
    assert a_gone, f"data_id_a still in list_documents after delete: {ids_after!r}"
    assert b_present, f"data_id_b missing from list_documents after A deleted: {ids_after!r}"

    # Advisory KG checks — printed, not asserted.
    for label, token in [
        ("token_a_only (unique to deleted doc)", token_a_only),
        ("token_b_only (unique to surviving doc)", token_b_only),
        ("token_shared (in both docs)", token_shared),
    ]:
        try:
            results = client.search(token, "CHUNKS", dataset_ids=[dataset_id], top_k=5)
            texts = [r.get("text", "") for r in results if isinstance(r, dict)]
            found = any(token in t for t in texts)
            print(f"[Phase 3 KG advisory] {label}: found={found}, result_count={len(results)}")
        except Exception as exc:
            print(f"[Phase 3 KG advisory] {label}: search raised {type(exc).__name__}: {exc}")
