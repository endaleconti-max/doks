#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="DocumentOrganizerMacApp"
APP_NAME="DocumentOrganizer.app"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_SOURCE="$ROOT_DIR/macos/DocumentOrganizerMacApp/Info.plist"
ENTITLEMENTS="$ROOT_DIR/macos/DocumentOrganizerMacApp/DocumentOrganizerMacApp.entitlements"
ICON_SOURCE="$ROOT_DIR/macos/DocumentOrganizerMacApp/AppIcon.icns"
ICON_GENERATOR="$ROOT_DIR/scripts/generate_app_icon.sh"
BINARY_SOURCE="$BUILD_DIR/$PRODUCT_NAME"

# Optional signing identity. Default '-' keeps local ad-hoc behavior.
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

printf "[1/7] Building release binary...\n"
(cd "$ROOT_DIR" && swift build -c release --product "$PRODUCT_NAME")

if [[ ! -x "$BINARY_SOURCE" ]]; then
    echo "Release binary not found at: $BINARY_SOURCE"
    exit 1
fi

printf "[2/7] Generating app icon...\n"
"$ICON_GENERATOR" AppIcon "$ICON_SOURCE"

printf "[3/7] Preparing app bundle layout...\n"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

printf "[4/7] Copying binary, plist, and resources...\n"
cp "$BINARY_SOURCE" "$MACOS_DIR/$PRODUCT_NAME"
cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
if [[ -f "$ICON_SOURCE" ]]; then
    cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi

printf "[5/7] Making binary executable...\n"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

printf "[6/7] Codesigning bundle...\n"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "Using ad-hoc signing (-)."
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR"
else
    echo "Using Developer ID signing identity: $SIGNING_IDENTITY"
    codesign --force --deep --timestamp --options runtime --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_DIR"
fi

printf "[7/7] Verifying bundle...\n"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
spctl --assess --type execute --verbose "$APP_DIR" || true

printf "\nBuilt app bundle:\n%s\n" "$APP_DIR"
printf "Open with:\nopen \"%s\"\n" "$APP_DIR"
