# Cognee Maintenance Procedures

Operator-only procedures. Agents MUST NOT run the wipe steps below without
explicit operator confirmation using the exact phrase **"I authorize KG wipe"**.

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
