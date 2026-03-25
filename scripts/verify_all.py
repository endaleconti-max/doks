#!/usr/bin/env python3
"""Run the full verification suite and emit a consolidated summary.

This wrapper executes all verification scripts in a deterministic order,
collects their pass/fail status, and writes a single JSON summary report.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class ScriptResult:
    name: str
    command: list[str]
    returncode: int
    passed: bool
    outputJson: str
    outputTail: str


@dataclass
class VerificationSummary:
    generatedAt: str
    packagePath: str
    overallPassed: bool
    scripts: list[ScriptResult]


def run_script(package_path: Path, script_name: str, output_json: Path) -> ScriptResult:
    script_path = package_path / "scripts" / script_name
    command = [
        sys.executable,
        str(script_path),
        "--package-path",
        str(package_path),
        "--output-json",
        str(output_json),
    ]

    completed = subprocess.run(
        command,
        cwd=str(package_path),
        text=True,
        capture_output=True,
        check=False,
    )

    combined = (completed.stdout or "") + (completed.stderr or "")
    return ScriptResult(
        name=script_name,
        command=command,
        returncode=completed.returncode,
        passed=completed.returncode == 0,
        outputJson=str(output_json),
        outputTail=combined[-2000:],
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all verification scripts")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/full-verification-summary.json")
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    summary_output = Path(args.output_json).resolve()
    audit_dir = package_path / "audit"
    audit_dir.mkdir(parents=True, exist_ok=True)

    plan: list[tuple[str, str]] = [
        ("verify_data_subject_rights.py", "data-subject-rights-report.json"),
        ("verify_retention_enforcement.py", "retention-enforcement-report.json"),
        ("verify_gdpr_documentation.py", "gdpr-documentation-report.json"),
        ("verify_privacy_controls.py", "privacy-controls-report.json"),
        ("verify_quality_baseline.py", "quality-baseline-report.json"),
        ("verify_security_baseline.py", "security-baseline-report.json"),
        ("verify_backup_restore.py", "backup-restore-report.json"),
        ("verify_monitoring_alerting.py", "monitoring-alerting-report.json"),
        ("verify_release_checklist.py", "release-checklist-report.json"),
    ]

    results: list[ScriptResult] = []
    for script_name, output_name in plan:
        output_json = audit_dir / output_name
        result = run_script(package_path=package_path, script_name=script_name, output_json=output_json)
        results.append(result)

        status = "PASS" if result.passed else "FAIL"
        print(f"[{status}] {script_name}")

    overall_passed = all(result.passed for result in results)

    summary = VerificationSummary(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        overallPassed=overall_passed,
        scripts=results,
    )

    summary_output.parent.mkdir(parents=True, exist_ok=True)
    summary_output.write_text(json.dumps(asdict(summary), indent=2))

    print()
    print(f"Full verification suite: {'PASS' if overall_passed else 'FAIL'}")
    print(f"Summary written to: {summary_output}")

    return 0 if overall_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
