#!/usr/bin/env python3
"""Adopter-safe recall wrapper for Cognee search results.

This script addresses two recall quality gaps:
1) Prevent leaking EposForge internal implementation paths (EF-011).
2) Tag each recommendation with maturity (shipped|partial|intent) (EF-012).

Usage:
    python instance/spec-graph/cognee/scripts/adopter-recall.py \
      --query "how does an adopter org do secrets handling for CI"

Environment:
    COGNEE_API_URL       Required. Example: https://cognee-api.example.lan
    COGNEE_API_TOKEN     Optional bearer token
    COGNEE_DATASET_NAME  Optional default dataset (default: eposforge-sync)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from typing import Any

DEFAULT_DATASET = "eposforge-sync"
SEARCH_TYPE = "GRAPH_COMPLETION"

_INTERNAL_PATH_RE = re.compile(r"\binstance/[^\s`'\")\]]+")
_MATURITY_RE = re.compile(r"\[maturity:\s*(shipped|partial|intent)\]", re.IGNORECASE)

INTENT_HINTS = (
    "future",
    "planned",
    "target",
    "not yet",
    "aspirational",
    "proposed",
    "roadmap",
)

PARTIAL_HINTS = (
    "partial",
    "workaround",
    "manual",
    "gap",
    "limited",
    "currently requires",
)


def _build_system_prompt(mode: str) -> str:
    mode_note = (
        "Prefer shipped behavior. Only include intent when explicitly asked."
        if mode == "operational"
        else "Include target-state intent alongside current behavior."
    )
    return (
        "You are generating guidance for an adopter org, not for the canonical "
        "EposForge repo internals. "
        "Never present EposForge internal filesystem paths as adopter-run commands. "
        "If a source mentions instance/* paths, translate to adopter-layer "
        "guidance and state prerequisites explicitly. "
        "For every recommendation line, include a maturity tag exactly as "
        "[maturity: shipped], [maturity: partial], or [maturity: intent]. "
        + mode_note
    )


def _infer_maturity(text: str) -> str:
    lower = text.lower()
    if any(token in lower for token in INTENT_HINTS):
        return "intent"
    if any(token in lower for token in PARTIAL_HINTS):
        return "partial"
    return "shipped"


def _sanitize_paths(text: str) -> str:
    if not _INTERNAL_PATH_RE.search(text):
        return text
    rewritten = _INTERNAL_PATH_RE.sub("<adopter-layout-path>", text)
    note = (
        "\nPrerequisite: if you need the canonical implementation details, "
        "open the EposForge reference adapter card and map it to your adopter layout."
    )
    return rewritten + note


def _ensure_maturity_tag(text: str) -> str:
    if _MATURITY_RE.search(text):
        return text
    return f"[maturity: {_infer_maturity(text)}] {text}"


def _extract_text(item: Any) -> str:
    if isinstance(item, str):
        return item
    if isinstance(item, dict):
        for key in ("text", "answer", "content", "summary"):
            value = item.get(key)
            if isinstance(value, str) and value.strip():
                return value
        return json.dumps(item, ensure_ascii=True)
    return str(item)


def _post_search(
    base_url: str,
    token: str,
    query: str,
    datasets: list[str],
    top_k: int,
    mode: str,
) -> list[Any]:
    payload = {
        "query": query,
        "search_type": SEARCH_TYPE,
        "datasets": datasets,
        "top_k": top_k,
        "system_prompt": _build_system_prompt(mode),
    }

    body = json.dumps(payload).encode("utf-8")
    endpoint = base_url.rstrip("/") + "/api/v1/search"
    req = urllib.request.Request(endpoint, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            data = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        message = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cognee search failed: HTTP {exc.code} {message}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Cognee search failed: {exc}") from exc

    parsed = json.loads(data)
    if not isinstance(parsed, list):
        return [parsed]
    return parsed


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="adopter-recall")
    parser.add_argument("--query", required=True, help="Natural-language recall query")
    parser.add_argument(
        "--dataset",
        action="append",
        dest="datasets",
        help="Dataset name (repeatable). Defaults to COGNEE_DATASET_NAME or eposforge-sync.",
    )
    parser.add_argument("--top-k", type=int, default=5, help="Maximum results")
    parser.add_argument(
        "--mode",
        choices=("operational", "design"),
        default="operational",
        help="Operational mode biases toward currently shipped behavior.",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()

    base_url = os.environ.get("COGNEE_API_URL", "").strip()
    if not base_url:
        print("ERROR: COGNEE_API_URL is required.", file=sys.stderr)
        return 1

    token = os.environ.get("COGNEE_API_TOKEN", "").strip()
    datasets = args.datasets or [os.environ.get("COGNEE_DATASET_NAME", DEFAULT_DATASET)]

    try:
        raw_items = _post_search(
            base_url=base_url,
            token=token,
            query=args.query,
            datasets=datasets,
            top_k=args.top_k,
            mode=args.mode,
        )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    normalized = []
    for item in raw_items:
        text = _extract_text(item)
        text = _sanitize_paths(text)
        text = _ensure_maturity_tag(text)
        normalized.append(
            {
                "maturity": _infer_maturity(text),
                "answer": text,
            }
        )

    if args.json:
        print(json.dumps(normalized, indent=2, ensure_ascii=True))
        return 0

    if not normalized:
        print("No results.")
        return 0

    for idx, entry in enumerate(normalized, start=1):
        print(f"{idx}. {entry['answer']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
