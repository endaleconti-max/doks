import Core
import Foundation

public enum ToolPermission: String, Codable, Hashable, CaseIterable {
    case readDocument
    case createDerivedFile
}

public struct ToolExecutionContext {
    public let outputDirectory: URL

    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }
}

public struct ToolExecutionResult {
    public let outputFileURL: URL
    public let summary: String

    public init(outputFileURL: URL, summary: String) {
        self.outputFileURL = outputFileURL
        self.summary = summary
    }
}

public enum ToolPluginError: Error, LocalizedError {
    case pluginNotFound(String)
    case permissionDenied(String)
    case unsupportedFileType(String)

    public var errorDescription: String? {
        switch self {
        case .pluginNotFound(let identifier):
            return "Tool plugin not found: \(identifier)"
        case .permissionDenied(let identifier):
            return "Required permissions not granted for plugin: \(identifier)"
        case .unsupportedFileType(let fileName):
            return "Tool plugin does not support this file type: \(fileName)"
        }
    }
}

public protocol ToolPlugin {
    var identifier: String { get }
    var displayName: String { get }
    var summary: String { get }
    var supportedCategories: [DocumentCategory] { get }
    var requiredPermissions: Set<ToolPermission> { get }
    func canProcess(document: DocumentRecord) -> Bool
    func process(document: DocumentRecord, context: ToolExecutionContext) throws -> ToolExecutionResult
}
