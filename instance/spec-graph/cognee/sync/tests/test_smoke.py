"""Phase 0 smoke tests — connectivity and dataset lifecycle.

Both tests are marked ``@pytest.mark.smoke`` so they can be selected with::

    uv run pytest -m smoke -v

Run via the secrets resolver (required for env vars)::

    python instance/secrets-key-management/bin/epos-secrets \\
        uv run pytest -m smoke -v
"""

from __future__ import annotations

from typing import Any

import pytest

from cognee_sync.client import CogneeClient


@pytest.mark.smoke
def test_api_reachable_and_authenticated(client: CogneeClient) -> None:
    """GET /health returns a 2xx response.

    This is the fast pre-flight check.  A failure here means the URL is
    wrong or the token is invalid; it will surface before the lifecycle test
    runs so the root cause is unambiguous.
    """
    result = client.health()
    # Health endpoint returns a JSON object; we just need it to not raise.
    assert isinstance(result, dict), f"Expected dict from /health, got: {type(result)}"


@pytest.mark.smoke
def test_dataset_lifecycle_roundtrip(
    dataset_lifecycle: Any,
    dataset_name: str,
) -> None:
    """Create a canary dataset and verify cleanup fires end-to-end.

    What this proves:
      (a) auth works end-to-end including write paths
      (b) Cognee accepts our multipart payload shape
      (c) the cleanup fixture actually fires and successfully deletes what
          it created (teardown is exercised, not just declared)

    The ``dataset_lifecycle`` fixture handles teardown automatically.
    After this test completes (pass or fail), the dataset named
    ``dataset_name`` is deleted via DELETE /api/v1/datasets/{id}.
    """
    response = dataset_lifecycle(
        dataset_name,
        content="# canary\nspec graph test\n",
        filename="canary.md",
    )

    assert isinstance(response, dict), (
        f"Expected dict response from add_file, got {type(response)}.  "
        f"Full response: {response!r}"
    )

    # Phase 0 discovery: log what fields the response actually contains so we
    # know the exact key to use in Phases 1–4.
    print(f"\n[Phase 0 discovery] add_file response keys: {sorted(response.keys())}")
    print(f"[Phase 0 discovery] add_file response: {response!r}")


# L2 ratchet: known-query recall against the live eposforge-sync corpus.
# Cognee MCP `recall` proxies to this API path (dkr-cgnee-mcp → dkr-cgnee-api).
KNOWN_RECALL_QUERY = "What defines a kernel in stabilization?"
KNOWN_RECALL_MARKERS = ("stable", "detect")


@pytest.mark.smoke
def test_spec_graph_recall_known_query(client: CogneeClient) -> None:
    """Recall a known architecture concept from the eposforge-sync corpus.

    This is the detectable half of the Cognee L2 kernel ratchet: the spec graph
    must answer a fixed query with content that proves the corpus is indexed and
    queryable. MCP ``recall`` hits the same backend via the MCP proxy container.
    """
    result = client.search(
        KNOWN_RECALL_QUERY,
        "GRAPH_COMPLETION",
        datasets=["eposforge-sync"],
        top_k=3,
    )
    assert isinstance(result, list), f"Expected list from search, got {type(result)}"
    assert result, f"Empty recall for known query: {KNOWN_RECALL_QUERY!r}"

    text = str(result[0]).lower()
    missing = [marker for marker in KNOWN_RECALL_MARKERS if marker not in text]
    assert not missing, (
        f"Recall for {KNOWN_RECALL_QUERY!r} missing expected terms {missing!r}. "
        f"Got: {result[0]!r}"
    )
