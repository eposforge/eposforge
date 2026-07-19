"""CLI entry point for cognee-sync.

Usage (invoked via epos-secrets for secret injection):

    epos-secrets uv run cognee-sync --added path/to/file.md
    epos-secrets uv run cognee-sync --modified path/a.md path/b.md
    epos-secrets uv run cognee-sync --deleted path/old.md
    epos-secrets uv run cognee-sync --status

Gitea Actions / post-receive hook pattern:

    ADDED=$(git diff --name-only --diff-filter=A $BASE..$HEAD -- '*.md')
    MODIFIED=$(git diff --name-only --diff-filter=M $BASE..$HEAD -- '*.md')
    DELETED=$(git diff --name-only --diff-filter=D $BASE..$HEAD -- '*.md')
    epos-secrets uv run cognee-sync \\
        ${ADDED:+--added $ADDED} \\
        ${MODIFIED:+--modified $MODIFIED} \\
        ${DELETED:+--deleted $DELETED}

Environment variables (injected by epos-secrets):
    COGNEE_API_URL         Base URL of the Cognee HTTP API (required)
    COGNEE_API_TOKEN       Bearer token (optional — anonymous if absent)
    COGNEE_TLS_VERIFY      false / path to CA bundle (optional)
    COGNEE_DATASET_NAME    Dataset to sync into (default: eposforge-sync)
    COGNEE_STATE_DB        Path to SQLite state store (default: .cognee-state.db)
    COGNEE_ONTOLOGY_KEY    Uploaded ontology key to anchor cognify against (optional)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from . import sync as _sync
from .client import CogneeClient
from .config import load_config
from .state import StateStore

# Default state DB lives alongside the sync project itself, committed to source.
# cli.py is at src/cognee_sync/cli.py; three parents up = sync/
_DEFAULT_STATE_DB = str(Path(__file__).parent.parent.parent / ".cognee-state.db")
_REPO_ROOT = Path(__file__).resolve().parents[6]


def _script_path(relative_path: str) -> str:
    return str(_REPO_ROOT / relative_path)


def _is_truthy(value: str | None) -> bool:
    if value is None:
        return False
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _validate_inference_routing() -> None:
    provider = os.environ.get("INFERENCE_PROVIDER", "").strip()
    require_azure = _is_truthy(os.environ.get("COGNEE_REQUIRE_AZURE_ROUTING"))

    if require_azure and provider != "azure-foundry":
        raise RuntimeError(
            "COGNEE_REQUIRE_AZURE_ROUTING=1 but INFERENCE_PROVIDER is not "
            "'azure-foundry'. Refusing to run sync with non-Azure routing."
        )

    if provider != "azure-foundry" and not require_azure:
        return

    llm_model = os.environ.get("LLM_MODEL", "").strip()
    embedding_model = os.environ.get("EMBEDDING_MODEL", "").strip()

    validator = _script_path(
        ".eposforge/inference/scripts/validate-azure-routing-config.sh"
    )

    proc = subprocess.run(
        [
            "bash",
            validator,
            "--provider",
            "azure-foundry",
            "--llm-model",
            llm_model,
            "--embedding-model",
            embedding_model,
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    if proc.returncode != 0:
        details = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(f"Azure routing validation failed: {details}")


def _estimate_requested_tokens(args: argparse.Namespace, changed_files: int) -> int:
    if args.budget_requested_tokens is not None:
        return args.budget_requested_tokens

    env_requested = os.environ.get("INFERENCE_BUDGET_REQUESTED_TOKENS", "").strip()
    if env_requested:
        try:
            return int(env_requested)
        except ValueError as exc:
            raise RuntimeError(
                "INFERENCE_BUDGET_REQUESTED_TOKENS must be an integer"
            ) from exc

    per_file = os.environ.get("INFERENCE_BUDGET_TOKENS_PER_FILE", "4000").strip()
    try:
        per_file_tokens = int(per_file)
    except ValueError as exc:
        raise RuntimeError("INFERENCE_BUDGET_TOKENS_PER_FILE must be an integer") from exc

    file_count = max(changed_files, 1)
    return max(file_count * per_file_tokens, 0)


def _run_budget_gate(repo_key: str, requested_tokens: int, model: str) -> dict[str, object]:
    checker = _script_path(".eposforge/inference/scripts/check-budget-gate.sh")
    proc = subprocess.run(
        [
            "bash",
            checker,
            "--repo-key",
            repo_key,
            "--requested-tokens",
            str(requested_tokens),
            "--model",
            model,
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    output = (proc.stdout or "").strip()
    if not output:
        details = (proc.stderr or "").strip()
        raise RuntimeError(f"Budget gate failed without JSON output: {details}")

    try:
        decision = json.loads(output)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Budget gate returned invalid JSON: {output}") from exc

    if not isinstance(decision, dict):
        raise RuntimeError("Budget gate response must be a JSON object")
    return decision


def _record_budget_usage(repo_key: str, consumed_tokens: int) -> None:
    recorder = _script_path(".eposforge/inference/scripts/record-budget-usage.sh")
    proc = subprocess.run(
        [
            "bash",
            recorder,
            "--repo-key",
            repo_key,
            "--consumed-tokens",
            str(consumed_tokens),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    if proc.returncode != 0:
        details = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(f"Failed to record budget usage: {details}")


def _read_actual_tokens(usage_file: str, since_ts: float) -> dict[str, int] | None:
    """Sum token counts from the LiteLLM JSONL tracker file written after `since_ts`.

    Returns None when the file is absent or contains no records in the window,
    so callers can fall back to estimated counts.
    """
    try:
        path = Path(usage_file)
        if not path.exists():
            return None
        prompt = completion = total = 0
        found = False
        with path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts_str = record.get("ts", "")
                if not ts_str:
                    continue
                try:
                    record_ts = datetime.fromisoformat(ts_str).timestamp()
                except ValueError:
                    continue
                if record_ts < since_ts:
                    continue
                prompt += record.get("prompt_tokens", 0) or 0
                completion += record.get("completion_tokens", 0) or 0
                total += record.get("total_tokens", 0) or 0
                found = True
        if not found:
            return None
        return {"prompt_tokens": prompt, "completion_tokens": completion, "total_tokens": total}
    except OSError:
        return None


def _emit_token_usage_event(
    repo_key: str,
    dataset_name: str,
    model: str,
    prompt_tokens: int,
    completion_tokens: int,
    total_tokens: int,
    latency_ms: int,
) -> None:
    emitter = _script_path(".eposforge/inference/scripts/emit-token-usage-event.sh")
    proc = subprocess.run(
        [
            "bash",
            emitter,
            "--repo",
            repo_key,
            "--dataset",
            dataset_name,
            "--phase",
            "cognify",
            "--model",
            model,
            "--prompt-tokens",
            str(prompt_tokens),
            "--completion-tokens",
            str(completion_tokens),
            "--total-tokens",
            str(total_tokens),
            "--latency-ms",
            str(max(latency_ms, 0)),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    if proc.returncode != 0:
        details = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(f"Failed to emit token usage event: {details}")


def _token_usage_counts(
    requested_tokens: int,
    actual: dict[str, int] | None,
) -> tuple[int, int, int]:
    if actual is not None:
        return (
            actual["prompt_tokens"],
            actual["completion_tokens"],
            actual["total_tokens"],
        )
    return (requested_tokens, 0, requested_tokens)


def _record_budget_reservation(repo_key: str, requested_tokens: int, budget_enforce: bool) -> None:
    if budget_enforce:
        _record_budget_usage(repo_key, requested_tokens)


def _record_cognify_usage(
    *,
    repo_key: str,
    dataset_name: str,
    model: str,
    requested_tokens: int,
    actual: dict[str, int] | None,
    latency_ms: int,
    budget_enforce: bool,
    emit_usage_events: bool,
) -> None:
    prompt_tokens, completion_tokens, consumed_tokens = _token_usage_counts(
        requested_tokens,
        actual,
    )

    if budget_enforce:
        recorded_tokens = consumed_tokens - requested_tokens
        if recorded_tokens > 0:
            _record_budget_usage(repo_key, recorded_tokens)

    if emit_usage_events:
        _emit_token_usage_event(
            repo_key=repo_key,
            dataset_name=dataset_name,
            model=model,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=consumed_tokens,
            latency_ms=latency_ms,
        )


def _state_store(args: argparse.Namespace) -> StateStore:
    db_path = args.db or os.environ.get("COGNEE_STATE_DB", _DEFAULT_STATE_DB)
    return StateStore(db_path)


def _dataset_name(args: argparse.Namespace) -> str:
    return args.dataset or os.environ.get("COGNEE_DATASET_NAME", "eposforge-sync")


def _ontology_key(args: argparse.Namespace) -> str | None:
    key = args.ontology_key or os.environ.get("COGNEE_ONTOLOGY_KEY", "")
    key = key.strip()
    return key or None


def _http_timeout_seconds() -> float:
    raw_timeout = os.environ.get("COGNEE_HTTP_TIMEOUT", "900").strip()
    try:
        timeout = float(raw_timeout)
    except ValueError as exc:
        raise RuntimeError("COGNEE_HTTP_TIMEOUT must be a number") from exc
    if timeout <= 0:
        raise RuntimeError("COGNEE_HTTP_TIMEOUT must be greater than 0")
    return timeout


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="cognee-sync",
        description="Sync EposForge Markdown files to the Cognee knowledge graph.",
    )
    parser.add_argument(
        "--dataset",
        default=None,
        metavar="NAME",
        help="Cognee dataset name (default: $COGNEE_DATASET_NAME or 'eposforge-sync')",
    )
    parser.add_argument("--db", default=None, metavar="PATH",
                        help="State DB path (default: $COGNEE_STATE_DB or '.cognee-state.db')")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print planned actions without calling the API")
    parser.add_argument("--status", action="store_true",
                        help="List tracked files and exit")
    parser.add_argument("--added", nargs="*", default=[], metavar="FILE",
                        help="Files to add (new to Cognee)")
    parser.add_argument("--modified", nargs="*", default=[], metavar="FILE",
                        help="Files to update (delete old + add new)")
    parser.add_argument("--deleted", nargs="*", default=[], metavar="FILE",
                        help="Files to remove from Cognee")
    parser.add_argument("--no-cognify", action="store_true",
                        help="Skip the post-run cognify call. Use when batching multiple "
                             "cognee-sync invocations and you'll cognify manually at the end. "
                             "Default: run cognify against the target dataset after add/update.")
    parser.add_argument(
        "--ontology-key",
        default=None,
        metavar="KEY",
        help="Uploaded ontology key to anchor cognify entity extraction against "
             "(default: $COGNEE_ONTOLOGY_KEY). When set, cognify is called with "
             "ontologyKey=[KEY] so extracted entities are matched to the ontology.",
    )
    parser.add_argument(
        "--upload-ontology",
        default=None,
        metavar="PATH",
        help="Upload (delete + re-upload) the ontology file at PATH under "
             "--ontology-key before cognify. Use on a full rebuild; omit on "
             "incremental runs where the ontology is already uploaded.",
    )
    parser.add_argument(
        "--repo-key",
        default=None,
        metavar="KEY",
        help="Budget/event repo key (default: $INFERENCE_BUDGET_REPO_KEY or repo name)",
    )
    parser.add_argument("--budget-requested-tokens", type=int, default=None, metavar="N",
                        help="Token estimate for this sync run when budgeting is enforced")

    args = parser.parse_args()

    _validate_inference_routing()

    if args.status:
        state = _state_store(args)
        records = state.list_all()
        if not records:
            print("No files tracked.")
        else:
            print(f"{'file_path':<60}  {'data_id':>8}  synced_at")
            print("-" * 95)
            for r in records:
                print(f"{r.file_path:<60}  {r.data_id[:8]}...  {r.synced_at}")
        sys.exit(0)

    if not any([args.added, args.modified, args.deleted]):
        parser.print_help()
        sys.exit(0)

    if args.dry_run:
        if args.upload_ontology:
            print(f"[dry-run] upload ontology: {args.upload_ontology} (key={_ontology_key(args)})")
        for f in (args.added or []):
            print(f"[dry-run] add:    {f}")
        for f in (args.modified or []):
            print(f"[dry-run] update: {f}")
        for f in (args.deleted or []):
            print(f"[dry-run] delete: {f}")
        sys.exit(0)

    config = load_config()
    state = _state_store(args)
    dataset_name = _dataset_name(args)
    repo_key = args.repo_key or os.environ.get("INFERENCE_BUDGET_REPO_KEY", _REPO_ROOT.name)
    budget_enforce = _is_truthy(os.environ.get("INFERENCE_BUDGET_ENFORCE", "1"))
    emit_usage_events = _is_truthy(os.environ.get("INFERENCE_EMIT_USAGE_EVENTS", "1"))
    model = os.environ.get("LLM_MODEL", "").strip() or "unknown"
    changed_files = len(args.added or []) + len(args.modified or [])
    requested_tokens = _estimate_requested_tokens(args, changed_files)
    # Host-side path to the LiteLLM JSONL tracker written by litellm_token_tracker.py
    # inside dkr-cgnee-api.  Set to the ./data mount path on the host so cognee-sync
    # can read actual token counts after each cognify run.
    # Example: COGNEE_TOKEN_USAGE_FILE=/mnt/raid-storage/docker-volume-mounts/cognee/data/token-usage.jsonl
    token_usage_file = os.environ.get("COGNEE_TOKEN_USAGE_FILE", "").strip()

    ontology_key = _ontology_key(args)

    with CogneeClient(
        base_url=config.api_url,
        token=config.api_token,
        timeout=_http_timeout_seconds(),
        verify=config.tls_verify,
    ) as client:
        if args.upload_ontology:
            if not ontology_key:
                raise RuntimeError(
                    "--upload-ontology requires --ontology-key or $COGNEE_ONTOLOGY_KEY"
                )
            ontology_content = Path(args.upload_ontology).read_bytes()
            client.delete_ontology(ontology_key)
            client.upload_ontology(ontology_key, ontology_content)
            print(f"ontology uploaded: key={ontology_key} from {args.upload_ontology}")

        cognify_needed = False

        for file_path in (args.added or []):
            content = Path(file_path).read_bytes()
            result = _sync.sync_add(client, state, dataset_name, file_path, content)
            print(f"{result['action']:8} {file_path}")
            if result["action"] in ("add",):
                cognify_needed = True

        for file_path in (args.modified or []):
            content = Path(file_path).read_bytes()
            result = _sync.sync_update(client, state, dataset_name, file_path, content)
            print(f"{result['action']:8} {file_path}")
            if result["action"] in ("update", "add"):
                cognify_needed = True

        for file_path in (args.deleted or []):
            result = _sync.sync_delete(client, state, file_path)
            print(f"{result['action']:8} {file_path}")

        # Cognee 1.0.7+ does NOT run extraction implicitly on /add — files
        # land in raw storage but knowledge-graph nodes are not created
        # until /cognify is called. Run it once per CLI invocation against
        # the affected dataset so MCP recall / graph queries see new docs.
        if cognify_needed and not args.no_cognify:
            if budget_enforce:
                decision = _run_budget_gate(repo_key, requested_tokens, model)
                decision_name = str(decision.get("decision", ""))
                if decision_name == "deny":
                    print(json.dumps(decision))
                    sys.exit(4)
                if decision_name == "degrade":
                    recommended_model = str(decision.get("recommended_model", "")).strip()
                    if recommended_model:
                        os.environ["LLM_MODEL"] = recommended_model
                        model = recommended_model
                        print(
                            "budget: degrade requested, using recommended model "
                            f"{recommended_model}"
                        )

            _record_budget_reservation(repo_key, requested_tokens, budget_enforce)

            cognify_wall_start = datetime.now(timezone.utc).timestamp()
            started = time.perf_counter()
            anchor = f" (ontology={ontology_key})" if ontology_key else ""
            print(f"cognify {dataset_name}{anchor} ...", flush=True)
            actual = None
            # COGNEE_CHUNKS_PER_BATCH throttles cognee's internal cognify
            # concurrency. Large corpora at the default corrupt cognee's embedded
            # SQLite ("database disk image is malformed"); a small batch avoids it.
            _cpb = os.environ.get("COGNEE_CHUNKS_PER_BATCH")
            try:
                client.cognify(
                    datasets=[dataset_name],
                    run_in_background=False,
                    ontology_key=[ontology_key] if ontology_key else None,
                    chunks_per_batch=int(_cpb) if _cpb else None,
                )
                print(f"cognify {dataset_name} done")
            finally:
                latency_ms = int((time.perf_counter() - started) * 1000)

                # Resolve actual token counts from the LiteLLM tracker file when
                # available; fall back to the pre-run estimate so budget accounting
                # always has a value. If cognify failed or timed out, the reservation
                # above remains counted so a retry cannot evade the budget ledger.
                actual = (
                    _read_actual_tokens(token_usage_file, cognify_wall_start)
                    if token_usage_file
                    else None
                )
                if actual is not None:
                    print(
                        f"token usage (actual): prompt={actual['prompt_tokens']} "
                        f"completion={actual['completion_tokens']} total={actual['total_tokens']}"
                    )

                _record_cognify_usage(
                    repo_key=repo_key,
                    dataset_name=dataset_name,
                    model=model,
                    requested_tokens=requested_tokens,
                    actual=actual,
                    latency_ms=latency_ms,
                    budget_enforce=budget_enforce,
                    emit_usage_events=emit_usage_events,
                )

    sys.exit(0)
