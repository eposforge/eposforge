---
name: update-spec-graph
description: Keeps the Cognee Spec Graph (Component 6) knowledge graph in sync with the repo. Use to update the KG after doc changes (incremental), rebuild it from scratch or after editing the ontology (full), or when recall is stale, the graph looks wrong, or entities are not ontology-anchored.
---

Updates the Cognee knowledge graph that backs the Spec Graph (Component 6) so
recall and graph queries reflect the current repo. Handles **both** update
paths — incremental per-file sync and full corpus rebuild — and decides which
one a given change requires.

This skill owns *running* the update. Editing the ontology TTL itself is a
separate concern owned by [maintain-ontology](../maintain-ontology/SKILL.md):
edit the TTL there, then come here to rebuild. Adapter-level deployment topology,
API behavior, and recovery procedures live in
[cognee.md](../../.eposforge/spec-graph/cognee/cognee.md).

## Pick the path first: incremental vs full

The trigger for the change decides the path. **Get this right before running
anything** — running incremental after an ontology edit silently leaves the
graph half-anchored.

| What changed | Path | Why |
|---|---|---|
| Corpus docs only (`*.md`, non-ontology `*.ttl`) | **Incremental** | New/changed docs anchor against the already-uploaded ontology; unchanged docs are untouched. |
| The ontology (`00-vision/01-ontology.ttl`) | **Full rebuild + KG wipe** | Anchoring is not retroactive *and* content-hash dedup skips re-extraction of unchanged docs — only a wipe forces every doc to re-anchor. |
| Empty / corrupt / from scratch / Ladybug stale-lock | **Full rebuild + KG wipe** | No usable prior state. |

**The asymmetry to remember:** a document edit is incremental; an ontology edit
is a full rebuild. Cognee resolves the ontology at cognify time per run and does
not re-anchor existing nodes, and its content-hash dedup (`PipelineRunAlreadyCompleted`)
will silently skip docs whose text did not change — so you cannot re-anchor a
changed ontology without wiping the KG.

## Preconditions (both paths)

- `dkr-cgnee-api` container running and healthy (the KG owner; the MCP container
  is only a proxy — never ingest against it). See cognee.md §Deployment topology.
- `epos-secrets` on PATH (or at `.eposforge/secrets-key-management/bin/`)
  to inject `COGNEE_API_URL` / `COGNEE_API_TOKEN`.
- `uv` available; run from `.eposforge/spec-graph/cognee/sync`.
- Check the inference budget before a full rebuild (~180K–200K embedding tokens
  for the full corpus): `.eposforge/.audit/inference-budget-counters.json`.
- The ontology key is `eposforge` (override via `$COGNEE_ONTOLOGY_KEY`).

## Incremental path (doc changes)

Compute the diff since the last synced commit, then dispatch per-file changes.
Always pass `--ontology-key` so cognify anchors entities to the ontology.

```bash
# From repo root. BASE = last commit whose changes are already in the KG.
ADDED=$(git diff --name-only --diff-filter=A "$BASE..HEAD" -- '*.md' '*.ttl' | grep -vxF '00-vision/01-ontology.ttl' | grep -vE '(^|/)(backlog/|.eposforge/backlog/|plans/)')
MODIFIED=$(git diff --name-only --diff-filter=M "$BASE..HEAD" -- '*.md' '*.ttl' | grep -vxF '00-vision/01-ontology.ttl' | grep -vE '(^|/)(backlog/|.eposforge/backlog/|plans/)')
DELETED=$(git diff --name-only --diff-filter=D "$BASE..HEAD" -- '*.md' '*.ttl' | grep -vxF '00-vision/01-ontology.ttl' | grep -vE '(^|/)(backlog/|.eposforge/backlog/|plans/)')

cd .eposforge/spec-graph/cognee/sync
epos-secrets uv run cognee-sync --ontology-key eposforge \
    ${ADDED:+--added $ADDED} \
    ${MODIFIED:+--modified $MODIFIED} \
    ${DELETED:+--deleted $DELETED}
```

