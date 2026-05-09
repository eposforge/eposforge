"""Phase 2 integration tests — updatefile behavior (the GraphRAG-burn test).

Proves that content edits to a same-named file are reflected in the dataset and
that old content is evicted. This is the test GraphRAG failed: content edits were
silently ignored because only filenames were tracked.

Assertion mechanism: ``list_documents`` (file-level presence/absence) rather than
CHUNKS semantic search. CHUNKS vector search for UUID-like tokens doesn't produce
reliable matches; ``list_documents`` shows what is actually stored in the dataset
and is the correct tool for eviction verification.

Run via the secrets resolver::

    python instance/installed/12-secrets-key-management/bin/epos-secrets \\
        uv run pytest -m integration -v -s
"""

from __future__ import annotations

import uuid
from collections.abc import Callable
from typing import Any

import pytest

from cognee_sync.client import CogneeClient


def _doc_ids(docs: list[dict[str, Any]]) -> set[str]:
    """Extract all plausible id fields from list_documents items."""
    ids: set[str] = set()
    for d in docs:
        if not isinstance(d, dict):
            continue
        for key in ("id", "data_id", "dataId", "document_id"):
            val = d.get(key)
            if val:
                ids.add(str(val))
    return ids


def _make_tokens() -> tuple[str, str]:
    alpha = f"phase2-alpha-{uuid.uuid4().hex[:8]}"
    beta = f"phase2-beta-{uuid.uuid4().hex[:8]}"
    return alpha, beta


@pytest.mark.integration
def test_updated_content_is_queryable(
    client: CogneeClient,
    updated_dataset: Callable[..., tuple[str, str, str]],
    dataset_name: str,
) -> None:
    """Beta content is present in the dataset after re-add (verified via list_documents)."""
    alpha_token, beta_token = _make_tokens()
    dataset_id, alpha_data_id, beta_data_id = updated_dataset(
        dataset_name, alpha_token, beta_token
    )

    docs = client.list_documents(dataset_id)
    doc_ids = _doc_ids(docs)

    print(f"\n[Phase 2] list_documents after alpha+beta add ({len(docs)} items):")
    for d in docs:
        print(f"  {d!r}")
    print(f"[Phase 2] extracted doc_ids: {doc_ids!r}")
    print(f"[Phase 2] alpha_data_id: {alpha_data_id!r}")
    print(f"[Phase 2] beta_data_id:  {beta_data_id!r}")

    assert len(docs) >= 1, (
        f"Expected at least 1 doc after beta add, got {len(docs)}"
    )
    if doc_ids:
        assert beta_data_id in doc_ids, (
            f"beta_data_id {beta_data_id!r} not found in dataset.\n"
            f"doc_ids present: {doc_ids!r}"
        )


@pytest.mark.integration
@pytest.mark.xfail(
    strict=True,
    reason=(
        "Cognee accumulates on re-add with new content (2 docs, not 1). "
        "Update = delete_document + add_file. Phase 5 must persist data_id per path. "
        "Mark xfail so XPASS alerts if Cognee ever changes to evict automatically."
    ),
)
def test_updated_content_evicts_old_content(
    client: CogneeClient,
    updated_dataset: Callable[..., tuple[str, str, str]],
    dataset_name: str,
) -> None:
    """THE GraphRAG-burn test: re-adding with new content must evict the old entry.

    Pass (count == 1): re-add alone evicts — Phase 5 can use simple re-add for updates.
    Fail (count == 2): accumulation — Phase 5 must use explicit delete+add.
    Follow the Phase 2 failure rule in the plan before deciding to continue.
    """
    alpha_token, beta_token = _make_tokens()
    dataset_id, alpha_data_id, beta_data_id = updated_dataset(
        dataset_name, alpha_token, beta_token
    )

    docs = client.list_documents(dataset_id)
    doc_ids = _doc_ids(docs)

    print(f"\n[Phase 2] list_documents after alpha+beta add ({len(docs)} items):")
    for d in docs:
        print(f"  {d!r}")
    print(f"[Phase 2] alpha_data_id: {alpha_data_id!r}")
    print(f"[Phase 2] beta_data_id:  {beta_data_id!r}")
    print(f"[Phase 2] alpha in doc_ids: {alpha_data_id in doc_ids}")
    print(f"[Phase 2] beta in doc_ids:  {beta_data_id in doc_ids}")

    assert len(docs) == 1, (
        f"Expected 1 doc after re-add (eviction), got {len(docs)}.\n"
        f"Re-add does NOT evict old content — accumulation detected.\n"
        f"doc_ids: {doc_ids!r}\n"
        "Phase 5 must use explicit delete_document + add_file for updates."
    )
    if doc_ids:
        assert alpha_data_id not in doc_ids, (
            f"alpha_data_id {alpha_data_id!r} still present after beta re-add.\n"
            f"doc_ids: {doc_ids!r}"
        )


