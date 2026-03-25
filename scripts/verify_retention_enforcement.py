#!/usr/bin/env python3
"""Verify retention/deletion enforcement using strict privacy preset.

The script seeds a plaintext organizer-state file with one stale and one fresh document,
runs retention enforcement, and validates that only stale records are removed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import uuid
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


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
        command = [
            str(built_binary),
            "--privacy-preset",
            "strict",
            *args,
        ]
    else:
        command = [
            "swift",
            "run",
            "--package-path",
            str(package_path),
            "DocumentOrganizer",
            "--privacy-preset",
            "strict",
            *args,
        ]
    return run_command(workdir, command, timeout_seconds=timeout_seconds)


def build_seed_state(now: datetime) -> dict:
    old_time = (now - timedelta(days=180)).replace(microsecond=0)
    new_time = (now - timedelta(days=10)).replace(microsecond=0)

    stale_id = str(uuid.uuid4()).upper()
    fresh_id = str(uuid.uuid4()).upper()

    return {
        "documents": [
            {
                "id": stale_id,
                "fileName": "old-invoice.txt",
                "filePath": "./old-invoice.txt",
                "contentHash": "hash-old",
                "importedAt": old_time.isoformat().replace("+00:00", "Z"),
                "contentPreview": "old",
                "categoryResult": {
                    "category": "invoice",
                    "confidence": 0.8,
                    "explanation": "seed-old"
                },
                "correction": None,
            },
            {
                "id": fresh_id,
                "fileName": "new-resume.txt",
                "filePath": "./new-resume.txt",
                "contentHash": "hash-new",
                "importedAt": new_time.isoformat().replace("+00:00", "Z"),
                "contentPreview": "new",
                "categoryResult": {
                    "category": "resume",
                    "confidence": 0.9,
                    "explanation": "seed-new"
                },
                "correction": None,
            },
        ],
        "events": [],
        "grantedPluginPermissions": {},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify retention enforcement behavior")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/retention-enforcement-report.json")
    parser.add_argument(
        "--command-timeout-seconds",
        type=int,
        default=90,
        help="Timeout for each CLI command invocation",
    )
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    report_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    with tempfile.TemporaryDirectory(prefix="documentorganizer-retention-") as temp:
        workdir = Path(temp)
        audit_dir = workdir / "audit"
        audit_dir.mkdir(parents=True, exist_ok=True)

        state_path = audit_dir / "organizer-state.json"
        state_path.write_text(json.dumps(build_seed_state(datetime.now(timezone.utc))), encoding="utf-8")

        list_before_code, list_before_output = run_cli(
            package_path,
            workdir,
            ["list"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["seed_state_loads"] = list_before_code == 0 and "old-invoice.txt" in list_before_output and "new-resume.txt" in list_before_output
        details["list_before"] = "ok" if checks["seed_state_loads"] else list_before_output[-1500:]

        enforce_code, enforce_output = run_cli(
            package_path,
            workdir,
            ["enforce-retention"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["enforcement_command_succeeds"] = enforce_code == 0
        checks["enforcement_reports_one_delete"] = "deleted documents   : 1" in enforce_output
        details["enforce_retention"] = "ok" if checks["enforcement_command_succeeds"] and checks["enforcement_reports_one_delete"] else enforce_output[-1500:]

        list_after_code, list_after_output = run_cli(
            package_path,
            workdir,
            ["list"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["stale_document_removed"] = list_after_code == 0 and "old-invoice.txt" not in list_after_output
        checks["fresh_document_kept"] = list_after_code == 0 and "new-resume.txt" in list_after_output
        details["list_after"] = "ok" if checks["stale_document_removed"] and checks["fresh_document_kept"] else list_after_output[-1500:]

        audit_code, audit_output = run_cli(
            package_path,
            workdir,
            ["audit", "10"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["deletion_audit_event_recorded"] = audit_code == 0 and "removed by retention policy" in audit_output
        details["audit_after"] = "ok" if checks["deletion_audit_event_recorded"] else audit_output[-1500:]

    overall = all(checks.values())
    report = VerificationReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        overallPassed=overall,
    )

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")

    print(f"Retention enforcement verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {report_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
