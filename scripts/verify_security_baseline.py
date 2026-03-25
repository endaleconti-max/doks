#!/usr/bin/env python3
"""Verify security baseline controls through executable checks.

This script validates:
- Encrypted state-at-rest envelope and key generation.
- Key integrity and restrictive key-file permissions.
- Permission gate enforcement for tool execution.
- Persistence safety gate when encrypted state exists but key is missing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ID_PATTERN = re.compile(r"^ID:\s+([0-9A-F-]{36})$", re.MULTILINE)


@dataclass
class VerificationReport:
    generatedAt: str
    packagePath: str
    checks: dict[str, bool]
    details: dict[str, str]
    overallPassed: bool


def run_command(cwd: Path, command: list[str], timeout_seconds: int) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_seconds,
        )
        output = (completed.stdout or "") + (completed.stderr or "")
        return completed.returncode, output
    except subprocess.TimeoutExpired as exc:
        captured = (exc.stdout or "") + (exc.stderr or "")
        return 124, f"Command timed out after {timeout_seconds}s: {' '.join(command)}\n{captured}"


def run_cli(package_path: Path, workdir: Path, args: list[str], timeout_seconds: int) -> tuple[int, str]:
    built_binary = package_path / ".build" / "debug" / "DocumentOrganizer"
    if built_binary.exists() and built_binary.is_file():
        command = [str(built_binary), *args]
    else:
        command = ["swift", "run", "--package-path", str(package_path), "DocumentOrganizer", *args]
    return run_command(workdir, command, timeout_seconds=timeout_seconds)


def extract_ids(output: str) -> list[str]:
    return ID_PATTERN.findall(output)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify security baseline")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/security-baseline-report.json")
    parser.add_argument("--command-timeout-seconds", type=int, default=90)
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    with tempfile.TemporaryDirectory(prefix="documentorganizer-security-") as temp_dir:
        workdir = Path(temp_dir)
        audit_dir = workdir / "audit"
        audit_dir.mkdir(parents=True, exist_ok=True)

        sample_invoice = package_path / "samples" / "invoice.txt"
        sample_resume = package_path / "samples" / "resume.txt"
        local_invoice = workdir / "invoice.txt"
        local_resume = workdir / "resume.txt"
        shutil.copy2(sample_invoice, local_invoice)
        shutil.copy2(sample_resume, local_resume)

        import_code, import_output = run_cli(
            package_path,
            workdir,
            ["import", str(local_invoice), str(local_resume)],
            timeout_seconds=args.command_timeout_seconds,
        )
        doc_ids = extract_ids(import_output)
        checks["seed_import_succeeds"] = import_code == 0 and len(doc_ids) >= 2
        details["seed_import"] = "ok" if checks["seed_import_succeeds"] else import_output[-2000:]

        state_path = audit_dir / "organizer-state.json"
        key_path = audit_dir / "organizer-state.key"

        checks["state_file_exists"] = state_path.exists()
        checks["key_file_exists"] = key_path.exists()

        encrypted_envelope_ok = False
        if state_path.exists():
            try:
                payload = json.loads(state_path.read_text(encoding="utf-8"))
                encrypted_envelope_ok = payload.get("algorithm") == "AES.GCM" and "combinedCiphertext" in payload
            except Exception:
                encrypted_envelope_ok = False
        checks["state_encrypted_at_rest"] = encrypted_envelope_ok
        details["state_encryption"] = "ok" if encrypted_envelope_ok else "State file missing AES.GCM envelope"

        key_integrity_ok = False
        key_permission_ok = False
        if key_path.exists():
            key_bytes = key_path.read_bytes()
            key_integrity_ok = len(key_bytes) == 32
            mode = os.stat(key_path).st_mode & 0o777
            key_permission_ok = mode <= 0o600
            details["key_permissions"] = f"mode={oct(mode)}"
        else:
            details["key_permissions"] = "key file missing"

        checks["key_length_32_bytes"] = key_integrity_ok
        checks["key_permissions_restrictive"] = key_permission_ok

        # Verify plugin permission gate is enforced by default.
        target_id = doc_ids[0] if doc_ids else ""
        run_tool_code, run_tool_output = run_cli(
            package_path,
            workdir,
            ["run-tool", target_id, "text-to-markdown"] if target_id else ["run-tool"],
            timeout_seconds=args.command_timeout_seconds,
        )
        # CLI currently may return code 0 on handled errors, so check output semantics.
        permission_denied = "Required permissions not granted for plugin" in run_tool_output
        checks["plugin_permission_gate_enforced"] = permission_denied
        details["plugin_permission_gate"] = "ok" if permission_denied else run_tool_output[-2000:]

        # Verify persistence safety gate when key is missing for existing encrypted state.
        if key_path.exists():
            key_path.unlink()

        followup_file = workdir / "new-note.txt"
        followup_file.write_text("Resume\nExperience\nSkills\n", encoding="utf-8")
        import_after_key_loss_code, import_after_key_loss_output = run_cli(
            package_path,
            workdir,
            ["import", str(followup_file)],
            timeout_seconds=args.command_timeout_seconds,
        )

        blocks_persist = "Refusing to overwrite existing state because initial load failed" in import_after_key_loss_output
        warns_user = "No state-changing operations will be persisted" in import_after_key_loss_output
        checks["persistence_safety_gate_blocks_overwrite"] = blocks_persist
        checks["user_warned_on_state_load_issue"] = warns_user
        details["state_load_safety_gate"] = (
            "ok" if blocks_persist and warns_user else import_after_key_loss_output[-2000:]
        )

    overall = all(checks.values())
    report = VerificationReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        overallPassed=overall,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")

    print(f"Security baseline verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
