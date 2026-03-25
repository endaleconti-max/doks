#!/usr/bin/env python3
"""Compute quality baseline metrics from executable checks.

This script evaluates:
- functionalTestPassRate
- categorizationQuality
- performanceTargets
- reliabilityTargets

It writes a machine-readable report under audit/ and can be used to update
qualityMetrics in audit/status.json.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ID_PATTERN = re.compile(r"^ID:\s+([0-9A-F-]{36})$", re.MULTILINE)


@dataclass
class CommandResult:
    returncode: int
    output: str
    durationSeconds: float


@dataclass
class QualityBaselineReport:
    generatedAt: str
    packagePath: str
    checks: dict[str, bool]
    details: dict[str, str]
    metrics: dict[str, float]
    overallPassed: bool


def run_command(cwd: Path, command: list[str], timeout_seconds: int) -> CommandResult:
    start = time.perf_counter()
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_seconds,
        )
        duration = time.perf_counter() - start
        output = (completed.stdout or "") + (completed.stderr or "")
        return CommandResult(returncode=completed.returncode, output=output, durationSeconds=duration)
    except subprocess.TimeoutExpired as exc:
        duration = time.perf_counter() - start
        captured = (exc.stdout or "") + (exc.stderr or "")
        msg = f"Command timed out after {timeout_seconds}s: {' '.join(command)}\n{captured}"
        return CommandResult(returncode=124, output=msg, durationSeconds=duration)


def cli_command(package_path: Path) -> list[str]:
    built_binary = package_path / ".build" / "debug" / "DocumentOrganizer"
    if built_binary.exists() and built_binary.is_file():
        return [str(built_binary)]
    return ["swift", "run", "--package-path", str(package_path), "DocumentOrganizer"]


def run_cli(package_path: Path, workdir: Path, args: list[str], timeout_seconds: int) -> CommandResult:
    return run_command(workdir, [*cli_command(package_path), *args], timeout_seconds=timeout_seconds)


def run_python_script(package_path: Path, script_name: str, output_json: Path, timeout_seconds: int) -> CommandResult:
    cmd = [
        sys.executable,
        str(package_path / "scripts" / script_name),
        "--package-path",
        str(package_path),
        "--output-json",
        str(output_json),
    ]
    return run_command(package_path, cmd, timeout_seconds=timeout_seconds)


def extract_ids(output: str) -> list[str]:
    return ID_PATTERN.findall(output)


def extract_category_for_document(output: str, file_name: str) -> str | None:
    # Match a section block starting at Document: <file_name> and read the first Category line.
    pattern = re.compile(
        rf"Document:\s+{re.escape(file_name)}.*?^Category:\s+(\w+)$",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(output)
    return match.group(1).strip() if match else None


def pct(passed: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((passed / total) * 100.0, 2)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify quality baseline metrics")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/quality-baseline-report.json")
    parser.add_argument("--command-timeout-seconds", type=int, default=120)
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    with tempfile.TemporaryDirectory(prefix="documentorganizer-quality-") as temp:
        workdir = Path(temp)
        (workdir / "audit").mkdir(parents=True, exist_ok=True)

        sample_invoice = package_path / "samples" / "invoice.txt"
        sample_resume = package_path / "samples" / "resume.txt"
        local_invoice = workdir / "invoice.txt"
        local_resume = workdir / "resume.txt"
        shutil.copy2(sample_invoice, local_invoice)
        shutil.copy2(sample_resume, local_resume)

        # Functional + categorization baseline
        import_result = run_cli(
            package_path,
            workdir,
            ["import", str(local_invoice), str(local_resume)],
            timeout_seconds=args.command_timeout_seconds,
        )
        imported_ids = extract_ids(import_result.output)
        checks["import_succeeds"] = import_result.returncode == 0 and len(imported_ids) >= 2
        details["import"] = "ok" if checks["import_succeeds"] else import_result.output[-2000:]

        invoice_cat = extract_category_for_document(import_result.output, "invoice.txt")
        resume_cat = extract_category_for_document(import_result.output, "resume.txt")
        checks["invoice_category_expected"] = invoice_cat == "invoice"
        checks["resume_category_expected"] = resume_cat == "resume"
        details["categorization"] = (
            "ok"
            if checks["invoice_category_expected"] and checks["resume_category_expected"]
            else f"invoice={invoice_cat} resume={resume_cat}"
        )

        # Performance checks (very lightweight, broad thresholds)
        list_result = run_cli(package_path, workdir, ["list"], timeout_seconds=args.command_timeout_seconds)
        search_result = run_cli(package_path, workdir, ["search", "invoice"], timeout_seconds=args.command_timeout_seconds)
        state_health_result = run_cli(package_path, workdir, ["state-health"], timeout_seconds=args.command_timeout_seconds)

        checks["import_under_3s"] = import_result.durationSeconds <= 3.0
        checks["list_under_2s"] = list_result.durationSeconds <= 2.0
        checks["search_under_2s"] = search_result.durationSeconds <= 2.0
        checks["state_health_under_2s"] = state_health_result.durationSeconds <= 2.0

        details["performance"] = (
            f"import={import_result.durationSeconds:.2f}s "
            f"list={list_result.durationSeconds:.2f}s "
            f"search={search_result.durationSeconds:.2f}s "
            f"state-health={state_health_result.durationSeconds:.2f}s"
        )

        # Reliability checks
        reliability_runs = []
        for _ in range(5):
            reliability_runs.append(run_cli(package_path, workdir, ["list"], timeout_seconds=args.command_timeout_seconds))
        reliability_successes = [r.returncode == 0 for r in reliability_runs]
        checks["state_health_reports_healthy"] = "State health: healthy" in state_health_result.output
        checks["list_repeated_runs_reliable"] = all(reliability_successes)
        details["reliability"] = (
            f"list_successes={sum(reliability_successes)}/{len(reliability_successes)} "
            f"state_health_ok={checks['state_health_reports_healthy']}"
        )

        # Reuse existing compliance-flow smoke scripts as functional signal inputs.
        rights_report = package_path / "audit" / "data-subject-rights-report.json"
        retention_report = package_path / "audit" / "retention-enforcement-report.json"
        rights_run = run_python_script(package_path, "verify_data_subject_rights.py", rights_report, timeout_seconds=args.command_timeout_seconds)
        retention_run = run_python_script(package_path, "verify_retention_enforcement.py", retention_report, timeout_seconds=args.command_timeout_seconds)
        checks["rights_workflow_script_passes"] = rights_run.returncode == 0
        checks["retention_workflow_script_passes"] = retention_run.returncode == 0
        details["rights_workflow"] = "ok" if checks["rights_workflow_script_passes"] else rights_run.output[-2000:]
        details["retention_workflow"] = "ok" if checks["retention_workflow_script_passes"] else retention_run.output[-2000:]

    functional_keys = [
        "import_succeeds",
        "rights_workflow_script_passes",
        "retention_workflow_script_passes",
    ]
    categorization_keys = ["invoice_category_expected", "resume_category_expected"]
    performance_keys = ["import_under_3s", "list_under_2s", "search_under_2s", "state_health_under_2s"]
    reliability_keys = ["list_repeated_runs_reliable", "state_health_reports_healthy"]

    metrics = {
        "functionalTestPassRate": pct(sum(checks[k] for k in functional_keys), len(functional_keys)),
        "categorizationQuality": pct(sum(checks[k] for k in categorization_keys), len(categorization_keys)),
        "performanceTargets": pct(sum(checks[k] for k in performance_keys), len(performance_keys)),
        "reliabilityTargets": pct(sum(checks[k] for k in reliability_keys), len(reliability_keys)),
    }

    overall = all(checks.values())
    report = QualityBaselineReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        metrics=metrics,
        overallPassed=overall,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")

    print(f"Quality baseline verification: {'PASS' if overall else 'FAIL'}")
    print(f"Metrics: {json.dumps(metrics, sort_keys=True)}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