@pytest.mark.integration
def test_explicit_delete_and_readd_evicts_old_content(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Explicit delete_document + re-add is the guaranteed update path.

    This test must pass regardless of test_updated_content_evicts_old_content's outcome.
    If this fails, stop and evaluate: Cognee may be accumulation-only.
    """
    alpha_token, beta_token = _make_tokens()

    alpha_response = dataset_lifecycle(
        dataset_name,
        f"# explicit update test\n\n{alpha_token}\n",
        "explicit-update-test.md",
    )
    dataset_id: str = alpha_response["dataset_id"]
    alpha_data_id: str = alpha_response["data_ingestion_info"][0]["data_id"]

    docs_before = client.list_documents(dataset_id)
    print(f"\n[Phase 2] docs before delete: {len(docs_before)} items")

    client.delete_document(dataset_id, alpha_data_id)

    docs_after_delete = client.list_documents(dataset_id)
    print(f"[Phase 2] docs after delete: {len(docs_after_delete)} items")
    for d in docs_after_delete:
        print(f"  {d!r}")

    beta_response = client.add_file(
        dataset_name=dataset_name,
        content=f"# explicit update test\n\n{beta_token}\n",
        filename="explicit-update-test.md",
    )
    beta_data_id: str = beta_response["data_ingestion_info"][0]["data_id"]

    docs_final = client.list_documents(dataset_id)
    doc_ids_final = _doc_ids(docs_final)
    print(f"[Phase 2] docs after beta re-add: {len(docs_final)} items")
    for d in docs_final:
        print(f"  {d!r}")

    assert alpha_data_id not in doc_ids_final or not doc_ids_final, (
        f"alpha_data_id {alpha_data_id!r} still present after explicit delete+readd.\n"
        f"doc_ids: {doc_ids_final!r}\n"
        "Stop and evaluate: Cognee may not evict content even on explicit delete."
    )
    assert len(docs_final) >= 1, (
        f"Expected at least 1 doc after re-add of beta, got {len(docs_final)}"
    )


@pytest.mark.integration
def test_data_id_behavior_on_content_change(
    client: CogneeClient,
    updated_dataset: Callable[..., tuple[str, str, str]],
    dataset_name: str,
) -> None:
    """Records whether data_id is stable across a content change — Phase 5 planning data.

    Same data_id = in-place update semantics (Phase 5 need not persist data_id).
    Different data_id = delete+add semantics (Phase 5 must persist data_id per path).
    """
    alpha_token, beta_token = _make_tokens()
    dataset_id, alpha_data_id, beta_data_id = updated_dataset(
        dataset_name, alpha_token, beta_token
    )

    docs = client.list_documents(dataset_id)
    doc_ids = _doc_ids(docs)

    print(f"\n[Phase 2 discovery] alpha_data_id: {alpha_data_id!r}")
    print(f"[Phase 2 discovery] beta_data_id:  {beta_data_id!r}")
    print(f"[Phase 2 discovery] list_documents ({len(docs)} items): {doc_ids!r}")

    if alpha_data_id == beta_data_id:
        print("[Phase 2 discovery] data_id STABLE: in-place update semantics")
        print("  ->Phase 5 does NOT need to persist data_id per file path")
    else:
        print("[Phase 2 discovery] data_id CHANGED: delete+add semantics")
        print("  ->Phase 5 MUST persist data_id per tracked file path")
