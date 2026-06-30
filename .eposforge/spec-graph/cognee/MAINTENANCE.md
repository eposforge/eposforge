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
error has been observed on already-empty databases and does not reliably
indicate corruption. Check `GET /api/v1/datasets` first — if it returns `[]`
the graph is already empty and no wipe is needed.

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

## Checking dataset state before any intervention

```bash
curl -s http://127.0.0.1:18000/api/v1/datasets | python3 -m json.tool
```

- Returns `[]` → graph is empty (no wipe needed, just rebuild)
- Returns list of datasets → graph has data; diagnose before wiping
