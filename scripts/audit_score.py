#!/usr/bin/env python3
"""Calculate roadmap audit progress from audit/status.json."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean

STATUS_VALUES = {
    "not_started": 0.0,
    "in_progress": 0.5,
    "complete": 1.0,
    "blocked": 0.0,
}


def bounded_percent(value: float) -> float:
    return max(0.0, min(100.0, float(value)))


def phase_completion_percent(phase: dict) -> float:
    milestones = phase.get("milestones", [])
    if not milestones:
        return 0.0

    weighted_sum = 0.0
    for milestone in milestones:
        status = milestone.get("status", "not_started")
        status_value = STATUS_VALUES.get(status)
        if status_value is None:
            raise ValueError(
                f"Unknown status '{status}' in phase '{phase.get('name', 'unknown')}'. "
                "Allowed: not_started, in_progress, complete, blocked"
            )

        weight = float(milestone.get("weight", 0))
        weighted_sum += weight * status_value

    return bounded_percent(weighted_sum)


def average_metric_percent(metric_values: dict) -> float:
    if not metric_values:
        return 0.0
    values = [bounded_percent(v) for v in metric_values.values()]
    return mean(values)


def stage_from_percent(overall: float) -> str:
    if overall < 40:
        return "Discovery/build-up stage"
    if overall < 70:
        return "Execution stage"
    if overall < 90:
        return "Stabilization stage"
    return "Launch-ready stage"


def calculate_scores(data: dict) -> dict:
    phases = data.get("phases", [])

    phase_scores = []
    weighted_delivery_sum = 0.0
    for phase in phases:
        phase_percent = phase_completion_percent(phase)
        roadmap_weight = float(phase.get("roadmapWeight", 0))
        weighted_delivery_sum += phase_percent * roadmap_weight
        phase_scores.append(
            {
                "id": phase.get("id", ""),
                "name": phase.get("name", "Unnamed Phase"),
                "roadmapWeight": roadmap_weight,
                "completionPercent": phase_percent,
            }
        )

    delivery_percent = bounded_percent(weighted_delivery_sum / 100.0)
    quality_percent = average_metric_percent(data.get("qualityMetrics", {}))
    compliance_percent = average_metric_percent(data.get("complianceMetrics", {}))

    weights = data.get("weights", {})
    delivery_weight = float(weights.get("delivery", 0.7))
    quality_weight = float(weights.get("quality", 0.2))
    compliance_weight = float(weights.get("compliance", 0.1))

    overall = bounded_percent(
        (delivery_percent * delivery_weight)
        + (quality_percent * quality_weight)
        + (compliance_percent * compliance_weight)
    )

    return {
        "snapshot": data.get("snapshot", {}),
        "phaseScores": phase_scores,
        "deliveryPercent": round(delivery_percent, 2),
        "qualityPercent": round(quality_percent, 2),
        "compliancePercent": round(compliance_percent, 2),
        "overallPercent": round(overall, 2),
        "stage": stage_from_percent(overall),
    }


def render_text_report(result: dict) -> str:
    lines = []
    snapshot = result.get("snapshot", {})

    lines.append("Documents App Audit Report")
    lines.append("==========================")
    lines.append(f"Date: {snapshot.get('date', 'n/a')}")
    lines.append(f"Version: {snapshot.get('version', 'n/a')}")
    lines.append(f"Auditor: {snapshot.get('auditor', 'n/a')}")
    lines.append("")

    lines.append("Phase Completion")
    lines.append("----------------")
    for phase in result["phaseScores"]:
        lines.append(
            f"- {phase['name']} (weight {phase['roadmapWeight']:.0f}): "
            f"{phase['completionPercent']:.2f}%"
        )

    lines.append("")
    lines.append("Composite Scores")
    lines.append("----------------")
    lines.append(f"Delivery: {result['deliveryPercent']:.2f}%")
    lines.append(f"Quality: {result['qualityPercent']:.2f}%")
    lines.append(f"Compliance: {result['compliancePercent']:.2f}%")
    lines.append(f"Overall: {result['overallPercent']:.2f}%")
    lines.append(f"Stage: {result['stage']}")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Calculate roadmap audit progress percentages"
    )
    parser.add_argument(
        "--input",
        default="audit/status.json",
        help="Path to input audit status JSON",
    )
    parser.add_argument(
        "--output-json",
        default="",
        help="Optional output path for machine-readable result JSON",
    )

    args = parser.parse_args()
    input_path = Path(args.input)
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    data = json.loads(input_path.read_text(encoding="utf-8"))
    result = calculate_scores(data)

    print(render_text_report(result))

    if args.output_json:
        output_path = Path(args.output_json)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
