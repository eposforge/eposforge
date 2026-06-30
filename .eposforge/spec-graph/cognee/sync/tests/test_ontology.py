"""Phase 4 integration tests — ontology grounding stability.

Explores whether entity node IDs from the knowledge graph are stable across
document edits and whether ontology-anchored cognify produces nodes tied to
the uploaded ontology's class IRIs.

All three tests are discovery-oriented: they print findings and pass regardless
of the observed behavior (except for hard infrastructure checks). The results
answer Phase 4's open questions and inform Phase 5 design.

Run via the secrets resolver::

    python.eposforge/secrets-key-management/bin/epos-secrets \\
        uv run pytest -m integration -v -s
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import pytest

from cognee_sync.client import CogneeClient

_ONTOLOGY_IRI = "https://eposforge.example/ontology#PhaseTestEntity"
_ONTOLOGY_LABEL = "PhaseTestEntity"


def _node_ids(graph: dict[str, Any]) -> set[str]:
    return {
        str(n.get("id"))
        for n in graph.get("nodes", [])
        if isinstance(n, dict) and n.get("id")
    }


@pytest.mark.integration
def test_graph_endpoint_structure(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Discovery: inspect the raw structure returned by GET /api/v1/datasets/{id}/graph."""
    resp = dataset_lifecycle(
        dataset_name,
        "# graph structure test\nPhaseTestEntity is a concept.\n",
        "graph-test.md",
    )
    dataset_id: str = resp["dataset_id"]

    graph = client.get_graph(dataset_id)

    print(f"\n[Phase 4 discovery] graph type: {type(graph)}")
    if isinstance(graph, dict):
        print(f"[Phase 4 discovery] top-level keys: {sorted(graph.keys())}")
        nodes = graph.get("nodes", [])
        edges = graph.get("edges", [])
        print(f"[Phase 4 discovery] node count: {len(nodes)}")
        print(f"[Phase 4 discovery] edge count: {len(edges)}")
        if nodes:
            print(f"[Phase 4 discovery] first node keys: {sorted(nodes[0].keys()) if isinstance(nodes[0], dict) else type(nodes[0])}")
            print(f"[Phase 4 discovery] first node: {nodes[0]!r}")
        if edges:
            print(f"[Phase 4 discovery] first edge: {edges[0]!r}")
    else:
        print(f"[Phase 4 discovery] graph value: {ascii(str(graph))}")

    assert graph is not None, "get_graph returned None"


@pytest.mark.integration
def test_graph_node_ids_stable_across_delete_readd(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
) -> None:
    """Node IDs from get_graph before and after delete+readd of identical content.

    Stable IDs = Phase 5 downstream consumers won't see entity churn on updates.
    Unstable IDs = every sync cycle produces new node IDs; downstream queries break.
    """
    content = "# entity stability test\nPhaseTestEntity is a core concept for testing.\n"
    resp = dataset_lifecycle(dataset_name, content, "stability-test.md")
    dataset_id: str = resp["dataset_id"]
    data_id: str = resp["data_ingestion_info"][0]["data_id"]

    graph_before = client.get_graph(dataset_id)
    ids_before = _node_ids(graph_before)
    print(f"\n[Phase 4] node count before delete+readd: {len(ids_before)}")

    client.delete_document(dataset_id, data_id)

    resp2 = client.add_file(
        dataset_name=dataset_name,
        content=content,
        filename="stability-test.md",
    )
    print(f"[Phase 4] re-add status: {resp2.get('status')!r}")

    graph_after = client.get_graph(dataset_id)
    ids_after = _node_ids(graph_after)
    print(f"[Phase 4] node count after delete+readd: {len(ids_after)}")

    if not ids_before and not ids_after:
        print("[Phase 4 discovery] graph returned 0 nodes both times — no entity extraction for this content type")
        return

    stable = ids_before == ids_after
    new_ids = ids_after - ids_before
    gone_ids = ids_before - ids_after

    print(f"[Phase 4 discovery] node IDs stable: {stable}")
    if not stable:
        print(f"[Phase 4 discovery] new IDs: {new_ids}")
        print(f"[Phase 4 discovery] gone IDs: {gone_ids}")

    if stable:
        print("[Phase 4 discovery] STABLE -> Phase 5 downstream consumers safe from entity ID churn")
    else:
        print("[Phase 4 discovery] UNSTABLE -> entity IDs churn on delete+readd; downstream queries will break")


@pytest.mark.integration
def test_ontology_anchored_cognify(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
    dataset_name: str,
    uploaded_ontology: str,
) -> None:
    """Ontology-anchored cognify: check whether extracted nodes reference the ontology IRI.

    Uploads the phase4.ttl ontology (via the uploaded_ontology session fixture),
    adds a document referencing PhaseTestEntity, then runs explicit cognify with
    ontologyKey to trigger ontology-anchored extraction. Inspects the resulting
    graph for nodes that carry the ontology class IRI.
    """
    resp = dataset_lifecycle(
        dataset_name,
        f"# ontology anchoring test\n{_ONTOLOGY_LABEL} is used for testing.\n",
        "ontology-test.md",
    )
    dataset_id: str = resp["dataset_id"]

    print(f"\n[Phase 4] ontology key: {uploaded_ontology!r}")

    cognify_resp = client.cognify(
        datasets=[dataset_name],
        ontology_key=[uploaded_ontology],
    )
    print(f"[Phase 4] cognify with ontologyKey response keys: "
          f"{sorted(cognify_resp.keys()) if isinstance(cognify_resp, dict) else type(cognify_resp)}")

    graph = client.get_graph(dataset_id)
    nodes = graph.get("nodes", []) if isinstance(graph, dict) else []

    print(f"[Phase 4] node count after ontology-anchored cognify: {len(nodes)}")
    for n in nodes[:5]:
        print(f"  node: {n!r}")

    anchored = [
        n for n in nodes
        if isinstance(n, dict) and (
            _ONTOLOGY_IRI in str(n)
            or _ONTOLOGY_LABEL in str(n.get("label", ""))
            or _ONTOLOGY_LABEL in str(n.get("properties", ""))
        )
    ]

    print(f"[Phase 4 discovery] nodes referencing ontology IRI/label: {len(anchored)}")
    if anchored:
        print(f"[Phase 4 discovery] ANCHORED -> ontology-guided extraction is working")
        for n in anchored:
            print(f"  anchored node: {n!r}")
    else:
        print(f"[Phase 4 discovery] NOT ANCHORED -> no nodes reference the ontology class")
        print(f"  (may need different document content, ontology format, or cognify parameters)")

    assert graph is not None, "get_graph returned None"
