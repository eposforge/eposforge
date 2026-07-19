# Cognee Maintenance Procedures

Operator-only procedures. Agents MUST NOT run the wipe steps below without
explicit operator confirmation using the exact phrase **"I authorize KG wipe"**.

---

## Known cognee failure modes (read before a rebuild)

Two non-obvious behaviors caused a multi-hour outage; both are now handled by
`bulk-rebuild.sh`, but understand them before touching the graph manually.

### 1. cognee never checkpoints the graph WAL on its own → data is WAL-only

Ladybug writes land in the WAL (`cognee_graph_ladybug.wal`) and are **not** flushed
into the durable main file (`cognee_graph_ladybug`) on shutdown — not even a
graceful `docker compose stop`. Consequences:

- The graph is fully queryable while the container runs (the WAL replays on open),
  so a **copy-probe of the main file alone reports 0 nodes even when the live graph
  is full** — always count via the API (`CYPHER: MATCH (n) RETURN count(n)`), not a
  main-file-only probe.
- Any unclean stop (`kill -9`, `--force-recreate` past the grace period, power loss)
  **tears the uncheckpointed WAL** → corrupt-WAL outage on the next cold start, and
  all un-checkpointed data is lost.

**Fix / rule:** force a checkpoint after any bulk graph change:
`POST /api/v1/search {"searchType":"CYPHER","query":"CHECKPOINT"}` (the bare
`CHECKPOINT` statement; `CALL checkpoint()` is invalid). `bulk-rebuild.sh` now does
this automatically as its final step. Verify durability with a main-file-only probe
— after a checkpoint it should match the live count. `stop_grace_period: 300s` on the
API service gives a clean stop time to settle; never hard-kill an un-checkpointed WAL.

### 2. Bulk ingest corrupts cognee's SQLite metadata without a batch throttle

A full-corpus cognify at cognee's default concurrency corrupts the embedded SQLite
metadata store — `sqlite3.DatabaseError: database disk image is malformed` — which
then fails every subsequent `/api/v1/add` and `/api/v1/cognify` with a 500 until a
full wipe. **The fix is throttling, not retrying** (once SQLite is malformed, retry
can't recover it).

**Fix / rule:** set `COGNEE_CHUNKS_PER_BATCH` (default `6` in `bulk-rebuild.sh`) so
cognee serializes graph/SQLite writes. A clean 116-doc rebuild at batch=6 completes
without corruption; the same rebuild unthrottled corrupted SQLite partway. If you
still hit `malformed`, lower the batch size further.

---

## Recovery procedures

### KG wipe (Ladybug stale-lock or clean-slate rebuild)

Use only when:

- The operator has explicitly authorized a wipe ("I authorize KG wipe"), **or**
- A container migration requires a clean data directory

**Do not wipe just because the Ladybug version-code error appears.** That
`Could not map version_code to proper Ladybug version` message is a masking
artifact (`version_code 40` is the normal state), not the real fault — it hides
the primary `RuntimeError`. **First unmask the real error** with the isolated-copy
probe in [`cognee.md` → Unmasking the real Ladybug open error](cognee.md#unmasking-the-real-ladybug-open-error-do-this-first),
then pick the matching recovery: **corrupt WAL** → the non-destructive procedure
below; **lock contention / stale lock** → the KG wipe above. Also check
`GET /api/v1/datasets` — if it returns `[]` the graph is already empty and no
wipe is needed regardless.

**What this destroys:** all graph data in `cognee_system`. A full
bulk-rebuild (`bulk-rebuild.sh`) is required after, costing ~180–200K
embedding tokens. Budget accordingly.

```bash
COMPOSE_DIR=/mnt/raid-storage/docker-volume-mounts/cognee
COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yml
DATA_DIR=$COMPOSE_DIR/data/cognee_system

# 1. Stop the API container (stop, not rm — preserves config)
cd "$COMPOSE_DIR"
./compose-with-secrets.sh stop dkr-cgnee-api

# 2. Create a timestamped backup before touching anything
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=$COMPOSE_DIR/backups/cognee_system-pre-reset-$STAMP.tar.gz
mkdir -p "$COMPOSE_DIR/backups"
[ -d "$DATA_DIR" ] && tar -czf "$BACKUP" -C "$COMPOSE_DIR/data" cognee_system \
  && echo "Backup: $BACKUP"

# 3. Wipe and recreate the directory
sudo rm -rf "$DATA_DIR"
sudo mkdir -p "$DATA_DIR"
sudo chown -R cdfadmin: "$DATA_DIR"

# 4. Restart via the secret wrapper (never plain docker compose up)
./compose-with-secrets.sh up -d dkr-cgnee-api dkr-cgnee-mcp

# 5. Rebuild the corpus (from eposforge repo root)
# bash.eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh
```

> **Note:** always start containers via `compose-with-secrets.sh`, not plain
> `docker compose up`. The compose file uses `${VAR:?set via epos-secrets}`
> guards that will cause compose to exit if secrets are not injected.

---

### Corrupt WAL recovery (non-destructive to the main DB)

Use when the unmask probe reports `Corrupted wal file. Read out invalid WAL
record type`. This touches **only** the WAL — it does not delete the main
`cognee_graph_ladybug` file or the SQLite/LanceDB stores, so the metadata layer
(`/api/v1/datasets`, embeddings) is preserved. Still requires **"I authorize KG
wipe"** if the main graph was never checkpointed (4 KB main file → `count(n)=0`
→ the graph data is gone and a rebuild is required either way; confirm with the
no-WAL probe variant in `cognee.md`).

Observed root cause: the WAL was corrupted by an earlier unclean stop and only
surfaced on the next cold restart (see the timeline trap in `cognee.md`). A
clean `docker restart` does **not** fix it — Ladybug re-reads the same bad WAL.

```bash
DBDIR=/mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system/databases
COMPOSE_DIR=/mnt/raid-storage/docker-volume-mounts/cognee
STAMP=$(date +%Y%m%d-%H%M%S)

# 1. Stop the API (stop, not rm)
cd "$COMPOSE_DIR" && ./compose-with-secrets.sh stop dkr-cgnee-api

# 2. Move the corrupt WAL aside (reversible — do NOT delete)
mkdir -p "$COMPOSE_DIR/backups"
mv "$DBDIR/cognee_graph_ladybug.wal" \
   "$COMPOSE_DIR/backups/cognee_graph_ladybug.wal.corrupt-$STAMP"

# 3. Restart via the secret wrapper
./compose-with-secrets.sh up -d dkr-cgnee-api

# 4. Verify recall works, then rebuild the corpus (data in the WAL is lost):
#    bash .eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh
```

---

## Checking dataset state before any intervention

```bash
curl -s http://127.0.0.1:18000/api/v1/datasets | python3 -m json.tool
```

- Returns `[]` → graph is empty (no wipe needed, just rebuild)
- Returns list of datasets → graph has data; diagnose before wiping
