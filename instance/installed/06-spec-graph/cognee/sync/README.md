---
doc_kind: developer-guide
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# cognee-sync — Incremental Sync Tool

Git-commit-driven incremental sync that keeps the Cognee knowledge graph
up-to-date with EposForge `*.md` changes. Replaces the old full
prune-and-reproject ingestion with per-file add / update / delete operations
via the Cognee HTTP API.

---

## What this is

`cognee-sync` is a `uv`-managed Python package providing:

- **`CogneeClient`** — httpx-based HTTP client for the Cognee API (health,
  add_file, cognify, search, list_documents, delete_dataset, delete_document,
  upload_ontology, delete_ontology, get_graph).
- **`StateStore`** — SQLite-backed mapping of `file_path → (dataset_id,
  data_id, content_hash)`. Persisted at `.cognee-state.db` in this directory,
  committed to source.
- **`cognee-sync` CLI** — invoked by Gitea Actions or a post-receive hook on
  push. Accepts `--added`, `--modified`, `--deleted` file lists and dispatches
  the correct Cognee API calls.
- **Test harness** — pytest integration tests (Phases 0–5) covering the full
  add / update / delete / ontology behavioral surface against the live
  `dkr-cgnee-api` container.

Behavioral findings from all phases are documented in
`../cognee.md` §Observed API behavior.

---

## Prerequisites

- `uv` installed
- Age key authorized per the sops-age setup runbook
- `cognee_api_url` populated in `secrets.enc.yaml` (encrypted)
- `dkr-cgnee-api` container running and reachable

Windows one-time: enable long paths (run as Administrator):

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1
```

---

## Bootstrap

```powershell
# Windows (from repo root)
cd instance\installed\06-spec-graph\cognee\sync
uv sync
```

```sh
# Linux / macOS (from repo root)
cd instance/installed/06-spec-graph/cognee/sync
uv sync
```

---

## Sync tool — usage

All invocations require `epos-secrets` to inject `COGNEE_API_URL` and
`COGNEE_API_TOKEN`:

```powershell
# Add new files to Cognee:
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run cognee-sync --added instance/SPEC.md 00-vision/01-ontology.ttl

# Update changed files (delete old data_id + add new):
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run cognee-sync --modified instance/installed/06-spec-graph/cognee/cognee.md

# Remove deleted files from Cognee:
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run cognee-sync --deleted path/to/removed.md

# Inspect tracked state:
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run cognee-sync --status

# Dry-run (no API calls):
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run cognee-sync --dry-run --added instance/SPEC.md
```

Linux equivalent — same invocations with forward slashes.

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `COGNEE_API_URL` | — (required) | Base URL of the Cognee HTTP API |
| `COGNEE_API_TOKEN` | empty | Bearer token (anonymous if absent) |
| `COGNEE_TLS_VERIFY` | `true` | `false` or path to CA bundle |
| `COGNEE_DATASET_NAME` | `eposforge-sync` | Dataset all tracked files go into |
| `COGNEE_STATE_DB` | `sync/.cognee-state.db` | Override the state DB path |

---

## Tests

```powershell
# Smoke (fast, connectivity only):
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run pytest -m smoke -v

# Full integration suite (all phases, ~2 min):
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run pytest -m integration -v -s

# All tests:
python ..\..\..\12-secrets-key-management\bin\epos-secrets `
    uv run pytest -v -s
```

Expected: 18 pass, 1 xfail (`test_updated_content_evicts_old_content` —
cognee accumulates on re-add; update uses explicit delete+add by design).

---

## Project layout

```
sync/
  pyproject.toml            project metadata, deps, entry point, ruff + pytest config
  uv.lock                   committed lockfile
  .python-version           pins Python 3.13
  .gitignore                ignores .venv/
  .cognee-state.db          SQLite state store (committed to source; created on first sync)
  README.md                 this file
  src/
    cognee_sync/
      __init__.py
      config.py             reads COGNEE_API_URL / COGNEE_API_TOKEN / COGNEE_TLS_VERIFY
      client.py             httpx-based Cognee HTTP client (Phases 0–4 methods)
      state.py              SQLite StateStore — file_path -> dataset_id/data_id/hash
      sync.py               sync_add / sync_update / sync_delete engine
      cli.py                cognee-sync argparse entry point
  tests/
    __init__.py
    conftest.py             fixtures: client, dataset_lifecycle, cognified_dataset,
                            updated_dataset, two_doc_dataset, uploaded_ontology
    test_smoke.py           Phase 0: connectivity + lifecycle
    test_addfile.py         Phase 1: addfile behavior, cognify implicit, search shapes
    test_updatefile.py      Phase 2: update = delete+add confirmed; xfail eviction test
    test_deletefile.py      Phase 3: delete synchronous, non-cascading, clean roundtrip
    test_ontology.py        Phase 4: graph structure, node stability, ontology anchoring
    test_sync.py            Phase 5: sync engine add/update/delete/idempotency
    fixtures/
      phase4.ttl            minimal OWL ontology for Phase 4 tests
```

---

## Secrets

Registered in `instance/installed/12-secrets-key-management/sops-age/secrets.toml`:

| Logical name | Runtime env var | Purpose |
|---|---|---|
| `cognee_api_url` | `COGNEE_API_URL` | Base URL of the Cognee HTTP API |
| `cognee_tls_verify` | `COGNEE_TLS_VERIFY` | TLS verification override |

Both encrypted in `secrets.enc.yaml`. Use `sops secrets.enc.yaml` to add or
rotate values. Neither is committed in plaintext per AGENTS.md.
