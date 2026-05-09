"""Phase 1 integration tests — addfile behavior.

Proves the load-bearing premise: a file added to Cognee is extractable into
the KG and queryable. All tests are marked ``@pytest.mark.integration``.

Run via the secrets resolver::

    python instance/installed/12-secrets-key-management/bin/epos-secrets \\
        uv run pytest -m integration -v -s
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import pytest

from cognee_sync.client import CogneeClient


@pytest.mark.integration
def test_added_file_is_queryable_via_search(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
    unique_token: str,
) -> None:
    """THE load-bearing Phase 1 test.

    Uses dataset_lifecycle (add only, no explicit cognify) to probe whether
    cognify is implicit on add — Phase 0 smoke showed status="PipelineRunCompleted"
    on the add response, which strongly suggests it is.

    If this fails: stop and evaluate. Do not proceed to Phase 2.
    """
    content = f"# canary\n\n{unique_token}\n\nspec graph test content\n"
    add_response = dataset_lifecycle(dataset_name, content)
    dataset_id: str = add_response["dataset_id"]

    result = client.search(unique_token, "GRAPH_COMPLETION", datasets=[dataset_name])
    result_text = str(result)

    print(f"\n[Phase 1] search result type: {type(result)}")
    print(f"[Phase 1] search result: {ascii(result)}")

    assert unique_token in result_text, (
        f"Token {unique_token!r} not found in search response.\n"
        f"dataset_id={dataset_id!r}\n"
        f"search result: {result!r}"
    )


@pytest.mark.integration
def test_cognify_completes_within_timeout(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Explicit cognify call returns without error.

    Documents the cognify response shape and confirms whether add_file
    already ran cognify implicitly (compare status fields between the
    add_response and the cognify_response).
    """
    add_response = dataset_lifecycle(dataset_name, "# cognify test\nsome content\n")

    cognify_response = client.cognify(datasets=[dataset_name])

    print(f"\n[Phase 1 discovery] add_file status:   {add_response.get('status')!r}")
    print(f"[Phase 1 discovery] cognify response:  {cognify_response!r}")
    if isinstance(cognify_response, dict):
        print(f"[Phase 1 discovery] cognify keys: {sorted(cognify_response.keys())}")

    assert cognify_response is not None, "cognify returned None"


@pytest.mark.integration
def test_re_add_identical_content_is_idempotent_or_documented(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Records cognee's dedup behavior on identical re-add for Phase 5.

    Phase 5 needs to know whether the sync tool can safely re-emit add
    on retry, or must track which docs are already in the KG.
    The assertion characterises, not enforces — any behavior is acceptable.
    """
    content = "# dedup test\nidentical content for dedup probe\n"
    first_response = dataset_lifecycle(dataset_name, content)
    dataset_id: str = first_response["dataset_id"]

    second_response = client.add_file(dataset_name=dataset_name, content=content)

    docs = client.list_documents(dataset_id)
    doc_count = len(docs)

    print(f"\n[Phase 1 discovery] first add response:  {first_response!r}")
    print(f"[Phase 1 discovery] second add response: {second_response!r}")
    print(f"[Phase 1 discovery] list_documents count after two adds: {doc_count}")
    if doc_count == 1:
        print("[Phase 1 discovery] re-add behavior: DEDUP (1 doc — safe to retry adds)")
    else:
        print(f"[Phase 1 discovery] re-add behavior: DUPLICATE ({doc_count} docs — sync tool must track state)")

    assert doc_count >= 1, f"Expected at least one document after two adds, got {doc_count}"


@pytest.mark.integration
def test_search_response_shape_discovery(
    client: CogneeClient,
    cognified_dataset: Callable[..., tuple[str, dict[str, Any]]],
    dataset_name: str,
) -> None:
    """Diagnostic: records search response shapes for Phase 2/3 strict assertions.

    Probes GRAPH_COMPLETION, SUMMARIES, and CHUNKS. Each result is printed
    so Phase 2 can write field-level assertions against the observed shape.
    Not load-bearing — failure here means a search_type isn't supported,
    not that the KG is broken.
    """
    dataset_id, _ = cognified_dataset(
        dataset_name, "# shape probe\nshape discovery content unique phrase\n"
    )

    for search_type in ("GRAPH_COMPLETION", "SUMMARIES", "CHUNKS"):
        try:
            result = client.search(
                "shape discovery content", search_type, datasets=[dataset_name]
            )
            print(f"\n[Phase 1 discovery] search_type={search_type!r}")
            print(f"  python type: {type(result)}")
            if isinstance(result, list):
                print(f"  list length: {len(result)}")
                if result and isinstance(result[0], dict):
                    print(f"  first item keys: {sorted(result[0].keys())}")
                    print(f"  first item: {ascii(result[0])}")
            elif isinstance(result, dict):
                print(f"  keys: {sorted(result.keys())}")
                print(f"  value: {ascii(result)}")
            else:
                print(f"  value: {result!r}")
        except Exception as exc:
            print(f"\n[Phase 1 discovery] search_type={search_type!r} raised: {type(exc).__name__}: {exc}")
