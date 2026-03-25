import Core
import Foundation

public struct PlainTextToMarkdownPlugin: ToolPlugin {
    public let identifier = "text-to-markdown"
    public let displayName = "Plain Text to Markdown"
    public let summary = "Converts a plain-text document to Markdown with YAML front-matter and paragraph formatting."
    public let supportedCategories = DocumentCategory.allCases
    public let requiredPermissions: Set<ToolPermission> = [.readDocument, .createDerivedFile]

    public init() {}

    public func canProcess(document: DocumentRecord) -> Bool {
        URL(fileURLWithPath: document.filePath).pathExtension.lowercased() == "txt"
    }

    public func process(document: DocumentRecord, context: ToolExecutionContext) throws -> ToolExecutionResult {
        guard canProcess(document: document) else {
            throw ToolPluginError.unsupportedFileType(document.fileName)
        }

        let sourceURL = URL(fileURLWithPath: document.filePath)
        let rawText = try String(contentsOf: sourceURL, encoding: .utf8)
        let markdownText = convertToMarkdown(text: rawText, sourceName: document.fileName)

        try FileManager.default.createDirectory(
            at: context.outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let timestamp = Self.timestampFormatter.string(from: Date())
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)-\(timestamp).md"
        let outputURL = context.outputDirectory.appendingPathComponent(fileName)

        try markdownText.write(to: outputURL, atomically: true, encoding: .utf8)
        return ToolExecutionResult(
            outputFileURL: outputURL,
            summary: "Converted plain text to Markdown at \(outputURL.path)."
        )
    }

    private func convertToMarkdown(text: String, sourceName: String) -> String {
        let isoDate = Self.isoDateFormatter.string(from: Date())
        let title = sourceName.hasSuffix(".txt")
            ? String(sourceName.dropLast(4)).replacingOccurrences(of: "-", with: " ")
            : sourceName

        var output = """
        ---
        title: \(title)
        date: \(isoDate)
        original-file: \(sourceName)
        ---

        """

        // Split into paragraphs on blank lines, write each as a Markdown paragraph
        let rawParagraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        output += rawParagraphs.joined(separator: "\n\n")
        output += "\n"
        return output
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
