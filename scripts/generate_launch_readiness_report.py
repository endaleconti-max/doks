#!/usr/bin/env python3
"""Generate a launch-readiness markdown report from audit artifacts."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def checkmark(value: bool) -> str:
    return "PASS" if value else "FAIL"


def build_markdown(
    generated_at: str,
    latest_report: dict,
    full_summary: dict,
    output_json_path: Path,
) -> str:
    delivery = float(latest_report.get("deliveryPercent", 0.0))
    quality = float(latest_report.get("qualityPercent", 0.0))
    compliance = float(latest_report.get("compliancePercent", 0.0))
    overall = float(latest_report.get("overallPercent", 0.0))
    stage = str(latest_report.get("stage", "unknown"))

    scripts = full_summary.get("scripts", [])
    overall_passed = bool(full_summary.get("overallPassed", False))

    lines: list[str] = []
    lines.append("# Launch Readiness Report")
    lines.append("")
    lines.append(f"Generated at (UTC): {generated_at}")
    lines.append(f"Summary source: `{output_json_path.as_posix()}`")
    lines.append("")
    lines.append("## Composite Audit Scores")
    lines.append("")
    lines.append(f"- Delivery: **{delivery:.2f}%**")
    lines.append(f"- Quality: **{quality:.2f}%**")
    lines.append(f"- Compliance: **{compliance:.2f}%**")
    lines.append(f"- Overall: **{overall:.2f}%**")
    lines.append(f"- Stage: **{stage}**")
    lines.append("")
    lines.append("## Verification Suite")
    lines.append("")
    lines.append(f"Overall verification result: **{checkmark(overall_passed)}**")
    lines.append("")
    lines.append("| Script | Result | Output Report |")
    lines.append("|---|---|---|")
    for script in scripts:
        script_name = str(script.get("name", "unknown"))
        passed = bool(script.get("passed", False))
        output_json = str(script.get("outputJson", "n/a"))
        lines.append(f"| `{script_name}` | **{checkmark(passed)}** | `{output_json}` |")

    lines.append("")
    lines.append("## Launch Decision")
    lines.append("")
    decision = "GO" if overall_passed and overall >= 90.0 else "NO-GO"
    lines.append(f"- Recommended decision: **{decision}**")
    lines.append(
        "- Rule: GO only when full verification is PASS and overall audit score is at least 90.00%."
    )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append(
        "- Manual GitHub branch protection remains a required human step (see docs/operations/github-setup-checklist.md)."
    )
    lines.append(
        "- Use docs/operations/launch-day-checklist.md for execution timeline and go/no-go sign-off."
    )

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate launch-readiness markdown report")
    parser.add_argument("--latest-report", default="audit/latest-report.json")
    parser.add_argument("--full-summary", default="audit/full-verification-summary.json")
    parser.add_argument(
        "--output-markdown",
        default="docs/operations/launch-readiness-report.md",
    )
    args = parser.parse_args()

    latest_report_path = Path(args.latest_report).resolve()
    full_summary_path = Path(args.full_summary).resolve()
    output_markdown_path = Path(args.output_markdown).resolve()

    latest_report = load_json(latest_report_path)
    full_summary = load_json(full_summary_path)

    generated_at = datetime.now(timezone.utc).isoformat()
    markdown = build_markdown(
        generated_at=generated_at,
        latest_report=latest_report,
        full_summary=full_summary,
        output_json_path=full_summary_path,
    )

    output_markdown_path.parent.mkdir(parents=True, exist_ok=True)
    output_markdown_path.write_text(markdown, encoding="utf-8")

    print(f"Launch readiness report written to: {output_markdown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
