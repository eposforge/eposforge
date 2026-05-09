"""pytest fixtures for the cognee-sync test harness.

Fixture scopes are chosen to accommodate future phases:
  - ``config``  — session scope:  one Config per test run
  - ``client``  — session scope:  one HTTP connection pool per test run
                                  (Phase 4 needs a session-scoped ontology fixture
                                  that shares the same client)
  - ``dataset_name``  — function scope:  fresh UUID-suffixed name per test
  - ``dataset_lifecycle``  — function scope:  factory that adds a file and
                              registers the resulting dataset for teardown cleanup
"""

from __future__ import annotations

import uuid
from collections.abc import Callable, Generator
from typing import Any

import pytest

from cognee_sync.client import CogneeClient
from cognee_sync.config import Config, load_config


# ---------------------------------------------------------------------------
# Config + client
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def config() -> Config:
    """Load config from environment once per test session.

    Raises ``RuntimeError`` with a clear hint if the env vars are absent
    (i.e. the test was not invoked via ``epos-secrets``).
    """
    return load_config()


@pytest.fixture(scope="session")
def client(config: Config) -> Generator[CogneeClient, None, None]:
    """Session-scoped HTTP client.  Closed automatically after all tests run."""
    with CogneeClient(base_url=config.api_url, token=config.api_token, verify=config.tls_verify) as c:
        yield c


# ---------------------------------------------------------------------------
# Dataset name helper
# ---------------------------------------------------------------------------


@pytest.fixture()
def dataset_name(config: Config) -> str:
    """Fresh UUID-suffixed dataset name for a single test.

    This fixture only generates the *name* — no API call is made here.
    Use ``dataset_lifecycle`` when you need to create + auto-delete.
    """
    return f"{config.dataset_prefix}-{uuid.uuid4().hex[:8]}"


# ---------------------------------------------------------------------------
# Lifecycle factory
# ---------------------------------------------------------------------------


@pytest.fixture()
def dataset_lifecycle(
    client: CogneeClient,
) -> Generator[Callable[..., dict[str, Any]], None, None]:
    """Factory fixture that adds a file and schedules the dataset for cleanup.

    Usage::

        def test_something(dataset_lifecycle, dataset_name):
            response = dataset_lifecycle(dataset_name, "# hello\\n")
            dataset_id = response["id"]   # exact key TBD by Phase 0 run
            ...

    Teardown
    --------
    After the test completes (pass or fail) every dataset_id recorded by the
    factory is deleted via ``DELETE /api/v1/datasets/{id}``.  404 responses are
    suppressed so partial-failure cleanup is robust.
    """
    recorded_ids: list[str] = []

    def _add_and_track(
        name: str,
        content: str | bytes = "# canary\nspec graph test\n",
        filename: str = "canary.md",
    ) -> dict[str, Any]:
        response = client.add_file(
            dataset_name=name,
            content=content,
            filename=filename,
        )
        # Record whatever id field the response exposes so teardown can clean up.
        # Phase 0 discovers the exact field name; we try common candidates.
        dataset_id: str | None = (
            response.get("dataset_id")
            or response.get("datasetId")
            or response.get("id")
        )
        if dataset_id:
            recorded_ids.append(str(dataset_id))
        return response

    yield _add_and_track

    for dataset_id in recorded_ids:
        client.delete_dataset(dataset_id)
