#!/usr/bin/env python3
"""Generate a timestamped launch evidence packet.

This script optionally runs the verification suite, refreshes audit scores,
regenerates the launch readiness report, and bundles key artifacts into a
timestamped directory plus zip archive.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class CommandResult:
    name: str
    command: list[str]
    returncode: int
    passed: bool


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Required artifact not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def run_command(command: list[str], cwd: Path, name: str) -> CommandResult:
    completed = subprocess.run(command, cwd=str(cwd), text=True, check=False)
    return CommandResult(
        name=name,
        command=command,
        returncode=completed.returncode,
        passed=completed.returncode == 0,
    )


def copy_artifact(src: Path, dest: Path) -> None:
    if not src.exists():
        raise FileNotFoundError(f"Required artifact not found: {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)


def render_packet_index(
        generated_at: str,
        packet_dir: Path,
        archive_path: Path,
        latest_report: dict,
        full_summary: dict,
) -> str:
        decision = "GO" if bool(full_summary.get("overallPassed", False)) and float(latest_report.get("overallPercent", 0.0)) >= 90.0 else "NO-GO"
        lines = [
                "# Launch Evidence Packet",
                "",
                f"Generated at (UTC): {generated_at}",
                f"Packet directory: `{packet_dir}`",
                f"Packet archive: `{archive_path}`",
                "",
                "## Current Decision Snapshot",
                "",
                f"- Delivery: **{float(latest_report.get('deliveryPercent', 0.0)):.2f}%**",
                f"- Quality: **{float(latest_report.get('qualityPercent', 0.0)):.2f}%**",
                f"- Compliance: **{float(latest_report.get('compliancePercent', 0.0)):.2f}%**",
                f"- Overall: **{float(latest_report.get('overallPercent', 0.0)):.2f}%**",
                f"- Verification suite: **{'PASS' if bool(full_summary.get('overallPassed', False)) else 'FAIL'}**",
                f"- Recommended decision: **{decision}**",
                "",
                "## Included Approval Docs",
                "",
                "- `docs/operations/launch-readiness-report.md`",
                "- `docs/operations/github-setup-signoff.md`",
                "- `docs/operations/release-signoff-record.md`",
                "- `docs/operations/release-signoff-record.prefilled.md`",
                "",
                "## Required Human Actions",
                "",
                "1. Complete GitHub governance checks in `docs/operations/github-setup-signoff.md`.",
                "2. Review `docs/operations/release-signoff-record.prefilled.md` and replace remaining placeholders.",
                "3. Record final GO/NO-GO approvals.",
                "4. Attach this packet archive to the release or change ticket.",
        ]
        return "\n".join(lines) + "\n"


def render_prefilled_release_signoff(
        generated_at: str,
        packet_dir: Path,
        archive_path: Path,
        latest_report: dict,
        full_summary: dict,
) -> str:
        delivery = float(latest_report.get("deliveryPercent", 0.0))
        quality = float(latest_report.get("qualityPercent", 0.0))
        compliance = float(latest_report.get("compliancePercent", 0.0))
        overall = float(latest_report.get("overallPercent", 0.0))
        overall_passed = bool(full_summary.get("overallPassed", False))
        decision = "GO" if overall_passed and overall >= 90.0 else "NO-GO"

        return f"""# Release Signoff Record

Formal approval record for a production launch of DocumentOrganizer.

Use this after generating a fresh launch evidence packet and completing the GitHub governance signoff.

## Release Metadata

- Release version: [fill]
- Release date: {generated_at[:10]}
- Target environment: Production / Staging / Other: [fill]
- Release candidate commit: [hash]
- Evidence packet path: {packet_dir}
- Evidence archive path: {archive_path}

## Required Inputs

Confirm these artifacts exist and are current:

- [x] [docs/operations/launch-readiness-report.md](launch-readiness-report.md)
- [x] [docs/operations/github-setup-signoff.md](github-setup-signoff.md)
- [x] [docs/operations/emergency-merge-procedure.md](emergency-merge-procedure.md)
- [x] [docs/operations/launch-day-checklist.md](launch-day-checklist.md)
- [x] [audit/latest-report.json](../../audit/latest-report.json)
- [x] [audit/full-verification-summary.json](../../audit/full-verification-summary.json)

## Evidence Summary

| Area | Required State | Status | Evidence | Notes |
|---|---|---|---|---|
| Verification suite | 9/9 PASS | {'PASS' if overall_passed else 'FAIL'} | audit/full-verification-summary.json | |
| Delivery score | 100.00% target | {'PASS' if delivery >= 100.0 else 'FAIL'} | audit/latest-report.json | Actual: {delivery:.2f}% |
| Quality score | 100.00% target | {'PASS' if quality >= 100.0 else 'FAIL'} | audit/latest-report.json | Actual: {quality:.2f}% |
| Compliance score | 100.00% target | {'PASS' if compliance >= 100.0 else 'FAIL'} | audit/latest-report.json | Actual: {compliance:.2f}% |
| Launch readiness decision | GO | {'PASS' if decision == 'GO' else 'FAIL'} | docs/operations/launch-readiness-report.md | Current recommendation: {decision} |
| GitHub governance setup | Complete | PASS / FAIL / N-A | docs/operations/github-setup-signoff.md | Human completion required |
| Monitoring dashboards | Operational | PASS / FAIL | [link] | Human confirmation required |
| Rollback plan | Reviewed and tested | PASS / FAIL | docs/operations/launch-day-checklist.md | Human confirmation required |
| Emergency merge path | Documented | PASS | docs/operations/emergency-merge-procedure.md | |