Notes:
- The ontology TTL is the **anchor, not a corpus document** — exclude it from
  `--added`/`--modified`. If it changed, you are on the wrong path (use full
  rebuild).
- Raw backlog items (`backlog/`, `.eposforge/backlog/`, `plans/`) are excluded from the main Spec Graph by default (EF-057). They live in the independent file-based backlog graph. The main graph may still reference backlog *mechanics* via ontology terms. Use aggregate.sh / portfolio-review for backlog GraphRAG views.
- The incremental path assumes the ontology is already uploaded. If unsure,
  add `--upload-ontology 00-vision/01-ontology.ttl` once (it is idempotent:
  delete + re-upload).
- `--dry-run` prints planned actions with no API calls.
- update = delete old `data_id` + add new; the state DB (`sync/.cognee-state.db`)
  maps `file_path → data_id` and is committed to source. Commit the updated
  state DB after a successful run.

## Full rebuild path (ontology change, or from scratch)

Two steps. **Step 1 (KG wipe) is mandatory for an ontology change** — skipping
it means dedup leaves the old anchoring in place.

### 1. Wipe the KG

Per cognee.md §Recovery procedures (this destroys the entire KG):

```bash
COMPOSE_FILE=<docker-volume-mounts>/cognee/docker-compose.yml
docker compose -f "$COMPOSE_FILE" stop dkr-cgnee-api
# sudo rm -rf <docker-volume-mounts>/cognee/data/cognee_system
# sudo mkdir -p <docker-volume-mounts>/cognee/data/cognee_system
# sudo chown -R <operator-user>: <docker-volume-mounts>/cognee/data/cognee_system
docker compose -f "$COMPOSE_FILE" start dkr-cgnee-api
# Wait ~10s for the health check before rebuilding.
# (Use concrete values only in private adopter runbooks.)
```

### 2. Rebuild

```bash
bash .eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh
```

`bulk-rebuild.sh` wipes the sync state DB, stages every tracked `*.md`/`*.ttl`
**except** the ontology TTL and raw backlog items (`backlog/`, `.eposforge/backlog/`, `plans/` per EF-057), uploads the ontology as the `eposforge` anchor, and
cognifies with `ontologyKey=[eposforge]`. Use `--dry-run` to preview.

**Bulk cognify is two-pass.** The first pass over 80+ docs may emit ~10 SQLite
contention errors (`database is locked`, `no such table: data`) — expected.
Re-run `bulk-rebuild.sh`; the second pass picks up the missed docs cleanly. If
the second pass also hits lock errors, restart `dkr-cgnee-api` first, then re-run.

## Verify the update

After either path, confirm the graph reflects the change — and, after a full
rebuild, that anchoring actually took:

- **Coverage:** `TextDocument` node count should match the synced doc count. If
  they diverge, cognify did not run (see cognee.md §Pipeline behavior).
- **Anchoring took (full rebuild):** the definitive signal is node
  `ontology_valid`. Fetch the graph
  (`GET https://cognee.grace.lan/api/v1/datasets/<id>/graph`) and confirm nodes
  carry `properties.ontology_valid: true` — if *every* node is `false`, nothing
  anchored. Corroborate in the API log: a storm of
  `OntologyAdapter: No close match found for '<x>' in category 'classes'` during
  cognify means the ontology did not load (most often it was uploaded as Turtle
  instead of RDF/XML — see cognee.md §Ontology grounding; `cognee-sync` now
  converts automatically). When healthy, the API log shows
  `OntologyAdapter: Lookup built: N classes, M individuals` at cognify start.
- **Recall probe:** ask cognee MCP `recall` for a term you just changed and
  confirm it reflects the new content.

## Outputs

- updated Cognee KG reflecting current repo state
- for incremental: updated `sync/.cognee-state.db` (commit it)
- `verification report` — doc coverage, `EntityType` anchoring check (full
  rebuild), and a recall probe result
