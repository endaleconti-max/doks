#!/usr/bin/env python3
"""Verify monitoring and alerting behavior via state-health diagnostics.

This script validates:
- Healthy baseline state emits healthy signal within latency target.
- Corrupted state payload produces unhealthy state signal.
- Alert rules trigger on unhealthy state and recovery is detectable.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class CommandResult:
    returncode: int
    output: str
    duration_seconds: float


@dataclass
class VerificationReport:
    generatedAt: str
    packagePath: str
    checks: dict[str, bool]
    details: dict[str, str]
    alerts: list[str]
    overallPassed: bool


def run_command(cwd: Path, command: list[str], timeout_seconds: int) -> CommandResult:
    started = time.perf_counter()
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_seconds,
        )
        elapsed = time.perf_counter() - started
        output = (completed.stdout or "") + (completed.stderr or "")
        return CommandResult(returncode=completed.returncode, output=output, duration_seconds=elapsed)
    except subprocess.TimeoutExpired as exc:
        elapsed = time.perf_counter() - started
        def _as_text(value: object) -> str:
            if value is None:
                return ""
            if isinstance(value, str):
                return value
            if isinstance(value, memoryview):
                return value.tobytes().decode("utf-8", errors="replace")
            if isinstance(value, (bytes, bytearray)):
                return bytes(value).decode("utf-8", errors="replace")
            return str(value)

        stdout = _as_text(exc.stdout)
        stderr = _as_text(exc.stderr)
        captured = stdout + stderr
        msg = f"Command timed out after {timeout_seconds}s: {' '.join(command)}\n{captured}"
        return CommandResult(returncode=124, output=msg, duration_seconds=elapsed)


def run_cli(package_path: Path, workdir: Path, args: list[str], timeout_seconds: int) -> CommandResult:
    built_binary = package_path / ".build" / "debug" / "DocumentOrganizer"
    if built_binary.exists() and built_binary.is_file():
        command = [str(built_binary), *args]
    else:
        command = ["swift", "run", "--package-path", str(package_path), "DocumentOrganizer", *args]

    return run_command(workdir, command, timeout_seconds=timeout_seconds)


def alert_rules(result: CommandResult) -> list[str]:
    alerts: list[str] = []
    output_lower = result.output.lower()
    if "state health: attention-needed" in output_lower:
        alerts.append("ALERT_STATE_HEALTH_ATTENTION")
    if "load issue:" in output_lower:
        alerts.append("ALERT_STATE_LOAD_ISSUE")
    if result.duration_seconds > 2.0:
        alerts.append("ALERT_STATE_HEALTH_LATENCY")
    return alerts


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify monitoring and alerting behavior")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/monitoring-alerting-report.json")
    parser.add_argument("--command-timeout-seconds", type=int, default=90)
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}
    alerts: list[str] = []

    with tempfile.TemporaryDirectory(prefix="documentorganizer-monitoring-") as temp_dir:
        workdir = Path(temp_dir)
        audit_dir = workdir / "audit"
        audit_dir.mkdir(parents=True, exist_ok=True)

        sample_invoice = package_path / "samples" / "invoice.txt"
        local_invoice = workdir / "invoice.txt"
        shutil.copy2(sample_invoice, local_invoice)

        # Seed state so encrypted key/state exists.
        import_result = run_cli(
            package_path,
            workdir,
            ["import", str(local_invoice)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["seed_import_succeeds"] = import_result.returncode == 0
        details["seed_import"] = "ok" if checks["seed_import_succeeds"] else import_result.output[-2000:]

        baseline_health = run_cli(
            package_path,
            workdir,
            ["state-health"],
            timeout_seconds=args.command_timeout_seconds,
        )
        baseline_alerts = alert_rules(baseline_health)
        checks["state_health_baseline_healthy"] = "State health: healthy" in baseline_health.output
        checks["state_health_baseline_under_2s"] = baseline_health.duration_seconds <= 2.0
        checks["no_alerts_in_healthy_baseline"] = len(baseline_alerts) == 0
        details["baseline_state_health"] = (
            f"ok (duration={baseline_health.duration_seconds:.3f}s)"
            if checks["state_health_baseline_healthy"] and checks["state_health_baseline_under_2s"]
            else baseline_health.output[-2000:]
        )

        # Corrupt persisted state payload and ensure monitoring detects unhealthy state.
        state_path = audit_dir / "organizer-state.json"
        if state_path.exists():
            state_path.write_text("{\n  \"algorithm\": \"AES.GCM\",\n  \"combinedCiphertext\": \"not-base64\"\n}\n", encoding="utf-8")

        degraded_health = run_cli(
            package_path,
            workdir,
            ["state-health"],
            timeout_seconds=args.command_timeout_seconds,
        )
        degraded_alerts = alert_rules(degraded_health)
        alerts.extend(degraded_alerts)

        checks["state_health_detects_corruption"] = "State health: attention-needed" in degraded_health.output
        checks["alert_raised_for_unhealthy_state"] = any(a.startswith("ALERT_STATE_HEALTH") for a in degraded_alerts)
        checks["alert_raised_for_load_issue"] = "ALERT_STATE_LOAD_ISSUE" in degraded_alerts
        details["degraded_state_health"] = (
            "ok" if checks["state_health_detects_corruption"] and checks["alert_raised_for_load_issue"]
            else degraded_health.output[-2000:]
        )

        # Recovery playbook: reset corrupted state and re-seed from source docs.
        if state_path.exists():
            state_path.unlink()

        reimport_result = run_cli(
            package_path,
            workdir,
            ["import", str(local_invoice)],
            timeout_seconds=args.command_timeout_seconds,
        )
        checks["recovery_reimport_succeeds"] = reimport_result.returncode == 0
        details["recovery_reimport"] = "ok" if checks["recovery_reimport_succeeds"] else reimport_result.output[-2000:]

        recovered_health = run_cli(
            package_path,
            workdir,
            ["state-health"],
            timeout_seconds=args.command_timeout_seconds,
        )
        recovery_alerts = alert_rules(recovered_health)
        checks["state_health_recovers_after_fix"] = "State health: healthy" in recovered_health.output
        checks["alerts_clear_after_fix"] = len(recovery_alerts) == 0
        details["recovered_state_health"] = (
            "ok" if checks["state_health_recovers_after_fix"] and checks["alerts_clear_after_fix"]
            else recovered_health.output[-2000:]
        )

    overall = all(checks.values())
    report = VerificationReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        alerts=sorted(set(alerts)),
        overallPassed=overall,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")

    print(f"Monitoring/alerting verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