## Risk Review

- Known limitations accepted for release:
    - [item]
    - [item]
- Open low-risk items deferred post-launch:
    - [item]
    - [item]
- Blocking issues remaining: {'NO' if decision == 'GO' else 'YES'}

If blocking issues remain, release decision must be NO-GO.

## Release Decision

- Final decision: [confirm GO / NO-GO] (current recommendation: {decision})
- Decision timestamp: {generated_at}
- Decision rationale:
    - Verification suite is {'fully passing' if overall_passed else 'not fully passing'}.
    - Composite audit score is {overall:.2f}%.

## Approvals

- Deployment owner: [name] / [date] / GO | NO-GO
- Engineering lead: [name] / [date] / GO | NO-GO
- DevOps owner: [name] / [date] / GO | NO-GO
- Compliance owner: [name] / [date] / GO | NO-GO
- Product owner: [name] / [date] / GO | NO-GO

## Post-Decision Actions

If GO:

1. Execute [docs/operations/launch-day-checklist.md](launch-day-checklist.md).
2. Attach evidence archive to release/change ticket.
3. Post launch start notice in incident or release channel.

If NO-GO:

1. Record blockers and owners.
2. Set retry decision meeting.
3. Regenerate evidence packet after fixes.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate launch evidence packet")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-dir", default="audit")
    parser.add_argument(
        "--skip-verify",
        action="store_true",
        help="Skip running scripts/verify_all.py",
    )
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_root = (package_path / args.output_dir).resolve()

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    packet_dir = output_root / f"launch-evidence-{timestamp}"
    packet_dir.mkdir(parents=True, exist_ok=True)
    archive_base = output_root / f"launch-evidence-{timestamp}"
    archive_path = Path(f"{archive_base}.zip")

    commands: list[CommandResult] = []

    if not args.skip_verify:
        commands.append(
            run_command(
                [
                    sys.executable,
                    "scripts/verify_all.py",
                    "--package-path",
                    ".",
                    "--output-json",
                    "audit/full-verification-summary.json",
                ],
                cwd=package_path,
                name="verify_all",
            )
        )

    commands.append(
        run_command(
            [
                sys.executable,
                "scripts/audit_score.py",
                "--input",
                "audit/status.json",
                "--output-json",
                "audit/latest-report.json",
            ],
            cwd=package_path,
            name="audit_score",
        )
    )

    commands.append(
        run_command(
            [sys.executable, "scripts/generate_launch_readiness_report.py"],
            cwd=package_path,
            name="launch_readiness_report",
        )
    )

    failed = [result for result in commands if not result.passed]
    if failed:
        print("One or more commands failed:")
        for result in failed:
            print(f"- {result.name}: return code {result.returncode}")
        return 1

    artifacts = [
        Path("audit/full-verification-summary.json"),
        Path("audit/latest-report.json"),
        Path("audit/status.json"),
        Path("docs/operations/launch-readiness-report.md"),
        Path("docs/operations/github-setup-signoff.md"),
        Path("docs/operations/release-signoff-record.md"),
    ]

    latest_report = load_json(package_path / "audit/latest-report.json")
    full_summary = load_json(package_path / "audit/full-verification-summary.json")

    copied_paths: list[str] = []
    for relative in artifacts:
        source = package_path / relative
        target = packet_dir / relative
        copy_artifact(source, target)
        copied_paths.append(str(relative))

    packet_index_path = packet_dir / "README.md"
    packet_index_path.write_text(
        render_packet_index(
            generated_at=datetime.now(timezone.utc).isoformat(),
            packet_dir=packet_dir,
            archive_path=archive_path,
            latest_report=latest_report,
            full_summary=full_summary,
        ),
        encoding="utf-8",
    )

    prefilled_signoff_path = packet_dir / "docs/operations/release-signoff-record.prefilled.md"
    prefilled_signoff_path.parent.mkdir(parents=True, exist_ok=True)
    prefilled_signoff_path.write_text(
        render_prefilled_release_signoff(
            generated_at=datetime.now(timezone.utc).isoformat(),
            packet_dir=packet_dir,
            archive_path=archive_path,
            latest_report=latest_report,
            full_summary=full_summary,
        ),
        encoding="utf-8",
    )
    copied_paths.append("README.md")
    copied_paths.append("docs/operations/release-signoff-record.prefilled.md")

    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "packetDirectory": str(packet_dir),
        "commands": [asdict(result) for result in commands],
        "artifacts": copied_paths,
    }

    manifest_path = packet_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    archive_path = shutil.make_archive(str(archive_base), "zip", root_dir=packet_dir)

    print(f"Launch evidence packet directory: {packet_dir}")
    print(f"Launch evidence packet archive: {archive_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
