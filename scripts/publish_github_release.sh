#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"

if [[ ! -d "$RELEASE_DIR" ]]; then
    echo "Release directory not found: $RELEASE_DIR"
    echo "Run ./scripts/create_release_artifacts.sh and ./scripts/generate_release_manifest.sh first."
    exit 1
fi

latest_file() {
    local pattern="$1"
    find "$RELEASE_DIR" -maxdepth 1 -type f -name "$pattern" -print | sort | tail -n 1
}

MANIFEST_PATH="${RELEASE_MANIFEST_PATH:-$(latest_file 'DocumentOrganizer-*-manifest.json')}"
if [[ -z "$MANIFEST_PATH" || ! -f "$MANIFEST_PATH" ]]; then
    echo "Could not locate a manifest file in $RELEASE_DIR"
    echo "Run ./scripts/generate_release_manifest.sh first."
    exit 1
fi

MANIFEST_OUTPUT="$(/usr/bin/python3 - "$MANIFEST_PATH" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
obj = json.loads(manifest_path.read_text())
version = obj.get("version", "0.0.0")
distribution_ready = obj.get("distributionReady", False)
signing_status = obj.get("signingStatus", "unknown")
notarization_status = obj.get("notarizationStatus", "unknown")
files = [a.get("path", "") for a in obj.get("artifacts", []) if a.get("path")]
print(version)
print("true" if distribution_ready else "false")
print(signing_status)
print(notarization_status)
print("\n".join(files))
PY
 )"

if [[ -z "$MANIFEST_OUTPUT" ]]; then
    echo "Manifest parser returned empty output: $MANIFEST_PATH"
    exit 1
fi

VERSION="$(printf "%s\n" "$MANIFEST_OUTPUT" | sed -n '1p')"
DISTRIBUTION_READY="$(printf "%s\n" "$MANIFEST_OUTPUT" | sed -n '2p')"
SIGNING_STATUS="$(printf "%s\n" "$MANIFEST_OUTPUT" | sed -n '3p')"
NOTARIZATION_STATUS="$(printf "%s\n" "$MANIFEST_OUTPUT" | sed -n '4p')"
ARTIFACTS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && ARTIFACTS+=("$line")
done <<EOF
$(printf "%s\n" "$MANIFEST_OUTPUT" | tail -n +5)
EOF

if [[ ${#ARTIFACTS[@]} -lt 1 ]]; then
    echo "Manifest did not include artifact paths: $MANIFEST_PATH"
    exit 1
fi

for artifact in "${ARTIFACTS[@]}"; do
    if [[ ! -f "$artifact" ]]; then
        echo "Artifact missing: $artifact"
        exit 1
    fi
done

TAG="${RELEASE_TAG:-v$VERSION}"
TITLE="${RELEASE_TITLE:-DocumentOrganizer $VERSION}"
NOTES_PATH="${RELEASE_NOTES_PATH:-${MANIFEST_PATH%-manifest.json}-release-notes.md}"
DRY_RUN="${DRY_RUN:-1}"
ALLOW_UNSIGNED_RELEASE="${ALLOW_UNSIGNED_RELEASE:-0}"

if [[ ! -f "$NOTES_PATH" ]]; then
    echo "Release notes file not found: $NOTES_PATH"
    exit 1
fi

if [[ "$DISTRIBUTION_READY" != "true" && "$ALLOW_UNSIGNED_RELEASE" != "1" ]]; then
    echo "Refusing to publish non-distribution-ready artifacts."
    echo "Signing status: $SIGNING_STATUS"
    echo "Notarization status: $NOTARIZATION_STATUS"
    echo "If you intend to bypass this safeguard, set ALLOW_UNSIGNED_RELEASE=1 explicitly."
    exit 1
fi

if [[ "$DRY_RUN" != "1" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "GitHub CLI (gh) is required when DRY_RUN=0"
        exit 1
    fi
fi

create_cmd=(gh release create "$TAG")
for artifact in "${ARTIFACTS[@]}"; do
    create_cmd+=("$artifact")
done
create_cmd+=("--title" "$TITLE" "--notes-file" "$NOTES_PATH")

upload_cmd=(gh release upload "$TAG" "--clobber")
for artifact in "${ARTIFACTS[@]}"; do
    upload_cmd+=("$artifact")
done

printf "Release publish plan\n"
printf -- "- Manifest: %s\n" "$MANIFEST_PATH"
printf -- "- Tag: %s\n" "$TAG"
printf -- "- Title: %s\n" "$TITLE"
printf -- "- Notes: %s\n" "$NOTES_PATH"
printf -- "- Distribution ready: %s\n" "$DISTRIBUTION_READY"
printf -- "- Signing status: %s\n" "$SIGNING_STATUS"
printf -- "- Notarization status: %s\n" "$NOTARIZATION_STATUS"
printf -- "- Artifacts:\n"
for artifact in "${ARTIFACTS[@]}"; do
    printf "  - %s\n" "$artifact"
done

if [[ "$DRY_RUN" == "1" ]]; then
    printf "\nDRY_RUN=1. Commands that would run:\n"
    printf ""
    printf -- "- "
    printf '%q ' "${create_cmd[@]}"
    printf "\n"
    printf -- "- "
    printf '%q ' "${upload_cmd[@]}"
    printf "\n"
    exit 0
fi

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "Release $TAG already exists. Uploading artifacts with clobber."
    "${upload_cmd[@]}"
else
    echo "Creating new release $TAG."
    "${create_cmd[@]}"
fi

echo "Release publish completed for $TAG"
