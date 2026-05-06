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
    return pathlib.Path(__file__).resolve().parents[5]


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

    body_values = " ".join(line.strip() for line in lines[body_start:body_end]).strip()
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

    hostname = args.hostname or socket.gethostname()
    fingerprint = _fingerprint(pubkey)

    payload = {
        "schema_version": "1",
        "hostname": hostname,
        "public_key": pubkey,
        "fingerprint": fingerprint,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "key_path": str(key_path),
    }

    output = pathlib.Path(args.output) if args.output else pathlib.Path.cwd() / "epos-machine-request.json"
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    # Interactive mode: display everything and prompt to save private key
    print("\n" + "=" * 70)
    print("MACHINE AUTHORIZATION REQUEST")
    print("=" * 70)
    print(f"\nMachine:    {hostname}")
    print(f"Fingerprint: {fingerprint}")
    print(f"Public key: {pubkey}")
    print(f"\n⚠️  SAVE THIS PRIVATE KEY TO YOUR SECRETS VAULT:")
    print("\nPrivate key (copy entire file):")
    print("-" * 70)
    print(key_path.read_text(encoding="utf-8"), end="")
    print("-" * 70)
    print(f"\n✅ Once saved, press Enter to proceed...")
    saved = input()

    print(f"\n📋 Share the following with your approver to authorize this machine:")
    print(f"\n   epos-authorize {hostname} {fingerprint} {pubkey}")
    print()
    return 0


def _authorize_cmd(args: argparse.Namespace) -> int:
    _require_tool("sops")
    _require_tool("git")

    repo_root = pathlib.Path(args.repo_root) if args.repo_root else _repo_root()
    sops_yaml = repo_root / "instance" / "installed" / "12-secrets-key-management" / "sops-age" / ".sops.yaml"
    enc_yaml = repo_root / "instance" / "installed" / "12-secrets-key-management" / "sops-age" / "secrets.enc.yaml"

    # Debug output
    # print(f"DEBUG: machine={args.machine!r}, fingerprint={args.fingerprint!r}, pubkey={getattr(args, 'pubkey', None)!r}, public_key={args.public_key!r}", file=sys.stderr)

    # Support multiple input modes:
    # 1. Request file (backward compat)
    # 2. Three positional args: machine fingerprint pubkey (from request output)
    # 3. Flags + positional: --public-key with machine/fingerprint
    # 4. Interactive mode
    if args.request_file:
        request_data = json.loads(pathlib.Path(args.request_file).read_text(encoding="utf-8"))
        pubkey = request_data["public_key"]
        claimed_fingerprint = request_data.get("fingerprint")
        hostname = request_data.get("hostname", "unknown")
    elif args.machine and args.fingerprint and getattr(args, 'pubkey', None):
        # All three positional args provided
        pubkey = args.pubkey.strip()
        claimed_fingerprint = args.fingerprint
        hostname = args.machine
    elif args.machine and args.fingerprint and args.public_key:
        # Backward compat: --public-key flag with machine/fingerprint
        pubkey = args.public_key.strip()
        claimed_fingerprint = args.fingerprint
        hostname = args.machine
    else:
        # Interactive mode: prompt for machine name and fingerprint
        hostname = args.machine or input("Machine name: ").strip()
        claimed_fingerprint = args.fingerprint or input("Fingerprint (from requesting machine): ").strip()
        pubkey = getattr(args, 'pubkey', None) or args.public_key or input("Public key (age1...): ").strip()

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

    # Interactive approval
    print("\n" + "=" * 70)
    print("AUTHORIZATION CONFIRMATION")
    print("=" * 70)
    print(f"\nMachine:    {hostname}")
    print(f"Fingerprint: {computed}")
    answer = input("\nApprove this machine? (y/n): ").strip().lower()
    if answer != "y":
        print("Authorization cancelled.")
        return 1

    _set_age_recipients(sops_yaml, existing + [pubkey])

    # Change to sops-age directory for sops updatekeys to find .sops.yaml
    sops_dir = sops_yaml.parent
    old_cwd = os.getcwd()
    try:
        os.chdir(sops_dir)
        _run(["sops", "updatekeys", str(enc_yaml)], check=True)
    finally:
        os.chdir(old_cwd)

    # Auto-commit
    os.chdir(repo_root)
    _run(["git", "add", str(sops_yaml), str(enc_yaml)], check=True)
    commit_msg = f"sops: authorize machine {hostname} ({computed})"
    _run(["git", "commit", "-m", commit_msg], check=True)

    print("\n✅ Authorization complete!")
    print(f"\nNext steps on {hostname}:")
    print(f"  1. git pull")
    print(f"  2. epos-secrets --check")
    print(f"\n")

    # Offer to push
    push = input("Push changes now? (y/n): ").strip().lower()
    if push == "y":
        _run(["git", "push"], check=True)
        print(f"✅ Pushed. Run 'git pull' on {hostname} to receive updates.")

    audit = {
        "ts": dt.datetime.now(dt.timezone.utc).isoformat(),
        "event": "recipient.authorized",
        "hostname": hostname,
        "public_key": pubkey,
        "fingerprint": computed,
    }
    print(json.dumps(audit))
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
    auth.add_argument("machine", nargs="?", help="Machine name to authorize")
    auth.add_argument("fingerprint", nargs="?", help="Fingerprint from requesting machine")
    auth.add_argument("pubkey", nargs="?", help="Public key (age1...) from requesting machine")
    auth.add_argument("--repo-root", help="Override repository root path")
    auth.add_argument("--request-file", help="Path to machine request JSON")
    auth.add_argument("--public-key", help="Age public key when request-file is not used")
    auth.add_argument("--hostname", help="Hostname for audit output (deprecated; use positional machine)")
    auth.add_argument("-y", "--yes", action="store_true", help="Skip interactive prompt")
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
