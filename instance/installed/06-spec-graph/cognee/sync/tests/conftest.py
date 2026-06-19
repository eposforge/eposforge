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
from pathlib import Path
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
        dataset_id: str = response["dataset_id"]
        recorded_ids.append(dataset_id)
        return response

    yield _add_and_track

    for dataset_id in recorded_ids:
        client.delete_dataset(dataset_id)


# ---------------------------------------------------------------------------
# Phase 1 fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def unique_token() -> str:
    """A short hex string guaranteed not to appear in real EposForge corpus content."""
    return f"phase1-canary-{uuid.uuid4().hex[:12]}"


@pytest.fixture()
def cognified_dataset(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
) -> Generator[Callable[..., tuple[str, dict[str, Any]]], None, None]:
    """Factory that adds a file, calls cognify, and returns (dataset_id, add_response).

    Cleanup is inherited from dataset_lifecycle — every dataset created here
    is deleted on teardown via the same proven mechanism.

    Note: add_file appears to run cognify implicitly (Phase 0 smoke showed
    status="PipelineRunCompleted" on add). The explicit cognify call here is
    belt-and-suspenders until Phase 1 confirms the implicit behavior.
    """
    def _factory(
        name: str,
        content: str | bytes = "# canary\nspec graph test\n",
        filename: str = "canary.md",
    ) -> tuple[str, dict[str, Any]]:
        add_response = dataset_lifecycle(name, content, filename)
        dataset_id: str = add_response["dataset_id"]
        client.cognify(datasets=[name])
        return dataset_id, add_response

    yield _factory


# ---------------------------------------------------------------------------
# Phase 2 fixtures
# ---------------------------------------------------------------------------



@pytest.fixture()
def updated_dataset(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
) -> Generator[Callable[..., tuple[str, str, str]], None, None]:
    """Factory that adds ALPHA content then re-adds BETA content to the same dataset.

    Returns ``(dataset_id, alpha_data_id, beta_data_id)``.
    Cleanup (dataset deletion) is inherited from ``dataset_lifecycle``.
    ``alpha_data_id`` and ``beta_data_id`` may or may not differ — Phase 2
    finding #4 records the answer.
    """
    def _factory(
        name: str,
        alpha_token: str,
        beta_token: str,
        filename: str = "update-test.md",
    ) -> tuple[str, str, str]:
        alpha_response = dataset_lifecycle(
            name,
            f"# update test\n\n{alpha_token}\n",
            filename,
        )
        dataset_id: str = alpha_response["dataset_id"]
        alpha_data_id: str = alpha_response["data_ingestion_info"][0]["data_id"]

        beta_response = client.add_file(
            dataset_name=name,
            content=f"# update test\n\n{beta_token}\n",
            filename=filename,
        )
        beta_data_id: str = beta_response["data_ingestion_info"][0]["data_id"]

        return dataset_id, alpha_data_id, beta_data_id

    yield _factory


# ---------------------------------------------------------------------------
# Phase 3 fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def two_doc_dataset(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
) -> Generator[Callable[..., tuple[str, str, str]], None, None]:
    """Factory that adds two distinct documents to the same dataset.

    Returns ``(dataset_id, data_id_a, data_id_b)``.
    Cleanup inherited from ``dataset_lifecycle``.
    """
    def _factory(
        name: str,
        token_a: str,
        token_b: str,
    ) -> tuple[str, str, str]:
        resp_a = dataset_lifecycle(
            name,
            f"# doc a\n\n{token_a}\n",
            "doc-a.md",
        )
        dataset_id: str = resp_a["dataset_id"]
        data_id_a: str = resp_a["data_ingestion_info"][0]["data_id"]

        resp_b = client.add_file(
            dataset_name=name,
            content=f"# doc b\n\n{token_b}\n",
            filename="doc-b.md",
        )
        data_id_b: str = resp_b["data_ingestion_info"][0]["data_id"]

        return dataset_id, data_id_a, data_id_b

    yield _factory


# ---------------------------------------------------------------------------
# Phase 4 fixtures
# ---------------------------------------------------------------------------

_FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="session")
def uploaded_ontology(client: CogneeClient) -> Generator[str, None, None]:
    """Upload the Phase 4 test ontology once per session; delete on teardown.

    Yields the ``ontology_key`` string used to reference it in ``cognify`` calls.
    """
    key = f"eposforge-phase4-{uuid.uuid4().hex[:8]}"
    content = (_FIXTURES_DIR / "phase4.ttl").read_text(encoding="utf-8")
    client.upload_ontology(key, content, description="Phase 4 test ontology")
    yield key
    client.delete_ontology(key)
