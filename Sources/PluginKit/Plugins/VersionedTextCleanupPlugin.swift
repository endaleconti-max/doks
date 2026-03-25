import Core
import Foundation

public struct VersionedTextCleanupPlugin: ToolPlugin {
    public let identifier = "versioned-text-cleanup"
    public let displayName = "Versioned Text Cleanup"
    public let summary = "Creates a cleaned copy with normalized whitespace and safe versioned naming."
    public let supportedCategories = DocumentCategory.allCases
    public let requiredPermissions: Set<ToolPermission> = [.readDocument, .createDerivedFile]

    public init() {}

    public func canProcess(document: DocumentRecord) -> Bool {
        let ext = URL(fileURLWithPath: document.filePath).pathExtension.lowercased()
        return ["txt", "md", "csv", "json", "xml", "html"].contains(ext)
    }

    public func process(document: DocumentRecord, context: ToolExecutionContext) throws -> ToolExecutionResult {
        guard canProcess(document: document) else {
            throw ToolPluginError.unsupportedFileType(document.fileName)
        }

        let sourceURL = URL(fileURLWithPath: document.filePath)
        let rawText = try String(contentsOf: sourceURL, encoding: .utf8)
        let cleanedText = normalizeWhitespace(in: rawText)

        try FileManager.default.createDirectory(
            at: context.outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let timestamp = Self.timestampFormatter.string(from: Date())
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let fileName = "\(baseName)-cleaned-\(timestamp).\(ext)"
        let outputURL = context.outputDirectory.appendingPathComponent(fileName)

        try cleanedText.write(to: outputURL, atomically: true, encoding: .utf8)
        return ToolExecutionResult(
            outputFileURL: outputURL,
            summary: "Created cleaned version with normalized whitespace at \(outputURL.path)."
        )
    }

    private func normalizeWhitespace(in text: String) -> String {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        var normalized: [String] = []
        var emptyRun = 0
        for line in lines {
            if line.isEmpty {
                emptyRun += 1
                if emptyRun <= 1 {
                    normalized.append("")
                }
            } else {
                emptyRun = 0
                normalized.append(line)
            }
        }

        return normalized.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
