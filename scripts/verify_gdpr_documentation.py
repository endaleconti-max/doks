#!/usr/bin/env python3
"""Verify GDPR documentation completeness across compliance artifacts.

This script validates required sections and key legal references in:
- data-processing-inventory.md
- ropa.md
- legal-basis-mapping.md
- incident-response-runbook.md
"""

from __future__ import annotations

import argparse
import json
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


def contains_all(text: str, required: list[str]) -> tuple[bool, list[str]]:
    missing = [item for item in required if item.lower() not in text.lower()]
    return len(missing) == 0, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify GDPR documentation completeness")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/gdpr-documentation-report.json")
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    docs = {
        "dpi": package_path / "docs" / "compliance" / "data-processing-inventory.md",
        "ropa": package_path / "docs" / "compliance" / "ropa.md",
        "legal_basis": package_path / "docs" / "compliance" / "legal-basis-mapping.md",
        "incident_runbook": package_path / "docs" / "compliance" / "incident-response-runbook.md",
    }

    required_by_doc = {
        "dpi": [
            "GDPR Article 30",
            "Processing Activities",
            "Data Portability Export",
            "Review Date",
        ],
        "ropa": [
            "GDPR Article 30",
            "Controller Information",
            "Data Subject Rights Fulfilment",
            "Review Date",
        ],
        "legal_basis": [
            "GDPR Article 6",
            "Art. 9",
            "Legitimate Interests Assessment",
            "Review Date",
        ],
        "incident_runbook": [
            "GDPR Article 33",
            "Art. 34",
            "72 hours",
            "Response Procedures",
            "Post-Incident Review",
        ],
    }

    for key, path in docs.items():
        exists = path.exists()
        checks[f"{key}_exists"] = exists
        if not exists:
            details[key] = f"Missing file: {path}"
            checks[f"{key}_required_sections_present"] = False
            continue

        text = path.read_text(encoding="utf-8")
        ok, missing = contains_all(text, required_by_doc[key])
        checks[f"{key}_required_sections_present"] = ok
        details[key] = "ok" if ok else f"Missing markers: {', '.join(missing)}"

    # Cross-document consistency checks
    cross_checks = [
        ("retention_policy_referenced", "retention", [docs["dpi"], docs["legal_basis"], docs["ropa"]]),
        ("data_subject_rights_referenced", "data subject rights", [docs["dpi"], docs["ropa"], docs["incident_runbook"]]),
    ]

    for check_name, marker, paths in cross_checks:
        found_in = 0
        for p in paths:
            if p.exists() and marker.lower() in p.read_text(encoding="utf-8").lower():
                found_in += 1
        checks[check_name] = found_in >= 2
        details[check_name] = f"found in {found_in}/{len(paths)} docs"

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

    print(f"GDPR documentation verification: {'PASS' if overall else 'FAIL'}")
    print(f"Report written to: {output_path}")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
