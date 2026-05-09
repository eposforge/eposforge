"""Cognee HTTP API client.

Production-grade from Phase 0. This is the same class that Phases 1–5 will
extend and that the sync tool's CLI/daemon will import directly.

Phase 0 surface:
  - health()          GET /health
  - add_file()        POST /api/v1/add
  - delete_dataset()  DELETE /api/v1/datasets/{dataset_id}

Design constraints (see docs/uv-manages-version-create-vivid-pony.md §Phase 0):
  - No test-mode flags or mock toggles.
  - No ``_for_test`` methods.
  - Test convenience lives in conftest fixtures, never in this module.
  - Return parsed JSON dicts (lenient); no strict typed models until Phases 1–4
    reveal the actual response shapes.
  - Easy to extend: add cognify(), search(), list_documents(), update_file(),
    delete_document() later without restructuring.
"""

from __future__ import annotations

from types import TracebackType
from typing import Any

import httpx


class CogneeClient:
    """Thin httpx wrapper around the Cognee HTTP API.

    Parameters
    ----------
    base_url:
        Root URL of the Cognee API, e.g. ``https://cognee.example.lan``.
        Trailing slashes are stripped at construction.
    token:
        API key / bearer token.  Sent as ``Authorization: Bearer <token>``
        on every request.
    timeout:
        Request timeout in seconds.  Defaults to 180 to match the
        ``COGNEE_TEST_STEP_TIMEOUT`` convention in the existing test scripts.
    """

    def __init__(
        self,
        base_url: str,
        token: str = "",
        timeout: float = 180.0,
        verify: bool | str = True,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        headers: dict[str, str] = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        self._client = httpx.Client(
            base_url=self._base_url,
            headers=headers,
            timeout=timeout,
            verify=verify,
        )

    # ------------------------------------------------------------------
    # Context-manager support
    # ------------------------------------------------------------------

    def __enter__(self) -> "CogneeClient":
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> None:
        self.close()

    def close(self) -> None:
        self._client.close()

    # ------------------------------------------------------------------
    # Phase 0 methods
    # ------------------------------------------------------------------

    def health(self) -> dict[str, Any]:
        """GET /health — liveness/readiness probe.

        Returns the parsed JSON response body.
        Raises ``httpx.HTTPStatusError`` on non-2xx responses.
        """
        response = self._client.get("/health")
        response.raise_for_status()
        return response.json()

    def add_file(
        self,
        dataset_name: str,
        content: str | bytes,
        filename: str = "canary.md",
    ) -> dict[str, Any]:
        """POST /api/v1/add — upload a file into a named dataset.

        Parameters
        ----------
        dataset_name:
            Name of the dataset to add the file to.  Cognee will create it
            if it does not already exist.
        content:
            File content.  str is encoded as UTF-8.
        filename:
            Filename sent in the multipart payload.  Defaults to
            ``canary.md``.

        Returns
        -------
        dict
            Parsed response body from Cognee.  Phase 0 treats this as an
            opaque dict; Phases 1–4 will reveal the exact field names.
        """
        if isinstance(content, str):
            content = content.encode("utf-8")

        files = {"data": (filename, content, "text/markdown")}
        data = {"datasetName": dataset_name}
        response = self._client.post("/api/v1/add", files=files, data=data)
        response.raise_for_status()
        return response.json()

    def delete_dataset(self, dataset_id: str) -> None:
        """DELETE /api/v1/datasets/{dataset_id} — permanently remove a dataset.

        Parameters
        ----------
        dataset_id:
            UUID string of the dataset to delete.

        Notes
        -----
        A 404 response is *not* raised as an error — the dataset may have
        already been deleted (e.g. by a previous cleanup attempt).
        Any other non-2xx response raises ``httpx.HTTPStatusError``.
        """
        response = self._client.delete(f"/api/v1/datasets/{dataset_id}")
        if response.status_code == 404:
            return
        response.raise_for_status()

    # ------------------------------------------------------------------
    # Phase 1 methods
    # ------------------------------------------------------------------

    def cognify(
        self,
        *,
        datasets: list[str] | None = None,
        dataset_ids: list[str] | None = None,
        run_in_background: bool = False,
        custom_prompt: str = "",
        ontology_key: list[str] | None = None,
    ) -> dict[str, Any]:
        """POST /api/v1/cognify — extract a knowledge graph from an added dataset.

        Provide ``datasets`` (names) or ``dataset_ids`` (UUID strings), not both.
        Note: ``add_file`` already returns ``status="PipelineRunCompleted"``,
        so cognify may be implicit on add — Phase 1 confirms this.
        """
        body: dict[str, Any] = {"runInBackground": run_in_background}
        if datasets is not None:
            body["datasets"] = datasets
        if dataset_ids is not None:
            body["datasetIds"] = [str(d) for d in dataset_ids]
        if custom_prompt:
            body["customPrompt"] = custom_prompt
        if ontology_key is not None:
            body["ontologyKey"] = ontology_key
        response = self._client.post("/api/v1/cognify", json=body)
        response.raise_for_status()
        return response.json()

    def search(
        self,
        query: str,
        search_type: str,
        *,
        datasets: list[str] | None = None,
        dataset_ids: list[str] | None = None,
        top_k: int = 10,
        system_prompt: str | None = None,
    ) -> list[Any]:
        """POST /api/v1/search — query the knowledge graph.

        ``search_type`` is required; Phase 1 discovery probes GRAPH_COMPLETION,
        SUMMARIES, and CHUNKS. Body field names are snake_case per swagger
        (``dataset_ids``, not ``datasetIds``).
        Returns a list; element shape varies by search_type.
        """
        body: dict[str, Any] = {
            "query": query,
            "search_type": search_type,
            "top_k": top_k,
        }
        if datasets is not None:
            body["datasets"] = datasets
        if dataset_ids is not None:
            body["dataset_ids"] = [str(d) for d in dataset_ids]
        if system_prompt is not None:
            body["system_prompt"] = system_prompt
        response = self._client.post("/api/v1/search", json=body)
        response.raise_for_status()
        return response.json()

    def list_documents(self, dataset_id: str) -> list[dict[str, Any]]:
        """GET /api/v1/datasets/{dataset_id}/data — list data items in a dataset."""
        response = self._client.get(f"/api/v1/datasets/{dataset_id}/data")
        response.raise_for_status()
        result = response.json()
        return result if isinstance(result, list) else [result]
