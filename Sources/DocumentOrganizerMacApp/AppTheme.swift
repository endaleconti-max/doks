import AppKit
import SwiftUI

enum AppTheme {
    // Background palette.
    static let vividGreen = Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.88, blue: 0.30, alpha: 1.0))
    static let vividRed = Color(nsColor: NSColor(calibratedRed: 0.95, green: 0.08, blue: 0.18, alpha: 1.0))
    static let metallicBlack = Color(nsColor: NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1.0))

    // Two-color visual system.
    static let vividBlue = Color(nsColor: NSColor(calibratedRed: 0.16, green: 0.37, blue: 1.00, alpha: 1.0))
    static let vividPurple = Color(nsColor: NSColor(calibratedRed: 0.62, green: 0.25, blue: 0.97, alpha: 1.0))

    static let canvasTop = vividGreen
    static let canvasBottom = metallicBlack

    // All UI semantics reuse only vivid blue and vivid purple.
    static let actionAccent = vividBlue
    static let success = vividBlue
    static let warning = vividPurple
    static let danger = vividPurple
    static let info = vividBlue

    static let riskHigh = vividPurple
    static let riskMedium = vividPurple
    static let riskLow = vividBlue
    static let riskMinimal = vividBlue

    static let panelFill = Color(nsColor: NSColor(calibratedRed: 0.90, green: 0.91, blue: 1.00, alpha: 0.92))
    static let panelStroke = vividBlue.opacity(0.28)

    static var canvasGradient: [Color] {
        [canvasTop, vividRed, canvasBottom]
    }
}
