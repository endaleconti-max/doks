#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/DocumentOrganizer.app"
PLIST_PATH="$ROOT_DIR/macos/DocumentOrganizerMacApp/Info.plist"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-official}"

if [[ "$RELEASE_CHANNEL" != "official" && "$RELEASE_CHANNEL" != "community" ]]; then
    echo "Invalid RELEASE_CHANNEL: $RELEASE_CHANNEL"
    echo "Use RELEASE_CHANNEL=official or RELEASE_CHANNEL=community"
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "App bundle not found at: $APP_PATH"
    echo "Run ./scripts/package_macos_app.sh first."
    exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil is required on macOS to build DMG artifacts."
    exit 1
fi

APP_VERSION="${APP_VERSION:-}"
if [[ -z "$APP_VERSION" ]]; then
    APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_PATH" 2>/dev/null || echo 1.0.0)"
fi

STAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BASE_NAME="DocumentOrganizer-${APP_VERSION}-${STAMP}"
RELEASE_DIR="$DIST_DIR/release"
ZIP_PATH="$RELEASE_DIR/${BASE_NAME}.zip"
DMG_PATH="$RELEASE_DIR/${BASE_NAME}.dmg"
CHECKSUMS_PATH="$RELEASE_DIR/${BASE_NAME}-SHA256.txt"
METADATA_PATH="$RELEASE_DIR/${BASE_NAME}-metadata.txt"

mkdir -p "$RELEASE_DIR"

printf "[1/6] Creating ZIP artifact...\n"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

printf "[2/6] Creating DMG artifact...\n"
rm -f "$DMG_PATH"
hdiutil create -volname "DocumentOrganizer" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" >/dev/null

printf "[3/6] Generating checksums...\n"
rm -f "$CHECKSUMS_PATH"
shasum -a 256 "$ZIP_PATH" "$DMG_PATH" > "$CHECKSUMS_PATH"

printf "[4/6] Collecting code-signing details...\n"
CODESIGN_SUMMARY="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
SPCTL_SUMMARY="$(spctl --assess --type execute --verbose "$APP_PATH" 2>&1 || true)"
STAPLER_SUMMARY="$(xcrun stapler validate "$APP_PATH" 2>&1 || true)"

SIGNING_STATUS="developer-id"
if grep -q 'Signature=adhoc' <<<"$CODESIGN_SUMMARY"; then
    SIGNING_STATUS="adhoc"
elif grep -q 'TeamIdentifier=not set' <<<"$CODESIGN_SUMMARY"; then
    SIGNING_STATUS="unknown"
fi

NOTARIZATION_STATUS="stapled"
if grep -q 'does not have a ticket stapled to it' <<<"$STAPLER_SUMMARY"; then
    NOTARIZATION_STATUS="unstapled"
elif grep -qi 'error' <<<"$STAPLER_SUMMARY"; then
    NOTARIZATION_STATUS="unknown"
fi

DISTRIBUTION_READY="yes"
if [[ "$SIGNING_STATUS" != "developer-id" || "$NOTARIZATION_STATUS" != "stapled" ]]; then
    DISTRIBUTION_READY="no"
fi

RELEASE_POLICY="official"
if [[ "$RELEASE_CHANNEL" == "community" ]]; then
    RELEASE_POLICY="community-unsigned"
    DISTRIBUTION_READY="yes"
fi

printf "[5/6] Writing metadata report...\n"
cat > "$METADATA_PATH" <<EOF
DocumentOrganizer Release Artifacts
Generated (UTC): $STAMP
Version: $APP_VERSION
Release Channel: $RELEASE_CHANNEL
Release Policy: $RELEASE_POLICY
App Bundle: $APP_PATH
ZIP: $ZIP_PATH
DMG: $DMG_PATH
Signing Status: $SIGNING_STATUS
Notarization Status: $NOTARIZATION_STATUS
Distribution Ready: $DISTRIBUTION_READY

codesign -dv --verbose=4
$CODESIGN_SUMMARY

spctl --assess --type execute --verbose
$SPCTL_SUMMARY

xcrun stapler validate
$STAPLER_SUMMARY
EOF

printf "[6/6] Done.\n\n"
if [[ "$DISTRIBUTION_READY" != "yes" ]]; then
    printf "Warning: artifacts are not distribution-ready (%s signing, %s notarization).\n" "$SIGNING_STATUS" "$NOTARIZATION_STATUS"
fi
if [[ "$RELEASE_CHANNEL" == "community" ]]; then
    printf "Community release mode enabled: unsigned/not-unnotarized artifacts are allowed and must be labeled for trusted testers only.\n"
fi
printf "Release artifacts created in:\n%s\n" "$RELEASE_DIR"
printf -- "- %s\n" "$ZIP_PATH"
printf -- "- %s\n" "$DMG_PATH"
printf -- "- %s\n" "$CHECKSUMS_PATH"
printf -- "- %s\n" "$METADATA_PATH"
