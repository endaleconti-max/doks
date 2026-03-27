#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_NAME="${1:-AppIcon}"
OUTPUT_ICNS="${2:-$ROOT_DIR/macos/DocumentOrganizerMacApp/${ICON_NAME}.icns}"
WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/${ICON_NAME}.iconset"
BASE_PNG="$WORK_DIR/${ICON_NAME}-1024.png"
SWIFT_RENDERER="$WORK_DIR/render_icon.swift"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$SWIFT_RENDERER" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let canvas = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width),
    pixelsHigh: Int(canvas.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
defer { NSGraphicsContext.restoreGraphicsState() }

let bounds = NSRect(origin: .zero, size: canvas)

// Base gradient.
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.84, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.77, alpha: 1.0)
])!
background.draw(in: bounds, angle: 42)

// Soft vignette to add depth.
let vignette = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.20),
    NSColor(calibratedWhite: 0.0, alpha: 0.12)
])!
vignette.draw(in: bounds, relativeCenterPosition: NSPoint(x: -0.3, y: 0.4))

// Rounded tile container.
let tileRect = bounds.insetBy(dx: 140, dy: 140)
let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 150, yRadius: 150)
NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
tilePath.fill()

NSColor(calibratedWhite: 1.0, alpha: 0.28).setStroke()
tilePath.lineWidth = 8
tilePath.stroke()

// Folder shape.
let folderRect = NSRect(x: 220, y: 300, width: 584, height: 380)
let folderPath = NSBezierPath(roundedRect: folderRect, xRadius: 52, yRadius: 52)

let folderGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.35, alpha: 1.0),
    NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.18, alpha: 1.0)
])!
folderGradient.draw(in: folderPath, angle: -90)

NSColor(calibratedRed: 0.74, green: 0.49, blue: 0.10, alpha: 0.55).setStroke()
folderPath.lineWidth = 6
folderPath.stroke()

// Folder tab.
let tabRect = NSRect(x: 260, y: 620, width: 250, height: 96)
let tabPath = NSBezierPath(roundedRect: tabRect, xRadius: 34, yRadius: 34)
NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.46, alpha: 1.0).setFill()
tabPath.fill()

// Document card in folder.
let docRect = NSRect(x: 420, y: 360, width: 250, height: 270)
let docPath = NSBezierPath(roundedRect: docRect, xRadius: 26, yRadius: 26)
NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
docPath.fill()

NSColor(calibratedRed: 0.72, green: 0.83, blue: 0.89, alpha: 1.0).setStroke()
docPath.lineWidth = 5
docPath.stroke()

// Suggest text lines on document.
for index in 0..<4 {
    let lineY = 565 - CGFloat(index) * 42
    let lineRect = NSRect(x: 455, y: lineY, width: 180 - CGFloat(index * 18), height: 14)
    let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 7, yRadius: 7)
    NSColor(calibratedRed: 0.31, green: 0.53, blue: 0.66, alpha: 0.72).setFill()
    linePath.fill()
}

let png = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0])!
try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

swift "$SWIFT_RENDERER" "$BASE_PNG"

mkdir -p "$ICONSET_DIR" "$(dirname "$OUTPUT_ICNS")"

make_icon() {
    local pixels="$1"
    local target="$2"
    sips -s format png -z "$pixels" "$pixels" "$BASE_PNG" --out "$ICONSET_DIR/$target" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "Generated icon: $OUTPUT_ICNS"