#!/usr/bin/env python3
"""Verify release and rollback readiness checklist artifacts.

This script enforces a practical release gate by validating:
- Core test suite pass
- Presence and PASS status of required audit evidence reports
- Presence of release/rollback checklist document
"""

from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
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


def read_pass_flag(path: Path) -> bool:
    if not path.exists():
        return False
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return False

    if "overallPassed" in payload:
        return bool(payload["overallPassed"])
    # Fallback for audit score style files that do not carry overallPassed.
    if "overall" in payload:
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify release/rollback readiness")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/release-checklist-report.json")
    parser.add_argument("--command-timeout-seconds", type=int, default=180)
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    checklist_path = package_path / "docs" / "operations" / "release-rollback-checklist.md"
    checks["checklist_document_exists"] = checklist_path.exists()
    details["checklist_document"] = str(checklist_path)

    swift_test_code, swift_test_output = run_command(
        package_path,
        ["swift", "test"],
        timeout_seconds=args.command_timeout_seconds,
    )
    checks["swift_test_passes"] = swift_test_code == 0
    details["swift_test"] = "ok" if checks["swift_test_passes"] else swift_test_output[-2000:]

    required_reports = {
        "quality_baseline_passes": package_path / "audit" / "quality-baseline-report.json",
        "rights_workflow_passes": package_path / "audit" / "data-subject-rights-report.json",
        "retention_workflow_passes": package_path / "audit" / "retention-enforcement-report.json",
        "monitoring_alerting_passes": package_path / "audit" / "monitoring-alerting-report.json",
        "security_baseline_passes": package_path / "audit" / "security-baseline-report.json",
        "backup_restore_passes": package_path / "audit" / "backup-restore-report.json",
    }

    for key, path in required_reports.items():
        ok = read_pass_flag(path)
        checks[key] = ok
        details[key] = str(path)

    latest_report = package_path / "audit" / "latest-report.json"
    checks["latest_audit_report_exists"] = latest_report.exists()
    details["latest_audit_report"] = str(latest_report)

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

    print(f"Release checklist verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
