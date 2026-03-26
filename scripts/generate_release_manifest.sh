#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"

if [[ ! -d "$RELEASE_DIR" ]]; then
    echo "Release directory not found: $RELEASE_DIR"
    echo "Run ./scripts/create_release_artifacts.sh first."
    exit 1
fi

latest_file() {
    local pattern="$1"
    find "$RELEASE_DIR" -maxdepth 1 -type f -name "$pattern" -print | sort | tail -n 1
}

ZIP_PATH="${RELEASE_ZIP_PATH:-$(latest_file 'DocumentOrganizer-*.zip')}"
DMG_PATH="${RELEASE_DMG_PATH:-$(latest_file 'DocumentOrganizer-*.dmg')}"

if [[ -z "$ZIP_PATH" || -z "$DMG_PATH" ]]; then
    echo "Could not locate ZIP/DMG artifacts in $RELEASE_DIR"
    echo "Run ./scripts/create_release_artifacts.sh first."
    exit 1
fi

BASE_NAME="$(basename "$ZIP_PATH" .zip)"
CHECKSUMS_PATH="${RELEASE_CHECKSUM_PATH:-$RELEASE_DIR/${BASE_NAME}-SHA256.txt}"
METADATA_PATH="${RELEASE_METADATA_PATH:-$RELEASE_DIR/${BASE_NAME}-metadata.txt}"

if [[ ! -f "$CHECKSUMS_PATH" ]]; then
  echo "Could not locate checksum file for artifact set: $CHECKSUMS_PATH"
  exit 1
fi

if [[ ! -f "$METADATA_PATH" ]]; then
  echo "Could not locate metadata file for artifact set: $METADATA_PATH"
  exit 1
fi

MANIFEST_JSON="$RELEASE_DIR/${BASE_NAME}-manifest.json"
MANIFEST_MD="$RELEASE_DIR/${BASE_NAME}-manifest.md"
RELEASE_NOTES_MD="$RELEASE_DIR/${BASE_NAME}-release-notes.md"

zip_name="$(basename "$ZIP_PATH")"
dmg_name="$(basename "$DMG_PATH")"
checksum_name="$(basename "$CHECKSUMS_PATH")"
metadata_name="$(basename "$METADATA_PATH")"

zip_size="$(stat -f%z "$ZIP_PATH")"
dmg_size="$(stat -f%z "$DMG_PATH")"

zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

signing_status="$(awk -F': ' '/^Signing Status:/ {print $2}' "$METADATA_PATH" | tail -n 1)"
notarization_status="$(awk -F': ' '/^Notarization Status:/ {print $2}' "$METADATA_PATH" | tail -n 1)"
distribution_ready="$(awk -F': ' '/^Distribution Ready:/ {print $2}' "$METADATA_PATH" | tail -n 1)"

if [[ -z "$signing_status" ]]; then
  signing_status="unknown"
fi

if [[ -z "$notarization_status" ]]; then
  notarization_status="unknown"
fi

if [[ -z "$distribution_ready" ]]; then
  distribution_ready="unknown"
fi

version="$(echo "$BASE_NAME" | sed -E 's/^DocumentOrganizer-([0-9]+\.[0-9]+\.[0-9]+)-.*/\1/')"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf "[1/3] Writing JSON manifest...\n"
cat > "$MANIFEST_JSON" <<EOF
{
  "product": "DocumentOrganizer",
  "version": "$version",
  "generatedAt": "$generated_at",
  "distributionReady": $(if [[ "$distribution_ready" == "yes" ]]; then echo true; else echo false; fi),
  "signingStatus": "$signing_status",
  "notarizationStatus": "$notarization_status",
  "artifacts": [
    {
      "type": "zip",
      "file": "$zip_name",
      "path": "$ZIP_PATH",
      "sizeBytes": $zip_size,
      "sha256": "$zip_sha"
    },
    {
      "type": "dmg",
      "file": "$dmg_name",
      "path": "$DMG_PATH",
      "sizeBytes": $dmg_size,
      "sha256": "$dmg_sha"
    }
  ],
  "checksumsFile": "$checksum_name",
  "metadataFile": "$metadata_name"
}
EOF

printf "[2/3] Writing Markdown manifest...\n"
cat > "$MANIFEST_MD" <<EOF
# DocumentOrganizer Release Manifest

- Product: DocumentOrganizer
- Version: $version
- Generated (UTC): $generated_at
- Distribution Ready: $distribution_ready
- Signing Status: $signing_status
- Notarization Status: $notarization_status

## Artifacts

- ZIP: $zip_name
  - Size: $zip_size bytes
  - SHA-256: $zip_sha
- DMG: $dmg_name
  - Size: $dmg_size bytes
  - SHA-256: $dmg_sha

## Companion Files

- Checksums: $checksum_name
- Metadata: $metadata_name

## Paths

- ZIP: $ZIP_PATH
- DMG: $DMG_PATH
- Checksums: $CHECKSUMS_PATH
- Metadata: $METADATA_PATH
EOF

printf "[3/3] Writing release notes template...\n"
cat > "$RELEASE_NOTES_MD" <<EOF
# DocumentOrganizer v$version

## Highlights

- Added privacy-first document organization features.
- Added menu bar workflows for import, review, and categorization.
- Added macOS packaging, signing, notarization, and release artifact pipelines.

## Downloads

- $zip_name
- $dmg_name

## Integrity (SHA-256)

- ZIP: $zip_sha
- DMG: $dmg_sha

## Notes

- Use the DMG for standard end-user install flows.
- Use the ZIP for automated or CI distribution pipelines.
- Full artifact metadata is available in $metadata_name.
EOF

printf "\nRelease manifest outputs:\n"
printf -- "- %s\n" "$MANIFEST_JSON"
printf -- "- %s\n" "$MANIFEST_MD"
printf -- "- %s\n" "$RELEASE_NOTES_MD"
