#!/usr/bin/env python3
"""Verify backup and restore behavior using export-state snapshots.

This script validates a practical local recovery workflow:
1. Import documents and export a plaintext backup snapshot.
2. Simulate state/key loss.
3. Restore from backup snapshot into organizer-state.json.
4. Confirm recovered documents are readable.
5. Confirm subsequent write re-encrypts state and recreates key material.
"""

from __future__ import annotations

import argparse
import json
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
    parser = argparse.ArgumentParser(description="Verify backup/restore workflow")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/backup-restore-report.json")
    parser.add_argument(
        "--command-timeout-seconds",
        type=int,
        default=90,
        help="Timeout for each CLI command invocation",
    )
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    with tempfile.TemporaryDirectory(prefix="documentorganizer-backup-restore-") as temp_dir:
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
        imported_ids = extract_ids(import_output)
        checks["seed_import_succeeds"] = import_code == 0 and len(imported_ids) >= 2
        details["seed_import"] = "ok" if checks["seed_import_succeeds"] else import_output[-2000:]

        state_path = audit_dir / "organizer-state.json"
        key_path = audit_dir / "organizer-state.key"
        checks["state_and_key_created"] = state_path.exists() and key_path.exists()
        details["initial_state_files"] = "ok" if checks["state_and_key_created"] else f"state={state_path.exists()} key={key_path.exists()}"

        backup_path = workdir / "backup" / "state-backup.json"
        export_code, export_output = run_cli(
            package_path,
            workdir,
            ["export-state", str(backup_path)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["export_state_succeeds"] = export_code == 0 and backup_path.exists()
        details["export_state"] = "ok" if checks["export_state_succeeds"] else export_output[-2000:]

        backup_schema_ok = False
        if backup_path.exists():
            try:
                payload = json.loads(backup_path.read_text(encoding="utf-8"))
                backup_schema_ok = all(k in payload for k in ["documents", "events", "grantedPluginPermissions"])
            except Exception:
                backup_schema_ok = False
        checks["backup_schema_valid"] = backup_schema_ok
        details["backup_schema"] = "ok" if backup_schema_ok else "Backup JSON missing expected keys"

        encrypted_before_restore = False
        if state_path.exists():
            try:
                raw = json.loads(state_path.read_text(encoding="utf-8"))
                encrypted_before_restore = raw.get("algorithm") == "AES.GCM"
            except Exception:
                encrypted_before_restore = False
        checks["state_encrypted_before_restore"] = encrypted_before_restore
        details["state_encrypted_before_restore"] = "ok" if encrypted_before_restore else "State file is not encrypted envelope"

        # Simulate local disaster: both encrypted state and key disappear.
        if state_path.exists():
            state_path.unlink()
        if key_path.exists():
            key_path.unlink()

        checks["state_and_key_removed"] = (not state_path.exists()) and (not key_path.exists())
        details["state_and_key_removed"] = "ok" if checks["state_and_key_removed"] else "Unable to remove state/key"

        # Restore from plaintext backup snapshot.
        state_path.write_text(backup_path.read_text(encoding="utf-8"), encoding="utf-8")

        list_after_restore_code, list_after_restore_output = run_cli(
            package_path,
            workdir,
            ["list"],
            timeout_seconds=args.command_timeout_seconds,
        )
        restored_ids = extract_ids(list_after_restore_output)
        checks["restored_state_loads"] = list_after_restore_code == 0 and len(restored_ids) >= 2
        details["list_after_restore"] = "ok" if checks["restored_state_loads"] else list_after_restore_output[-2000:]

        # Any write operation after restore should recreate encryption key and persist encrypted state.
        followup_file = workdir / "post-restore-note.txt"
        followup_file.write_text("Resume\nExperience\nSkills\n", encoding="utf-8")
        followup_import_code, followup_import_output = run_cli(
            package_path,
            workdir,
            ["import", str(followup_file)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["write_after_restore_succeeds"] = followup_import_code == 0
        details["write_after_restore"] = "ok" if checks["write_after_restore_succeeds"] else followup_import_output[-2000:]

        checks["key_recreated_after_restore"] = key_path.exists()
        details["key_recreated_after_restore"] = "ok" if key_path.exists() else "Key file missing after post-restore write"

        encrypted_after_restore = False
        if state_path.exists():
            try:
                raw = json.loads(state_path.read_text(encoding="utf-8"))
                encrypted_after_restore = raw.get("algorithm") == "AES.GCM"
            except Exception:
                encrypted_after_restore = False
        checks["state_reencrypted_after_restore"] = encrypted_after_restore
        details["state_reencrypted_after_restore"] = "ok" if encrypted_after_restore else "State not re-encrypted after post-restore write"

        health_code, health_output = run_cli(
            package_path,
            workdir,
            ["state-health"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["state_health_reports_healthy"] = health_code == 0 and "State health: healthy" in health_output
        details["state_health"] = "ok" if checks["state_health_reports_healthy"] else health_output[-2000:]

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

    print(f"Backup/restore verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
