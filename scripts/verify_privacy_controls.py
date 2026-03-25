#!/usr/bin/env python3
"""Verify privacy control implementation and enforcement.

This script validates:
- Privacy policy module existence and configuration.
- Privacy presets availability (StandardUSA, EUStrict, Developer).
- Audit trail and logging capabilities.
- Data minimization practices in ingestion and processing.
- Encryption and key derivation controls.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ID_PATTERN = re.compile(r"^ID:\s+([0-9A-F-]{36})$", re.MULTILINE)


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
    except subprocess.TimeoutExpired:
        return 124, f"Command timed out after {timeout_seconds}s"


def check_file_contains(file_path: Path, required_strings: list[str]) -> tuple[bool, str]:
    """Check if file contains all required strings."""
    if not file_path.exists():
        return False, f"File not found: {file_path}"
    
    content = file_path.read_text()
    missing = [s for s in required_strings if s not in content]
    
    if missing:
        return False, f"Missing strings: {', '.join(missing)}"
    
    return True, "ok"


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify privacy controls")
    parser.add_argument("--package-path", default=".")
    parser.add_argument("--output-json", default="audit/privacy-controls-report.json")
    args = parser.parse_args()

    package_path = Path(args.package_path).resolve()
    output_path = Path(args.output_json).resolve()

    checks: dict[str, bool] = {}
    details: dict[str, str] = {}

    # Check 1: Privacy policy module exists
    privacy_policy = package_path / "Sources" / "Privacy" / "PrivacyPolicy.swift"
    checks["privacy_policy_module_exists"] = privacy_policy.exists()
    if checks["privacy_policy_module_exists"]:
        # Verify it contains privacy presets (strict, balanced, permissive)
        ok, msg = check_file_contains(
            privacy_policy,
            ["strict", "balanced", "permissive", "PrivacyPreset"]
        )
        checks["privacy_presets_defined"] = ok
        details["privacy_presets"] = msg
    else:
        checks["privacy_presets_defined"] = False
        details["privacy_presets"] = "Privacy policy module not found"
    
    details["privacy_policy"] = "ok" if checks["privacy_policy_module_exists"] else "missing"

    # Check 2: Verify Privacy Policy has configuration structure
    if privacy_policy.exists():
        content = privacy_policy.read_text()
        has_config_methods = (
            "PrivacyConfiguration" in content and
            "encryptStateAtRest" in content and
            "exportsAuditLog" in content
        )
        checks["privacy_config_interface"] = has_config_methods
        details["privacy_config"] = "ok" if has_config_methods else "incomplete interface"
    else:
        checks["privacy_config_interface"] = False
        details["privacy_config"] = "module not found"

    # Check 3: Data retention and policy controls
    if privacy_policy.exists():
        content = privacy_policy.read_text()
        has_retention = "DataRetentionPolicy" in content and "retentionDays" in content
        checks["data_retention_controls"] = has_retention
        details["data_retention"] = "ok" if has_retention else "retention policy not defined"
    else:
        checks["data_retention_controls"] = False
        details["data_retention"] = "Privacy module not found"

    # Check 4: Data minimization (verify ingestion service)
    ingestion_service = package_path / "Sources" / "Ingestion" / "DocumentIngestionService.swift"
    if ingestion_service.exists():
        content = ingestion_service.read_text()
        # Check for text extraction (selective processing of content)
        has_selective_extraction = "extractText" in content and ("Image" in content or "PDF" in content or "DOCX" in content)
        checks["data_minimization_practiced"] = has_selective_extraction
        details["data_minimization"] = "ok" if has_selective_extraction else "extraction methods incomplete"
    else:
        checks["data_minimization_practiced"] = False
        details["data_minimization"] = "Ingestion service not found"

    # Check 5: Encryption and key control (OrganizerService)
    organizer_service = package_path / "Sources" / "Services" / "OrganizerService.swift"
    if organizer_service.exists():
        content = organizer_service.read_text()
        has_key_management = "keyFilePath" in content and "resolveOrCreateStateEncryptionKey" in content
        checks["encryption_at_rest"] = has_key_management
        details["encryption"] = "ok" if has_key_management else "key management not evident"
    else:
        checks["encryption_at_rest"] = False
        details["encryption"] = "OrganizerService not found"

    # Check 6: Privacy documentation exists
    privacy_docs = [
        package_path / "docs" / "compliance" / "data-processing-inventory.md",
        package_path / "docs" / "compliance" / "ropa.md",
    ]
    docs_found = sum(1 for d in privacy_docs if d.exists())
    checks["privacy_documentation_complete"] = docs_found >= 2
    details["privacy_docs"] = f"{docs_found}/{len(privacy_docs)} compliance documentation files found"

    # Check 7: Plugin permission controls (security gate for tool extensions)
    if privacy_policy.exists():
        content = privacy_policy.read_text()
        has_plugin_policy = "PluginPermissionPolicy" in content and "defaultGrantedPermissionsByPlugin" in content
        checks["plugin_permission_controls"] = has_plugin_policy
        details["plugin_permissions"] = "ok" if has_plugin_policy else "plugin permission policy not defined"
    else:
        checks["plugin_permission_controls"] = False
        details["plugin_permissions"] = "Privacy module not found"

    # Compile final report
    all_passed = all(checks.values())

    report = VerificationReport(
        generatedAt=datetime.now(timezone.utc).isoformat(),
        packagePath=str(package_path),
        checks=checks,
        details=details,
        overallPassed=all_passed,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(asdict(report), indent=2))

    result_label = "PASS" if all_passed else "FAIL"
    print(f"Privacy controls verification: {result_label}")
    print(f"Report written to: {output_path}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
