"""Configuration for cognee-sync.

Reads COGNEE_API_URL and COGNEE_API_TOKEN from the process environment,
which are injected by the `epos-secrets` resolver shim before this process starts.
No decryption logic lives here — that is the resolver's responsibility.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

# Dataset name prefix used by the test harness.  Not a secret; lives here.
DATASET_PREFIX: str = "eposforge-sync-tests"


@dataclass(frozen=True)
class Config:
    api_url: str
    api_token: str = ""  # empty string = anonymous access
    dataset_prefix: str = DATASET_PREFIX
    tls_verify: bool | str = True  # False or path to CA bundle


def load_config() -> Config:
    """Build a Config from environment variables.

    ``COGNEE_API_URL`` is required.
    ``COGNEE_API_TOKEN`` is optional — omit it for anonymous access.

    Raises:
        RuntimeError: if COGNEE_API_URL is missing,
            with a hint to invoke via the epos-secrets resolver.
    """
    api_url = os.environ.get("COGNEE_API_URL", "")

    if not api_url:
        raise RuntimeError(
            "Missing required environment variable: COGNEE_API_URL. "
            "Invoke via the epos-secrets resolver, e.g.: "
            "  python instance/secrets-key-management/bin/epos-secrets "
            "  uv run pytest -m smoke"
        )

    api_token = os.environ.get("COGNEE_API_TOKEN", "")
    tls_verify: bool | str = True
    raw_verify = os.environ.get("COGNEE_TLS_VERIFY", "").strip()
    if raw_verify.lower() in ("false", "0", "no"):
        tls_verify = False
    elif raw_verify and raw_verify.lower() not in ("true", "1", "yes"):
        tls_verify = raw_verify  # treat as CA bundle path
    return Config(api_url=api_url.rstrip("/"), api_token=api_token, tls_verify=tls_verify)
