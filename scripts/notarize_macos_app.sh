#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/DocumentOrganizer.app"
ZIP_PATH="$DIST_DIR/DocumentOrganizer.zip"
CREATE_RELEASE_ARTIFACTS="${CREATE_RELEASE_ARTIFACTS:-1}"

# Required for notarization path.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a keychain profile configured with xcrun notarytool store-credentials.}"

if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is required (Xcode command line tools)."
    exit 1
fi

printf "[1/6] Packaging and Developer ID signing app...\n"
SIGNING_IDENTITY="$SIGNING_IDENTITY" "$ROOT_DIR/scripts/package_macos_app.sh"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Expected app bundle not found: $APP_PATH"
    exit 1
fi

printf "[2/6] Creating notarization zip...\n"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

printf "[3/6] Submitting to Apple notarization service...\n"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

printf "[4/6] Stapling ticket to app bundle...\n"
xcrun stapler staple "$APP_PATH"

printf "[5/6] Verifying stapled app...\n"
xcrun stapler validate "$APP_PATH"

printf "[6/6] Final Gatekeeper assessment...\n"
spctl --assess --type execute --verbose "$APP_PATH"

if [[ "$CREATE_RELEASE_ARTIFACTS" == "1" ]]; then
    printf "\nGenerating release artifacts from notarized app...\n"
    "$ROOT_DIR/scripts/create_release_artifacts.sh"
    "$ROOT_DIR/scripts/generate_release_manifest.sh"
fi

printf "\nNotarized app ready:\n%s\n" "$APP_PATH"
printf "Open with:\nopen \"%s\"\n" "$APP_PATH"
