#!/usr/bin/env python3
"""Verify data-subject-rights workflows via CLI smoke tests.

This script runs in an isolated temporary workspace and validates:
- Access: list/search visibility after import
- Portability: export-audit and export-state produce readable JSON
- Erasure: delete removes a document and remains removed on subsequent list
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
from typing import Sequence


ID_PATTERN = re.compile(r"^ID:\s+([0-9A-F-]{36})$", re.MULTILINE)


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    output: str


@dataclass
class VerificationReport:
    generatedAt: str
    packagePath: str
    checks: dict[str, bool]
    details: dict[str, str]
    overallPassed: bool


def run_command(cwd: Path, command: Sequence[str]) -> CommandResult:
    return run_command_with_timeout(cwd=cwd, command=command, timeout_seconds=90)


def run_command_with_timeout(cwd: Path, command: Sequence[str], timeout_seconds: int) -> CommandResult:
    try:
        completed = subprocess.run(
            list(command),
            cwd=str(cwd),
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_seconds,
        )
        output = (completed.stdout or "") + (completed.stderr or "")
        return CommandResult(command=list(command), returncode=completed.returncode, output=output)
    except subprocess.TimeoutExpired as exc:
        captured = (exc.stdout or "") + (exc.stderr or "")
        message = f"Command timed out after {timeout_seconds}s: {' '.join(command)}\n{captured}"
        return CommandResult(command=list(command), returncode=124, output=message)


def run_cli(package_path: Path, working_dir: Path, args: Sequence[str], timeout_seconds: int) -> CommandResult:
    built_binary = package_path / ".build" / "debug" / "DocumentOrganizer"
    if built_binary.exists() and built_binary.is_file():
        cmd = [str(built_binary), *args]
    else:
        cmd = ["swift", "run", "--package-path", str(package_path), "DocumentOrganizer", *args]
    return run_command_with_timeout(working_dir, cmd, timeout_seconds=timeout_seconds)


def extract_ids(output: str) -> list[str]:
    return ID_PATTERN.findall(output)


def write_report(report_path: Path, report: VerificationReport) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify data-subject-rights workflows")
    parser.add_argument(
        "--package-path",
        default=".",
        help="Path to the Swift package root",
    )
    parser.add_argument(
        "--output-json",
        default="audit/data-subject-rights-report.json",
        help="Output JSON report path",
    )
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

    with tempfile.TemporaryDirectory(prefix="documentorganizer-rights-") as temp_dir:
        workdir = Path(temp_dir)
        (workdir / "audit").mkdir(parents=True, exist_ok=True)

        sample_invoice = package_path / "samples" / "invoice.txt"
        sample_resume = package_path / "samples" / "resume.txt"
        local_invoice = workdir / "invoice.txt"
        local_resume = workdir / "resume.txt"
        shutil.copy2(sample_invoice, local_invoice)
        shutil.copy2(sample_resume, local_resume)

        import_result = run_cli(
            package_path,
            workdir,
            ["import", str(local_invoice), str(local_resume)],
            timeout_seconds=args.command_timeout_seconds,
        )
        imported_ids = extract_ids(import_result.output)
        checks["import_command_succeeds"] = import_result.returncode == 0 and len(imported_ids) >= 2
        details["import_command"] = "ok" if checks["import_command_succeeds"] else import_result.output[-1500:]

        list_before = run_cli(package_path, workdir, ["list"], timeout_seconds=args.command_timeout_seconds)
        checks["access_list_shows_documents"] = list_before.returncode == 0 and len(extract_ids(list_before.output)) >= 2
        details["list_before_delete"] = "ok" if checks["access_list_shows_documents"] else list_before.output[-1500:]

        search_result = run_cli(
            package_path,
            workdir,
            ["search", "invoice"],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["access_search_returns_match"] = search_result.returncode == 0 and "Found " in search_result.output
        details["search_invoice"] = "ok" if checks["access_search_returns_match"] else search_result.output[-1500:]

        audit_export_path = workdir / "audit" / "timeline-export.json"
        audit_export_result = run_cli(
            package_path,
            workdir,
            ["export-audit", str(audit_export_path)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["portability_audit_export_succeeds"] = audit_export_result.returncode == 0 and audit_export_path.exists()

        state_export_path = workdir / "audit" / "state-export.json"
        state_export_result = run_cli(
            package_path,
            workdir,
            ["export-state", str(state_export_path)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["portability_state_export_succeeds"] = state_export_result.returncode == 0 and state_export_path.exists()

        state_schema_ok = False
        if state_export_path.exists():
            try:
                payload = json.loads(state_export_path.read_text(encoding="utf-8"))
                state_schema_ok = all(k in payload for k in ["documents", "events", "grantedPluginPermissions"])
            except Exception:
                state_schema_ok = False
        checks["portability_state_export_schema_valid"] = state_schema_ok

        delete_target = imported_ids[0] if imported_ids else ""
        delete_result = (
            run_cli(
                package_path,
                workdir,
                ["delete", delete_target],
                timeout_seconds=args.command_timeout_seconds,
            )
            if delete_target
            else CommandResult([], 1, "No document ID available for delete.")
        )
        checks["erasure_delete_command_succeeds"] = delete_result.returncode == 0

        list_after = run_cli(package_path, workdir, ["list"], timeout_seconds=args.command_timeout_seconds)
        ids_after = set(extract_ids(list_after.output))
        checks["erasure_deleted_record_absent"] = bool(delete_target) and delete_target not in ids_after

        # Separate process run (CLI process restarts each call) confirms persisted deletion.
        list_after_restart = run_cli(
            package_path,
            workdir,
            ["list"],
            timeout_seconds=args.command_timeout_seconds,
        )
        ids_after_restart = set(extract_ids(list_after_restart.output))
        checks["erasure_absent_after_restart"] = bool(delete_target) and delete_target not in ids_after_restart

        details["audit_export"] = "ok" if checks["portability_audit_export_succeeds"] else audit_export_result.output[-1500:]
        details["state_export"] = "ok" if checks["portability_state_export_succeeds"] else state_export_result.output[-1500:]
        details["state_export_schema"] = "ok" if checks["portability_state_export_schema_valid"] else "Missing required keys in state export"
        details["delete"] = "ok" if checks["erasure_delete_command_succeeds"] else delete_result.output[-1500:]
        details["list_after_delete"] = "ok" if checks["erasure_deleted_record_absent"] else list_after.output[-1500:]
        details["list_after_restart"] = "ok" if checks["erasure_absent_after_restart"] else list_after_restart.output[-1500:]

    overall = all(checks.values())
    report = VerificationReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        overallPassed=overall,
    )
    write_report(output_path, report)

    print(f"Data-subject-rights verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
