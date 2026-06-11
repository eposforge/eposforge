"""Phase 0 smoke tests — connectivity and dataset lifecycle.

Both tests are marked ``@pytest.mark.smoke`` so they can be selected with::

    uv run pytest -m smoke -v

Run via the secrets resolver (required for env vars)::

    python instance/installed/12-secrets-key-management/bin/epos-secrets \\
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
