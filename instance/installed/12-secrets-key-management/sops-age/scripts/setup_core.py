#!/usr/bin/env python3
"""Cross-platform helpers for sops-age machine bootstrap and recipient authorization.

Subcommands:
  request   - target machine: ensure local age key and emit authorization request JSON
  authorize - approver machine: verify fingerprint, add recipient to .sops.yaml, rekey secrets
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import socket
import subprocess
import sys
from typing import Iterable

AGE_PUBKEY_RE = re.compile(r"^age1[0-9a-z]{58}$")


def _repo_root() -> pathlib.Path:
    # setup_core.py -> scripts -> sops-age -> 12-secrets-key-management -> installed -> instance -> repo
    return pathlib.Path(__file__).resolve().parents[6]


def _default_key_path() -> pathlib.Path:
    if os.name == "nt":
        appdata = os.environ.get("APPDATA")
        if not appdata:
            raise RuntimeError("APPDATA is not set; cannot resolve Windows age key path")
        return pathlib.Path(appdata) / "sops" / "age" / "keys.txt"
    return pathlib.Path.home() / ".config" / "sops" / "age" / "keys.txt"


def _run(cmd: list[str], *, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        capture_output=capture,
    )


def _require_tool(name: str) -> None:
    try:
        _run([name, "--version"], check=True, capture=True)
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required tool '{name}' not found on PATH") from exc
    except subprocess.CalledProcessError:
        # Some tools may not support --version reliably; existence on PATH is enough.
        pass


def _extract_pubkey_from_keyfile(key_path: pathlib.Path) -> str | None:
    if not key_path.exists():
        return None

    for line in key_path.read_text(encoding="utf-8").splitlines():
        marker = "# public key: "
        if line.startswith(marker):
            return line[len(marker) :].strip()
    return None


def _ensure_age_key(key_path: pathlib.Path) -> str:
    _require_tool("age-keygen")
    key_path.parent.mkdir(parents=True, exist_ok=True)

    pubkey = _extract_pubkey_from_keyfile(key_path)
    if pubkey and AGE_PUBKEY_RE.match(pubkey):
        return pubkey

    _run(["age-keygen", "-o", str(key_path)], check=True)
    if os.name != "nt":
        os.chmod(key_path, 0o600)

    pubkey = _extract_pubkey_from_keyfile(key_path)
    if not pubkey:
        raise RuntimeError(f"Failed to read public key from {key_path}")
    return pubkey


def _fingerprint(pubkey: str) -> str:
    digest = hashlib.sha256(pubkey.encode("utf-8")).hexdigest()
    return digest[:16]


def _validate_pubkey(pubkey: str) -> None:
    if not AGE_PUBKEY_RE.match(pubkey):
        raise RuntimeError("Invalid age public key format")


def _load_yaml_lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def _parse_age_recipients(lines: list[str]) -> tuple[int, int, str, list[str]]:
    age_line_index = -1
    age_indent = ""

    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "age: >-":
            age_line_index = idx
            age_indent = line[: len(line) - len(line.lstrip(" "))]
            break

    if age_line_index < 0:
        raise RuntimeError("Could not find 'age: >-' block in .sops.yaml")

    body_start = age_line_index + 1
    body_end = body_start
    body_indent = age_indent + "  "

    while body_end < len(lines):
        line = lines[body_end]
        if line.strip() == "":
            break
        if line.startswith(body_indent):
            body_end += 1
            continue
        break

    body_values = "".join(line.strip() for line in lines[body_start:body_end]).strip()
    recipients = [token for token in re.split(r"[\s,]+", body_values) if token]

    return body_start, body_end, body_indent, recipients


def _set_age_recipients(sops_yaml: pathlib.Path, recipients: Iterable[str]) -> None:
    deduped = sorted(set(recipients))
    for key in deduped:
        _validate_pubkey(key)

    lines = _load_yaml_lines(sops_yaml)
    body_start, body_end, body_indent, _ = _parse_age_recipients(lines)

    new_body = [f"{body_indent}{key}\n" for key in deduped]
    new_lines = lines[:body_start] + new_body + lines[body_end:]
    sops_yaml.write_text("".join(new_lines), encoding="utf-8")


def _request_cmd(args: argparse.Namespace) -> int:
    key_path = pathlib.Path(args.key_path) if args.key_path else _default_key_path()
    pubkey = _ensure_age_key(key_path)
    _validate_pubkey(pubkey)

    payload = {
        "schema_version": "1",
        "hostname": args.hostname or socket.gethostname(),
        "public_key": pubkey,
        "fingerprint": _fingerprint(pubkey),
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "key_path": str(key_path),
    }

    output = pathlib.Path(args.output) if args.output else pathlib.Path.cwd() / "epos-machine-request.json"
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(f"[OK] Wrote machine request to {output}")
    print(f"Public key: {pubkey}")
    print(f"Fingerprint: {payload['fingerprint']}")
    print("Share the request JSON and fingerprint with the approving operator out-of-band.")
    return 0


def _authorize_cmd(args: argparse.Namespace) -> int:
    _require_tool("sops")

    repo_root = pathlib.Path(args.repo_root) if args.repo_root else _repo_root()
    sops_yaml = repo_root / "instance" / "installed" / "12-secrets-key-management" / "sops-age" / ".sops.yaml"
    enc_yaml = repo_root / "instance" / "installed" / "12-secrets-key-management" / "sops-age" / "secrets.enc.yaml"

    if args.request_file:
        request_data = json.loads(pathlib.Path(args.request_file).read_text(encoding="utf-8"))
        pubkey = request_data["public_key"]
        claimed_fingerprint = request_data.get("fingerprint")
        hostname = request_data.get("hostname", "unknown")
    else:
        if not args.public_key:
            raise RuntimeError("Either --request-file or --public-key is required")
        pubkey = args.public_key.strip()
        claimed_fingerprint = args.fingerprint
        hostname = args.hostname or "unknown"

    _validate_pubkey(pubkey)
    computed = _fingerprint(pubkey)

    if claimed_fingerprint and computed != claimed_fingerprint:
        raise RuntimeError(
            f"Fingerprint mismatch: computed={computed} claimed={claimed_fingerprint}. Refusing authorization."
        )

    lines = _load_yaml_lines(sops_yaml)
    _, _, _, existing = _parse_age_recipients(lines)

    if pubkey in existing:
        print("[SKIP] Recipient already present in .sops.yaml")
        print(f"Fingerprint: {computed}")
        return 0

    if not args.yes:
        print("Authorize recipient:")
        print(f"  Hostname: {hostname}")
        print(f"  Public key: {pubkey}")
        print(f"  Fingerprint: {computed}")
        answer = input("Type the fingerprint to confirm authorization: ").strip()
        if answer != computed:
            raise RuntimeError("Fingerprint confirmation failed; aborting")

    _set_age_recipients(sops_yaml, existing + [pubkey])

    _run(["sops", "updatekeys", str(enc_yaml)], check=True)

    audit = {
        "ts": dt.datetime.now(dt.timezone.utc).isoformat(),
        "event": "recipient.authorized",
        "hostname": hostname,
        "public_key": pubkey,
        "fingerprint": computed,
    }
    print(json.dumps(audit))
    print("[OK] Recipient authorized and secrets.enc.yaml re-keyed. Commit .sops.yaml and secrets.enc.yaml.")
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="sops-age machine bootstrap and recipient authorization helpers")
    sub = parser.add_subparsers(dest="command", required=True)

    req = sub.add_parser("request", help="Generate/request machine authorization payload")
    req.add_argument("--key-path", help="Override age keys.txt path")
    req.add_argument("--hostname", help="Override hostname in generated request")
    req.add_argument("--output", help="Output JSON file path")
    req.set_defaults(func=_request_cmd)

    auth = sub.add_parser("authorize", help="Authorize a machine recipient and re-key secrets")
    auth.add_argument("--repo-root", help="Override repository root path")
    auth.add_argument("--request-file", help="Path to machine request JSON")
    auth.add_argument("--public-key", help="Age public key when request-file is not used")
    auth.add_argument("--fingerprint", help="Claimed short fingerprint for public key")
    auth.add_argument("--hostname", help="Hostname for audit output when not using request-file")
    auth.add_argument("-y", "--yes", action="store_true", help="Skip interactive fingerprint prompt")
    auth.set_defaults(func=_authorize_cmd)

    return parser


def main() -> int:
    try:
        parser = _build_parser()
        args = parser.parse_args()
        return args.func(args)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
