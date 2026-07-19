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


def _to_rdf_xml(content: bytes) -> bytes:
    """Return ``content`` as RDF/XML bytes.

    Cognee's RDFLibOntologyResolver parses uploaded ontology files with a
    hardcoded ``format="xml"`` on its file-object path, so a Turtle file
    silently fails to load (no classes/individuals → nothing anchors). We
    convert Turtle (and anything else RDFLib can parse) to RDF/XML before
    upload. Content that is already RDF/XML is returned unchanged.
    """
    head = content.lstrip()[:64].lower()
    if head.startswith(b"<?xml") or head.startswith(b"<rdf"):
        return content
    from rdflib import Graph

    graph = Graph()
    graph.parse(data=content, format="turtle")
    return graph.serialize(format="xml").encode("utf-8")


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
        long-running sync workload (900s).
    """

    def __init__(
        self,
        base_url: str,
        token: str = "",
        timeout: float = 900.0,
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
        chunks_per_batch: int | None = None,
    ) -> dict[str, Any]:
        """POST /api/v1/cognify — extract a knowledge graph from an added dataset.

        Provide ``datasets`` (names) or ``dataset_ids`` (UUID strings), not both.
        Note: ``add_file`` already returns ``status="PipelineRunCompleted"``,
        so cognify may be implicit on add — Phase 1 confirms this.

        ``chunks_per_batch`` throttles how many chunks cognee processes
        concurrently. Large corpora at the default concurrency corrupt cognee's
        embedded SQLite metadata store ("database disk image is malformed"); a
        small batch serializes the writes enough to avoid it.
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
        if chunks_per_batch is not None:
            body["chunksPerBatch"] = chunks_per_batch
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

    # ------------------------------------------------------------------
    # Phase 2 methods
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # Phase 4 methods
    # ------------------------------------------------------------------

    def upload_ontology(
        self,
        ontology_key: str,
        content: str | bytes,
        description: str = "",
    ) -> dict[str, Any]:
        """POST /api/v1/ontologies — upload an ontology file (OWL/Turtle).

        ``ontology_key`` is the user-defined identifier referenced later via
        the ``ontologyKey`` parameter on ``cognify``.
        """
        if isinstance(content, str):
            content = content.encode("utf-8")
        content = _to_rdf_xml(content)
        files = {"ontology_file": (f"{ontology_key}.owl", content, "application/octet-stream")}
        data: dict[str, str] = {"ontology_key": ontology_key}
        if description:
            data["description"] = description
        response = self._client.post("/api/v1/ontologies", files=files, data=data)
        response.raise_for_status()
        return response.json()

    def delete_ontology(self, ontology_key: str) -> None:
        """DELETE /api/v1/ontologies/{ontology_key} — remove an uploaded ontology.

        Treats "not found" as success so delete-before-upload stays idempotent.
        This cognee build returns 400 (not 404) when the key is absent.
        """
        response = self._client.delete(f"/api/v1/ontologies/{ontology_key}")
        if response.status_code == 404:
            return
        if response.status_code == 400 and "not found" in response.text.lower():
            return
        response.raise_for_status()

    def get_graph(self, dataset_id: str) -> dict[str, Any]:
        """GET /api/v1/datasets/{dataset_id}/graph — retrieve the knowledge graph."""
        response = self._client.get(f"/api/v1/datasets/{dataset_id}/graph")
        response.raise_for_status()
        return response.json()

    def delete_document(self, dataset_id: str, data_id: str) -> None:
        """DELETE /api/v1/datasets/{dataset_id}/data/{data_id} — remove one data item.

        404 is suppressed (item may already be deleted).
        Any other non-2xx raises ``httpx.HTTPStatusError``.
        """
        response = self._client.delete(
            f"/api/v1/datasets/{dataset_id}/data/{data_id}"
        )
        if response.status_code == 404:
            return
        response.raise_for_status()
