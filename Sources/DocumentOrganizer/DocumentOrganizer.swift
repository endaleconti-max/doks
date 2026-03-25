import Foundation
import PluginKit
import Privacy
import Services
import Core

@main
struct DocumentOrganizer {
    static func main() {
        let rawArguments = Array(CommandLine.arguments.dropFirst())
        guard !rawArguments.isEmpty else {
            printUsage()
            return
        }

        let parseResult = parseGlobalOptions(rawArguments)
        guard parseResult.valid else {
            return
        }

        let arguments = parseResult.remainingArgs
        guard !arguments.isEmpty else {
            printUsage()
            return
        }

        let privacyConfig = resolvePrivacyConfiguration(presetOverride: parseResult.presetOverride)
        let stateURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("audit")
            .appendingPathComponent("organizer-state.json")
        let organizer = OrganizerService(privacy: privacyConfig, stateURL: stateURL)

        print("Processing mode: \(privacyConfig.processingMode)")
        for note in privacyConfig.gdprNotes {
            print("- \(note)")
        }
        if let loadIssue = organizer.stateLoadIssue() {
            print("WARNING: \(loadIssue)")
            print("WARNING: No state-changing operations will be persisted until this is resolved.")
        }

        let command = String(arguments.first ?? "")
        let payload = Array(arguments.dropFirst())

        do {
            switch command.lowercased() {
            case "import":
                try runImport(paths: payload, organizer: organizer)
            case "list":
                runList(organizer: organizer)
            case "search":
                runSearch(queryParts: payload, organizer: organizer)
            case "recategorize":
                try runRecategorize(args: payload, organizer: organizer)
            case "delete":
                try runDelete(args: payload, organizer: organizer)
            case "tools":
                try runTools(args: payload, organizer: organizer)
            case "run-tool":
                try runTool(args: payload, organizer: organizer)
            case "tool-permissions":
                runToolPermissions(organizer: organizer, privacyConfig: privacyConfig)
            case "privacy-preset":
                runPrivacyPreset(privacyConfig)
            case "grant-tool":
                try runGrantTool(args: payload, organizer: organizer)
            case "revoke-tool":
                try runRevokeTool(args: payload, organizer: organizer)
            case "audit":
                runAudit(args: payload, organizer: organizer)
            case "export-audit":
                try runExportAudit(args: payload, organizer: organizer)
            case "export-state":
                try runExportState(args: payload, organizer: organizer)
            case "enforce-retention":
                try runEnforceRetention(organizer: organizer)
            case "state-health":
                runStateHealth(organizer: organizer)
            case "dashboard":
                runDashboard(organizer: organizer)
            default:
                try runImport(paths: arguments, organizer: organizer)
            }
        } catch {
            print("Command failed: \(error.localizedDescription)")
        }
    }

    private static func printUsage() {
        print("Usage:")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] import <file-path> [additional-file-paths]")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] list")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] search <query>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] recategorize <document-id> <category> [reason]")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] delete <document-id>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] tools <document-id>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] run-tool <document-id> <plugin-id>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] tool-permissions")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] privacy-preset")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] grant-tool <plugin-id> <permission> [<permission> ...]")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] revoke-tool <plugin-id> <permission>|all")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] audit [limit]")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] export-audit <output-path>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] export-state <output-path>")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] enforce-retention")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] state-health")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] dashboard")
        print("  swift run DocumentOrganizer [--privacy-preset <strict|balanced|permissive>] <file-path> [additional-file-paths]")
        print("Alternative: set DOCUMENT_ORGANIZER_PRIVACY_PRESET=strict|balanced|permissive")
        print("Categories: \(DocumentCategory.allCases.map(\.rawValue).joined(separator: ", "))")
    }

    private struct GlobalOptionParseResult {
        let presetOverride: PrivacyPreset?
        let remainingArgs: [String]
        let valid: Bool
    }

    private static func parseGlobalOptions(_ args: [String]) -> GlobalOptionParseResult {
        var remaining = args
        var presetOverride: PrivacyPreset?

        while let first = remaining.first, first.hasPrefix("--") {
            if first == "--privacy-preset" {
                guard remaining.count >= 2 else {
                    print("Missing value for --privacy-preset")
                    print("Allowed values: \(PrivacyPreset.allCases.map(\.rawValue).joined(separator: ", "))")
                    return GlobalOptionParseResult(presetOverride: nil, remainingArgs: [], valid: false)
                }

                let rawValue = remaining[1].lowercased()
                guard let preset = PrivacyPreset(rawValue: rawValue) else {
                    print("Unknown privacy preset: \(rawValue)")
                    print("Allowed values: \(PrivacyPreset.allCases.map(\.rawValue).joined(separator: ", "))")
                    return GlobalOptionParseResult(presetOverride: nil, remainingArgs: [], valid: false)
                }

                presetOverride = preset
                remaining.removeFirst(2)
                continue
            }

            if first.hasPrefix("--privacy-preset=") {
                let rawValue = String(first.dropFirst("--privacy-preset=".count)).lowercased()
                guard let preset = PrivacyPreset(rawValue: rawValue) else {
                    print("Unknown privacy preset: \(rawValue)")
                    print("Allowed values: \(PrivacyPreset.allCases.map(\.rawValue).joined(separator: ", "))")
                    return GlobalOptionParseResult(presetOverride: nil, remainingArgs: [], valid: false)
                }

                presetOverride = preset
                remaining.removeFirst()
                continue
            }

            break
        }

        return GlobalOptionParseResult(presetOverride: presetOverride, remainingArgs: remaining, valid: true)
    }

    private static func resolvePrivacyConfiguration(presetOverride: PrivacyPreset?) -> PrivacyConfiguration {
        if let presetOverride {
            return PrivacyConfiguration.preset(presetOverride)
        }

        let environmentPreset = ProcessInfo.processInfo.environment["DOCUMENT_ORGANIZER_PRIVACY_PRESET"]?.lowercased()
        if let environmentPreset, let preset = PrivacyPreset(rawValue: environmentPreset) {
            return PrivacyConfiguration.preset(preset)
        }

        return PrivacyConfiguration.preset(.balanced)
    }

    private static func runPrivacyPreset(_ privacyConfig: PrivacyConfiguration) {
        print("Active privacy preset: \(privacyConfig.presetName)")
        print("Available presets: \(PrivacyPreset.allCases.map(\.rawValue).joined(separator: ", "))")
    }

    private static func runImport(paths: [String], organizer: OrganizerService) throws {
        guard !paths.isEmpty else {
            print("No file paths were provided.")
            printUsage()
            return
        }

        for path in paths {
            do {
                let record = try organizer.processDocument(at: path)
                print("\nDocument: \(record.fileName)")
                print("ID: \(record.id.uuidString)")
                print("Category: \(record.effectiveCategory.rawValue)")
                print("Confidence: \(String(format: "%.2f", record.categoryResult.confidence))")
                print("Why: \(record.categoryResult.explanation)")
            } catch {
                print("\nFailed to process \(path): \(error.localizedDescription)")
            }
        }
    }

    private static func runList(organizer: OrganizerService) {
        let records = organizer.listDocuments()
        guard !records.isEmpty else {
            print("No documents are currently stored.")
            return
        }

        for record in records {
            print("\n\(record.fileName)")
            print("ID: \(record.id.uuidString)")
            print("Category: \(record.effectiveCategory.rawValue)")
            if let correction = record.correction {
                print("Correction: \(correction.previousCategory.rawValue) -> \(correction.newCategory.rawValue)")
            }
            print("Imported: \(record.importedAt)")
        }
    }

    private static func runSearch(queryParts: [String], organizer: OrganizerService) {
        let query = queryParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            print("Search query is required.")
            return
        }

        let results = organizer.searchDocuments(query: query)
        guard !results.isEmpty else {
            print("No matches found for query: \(query)")
            return
        }

        print("Found \(results.count) result(s) for '\(query)':")
        for record in results {
            print("- \(record.id.uuidString) | \(record.fileName) | \(record.effectiveCategory.rawValue)")
        }
    }

    private static func runRecategorize(args: [String], organizer: OrganizerService) throws {
        guard args.count >= 2 else {
            print("Usage: swift run DocumentOrganizer recategorize <document-id> <category> [reason]")
            return
        }

        let id = try organizer.parseDocumentID(args[0])
        let categoryText = args[1].lowercased()
        guard let category = DocumentCategory(rawValue: categoryText) else {
            print("Unknown category '\(categoryText)'.")
            print("Allowed categories: \(DocumentCategory.allCases.map(\.rawValue).joined(separator: ", "))")
            return
        }

        let reason = args.dropFirst(2).joined(separator: " ")
        let finalReason = reason.isEmpty ? "Manual correction" : reason
        let updated = try organizer.recategorize(documentID: id, to: category, reason: finalReason)
        print("Updated \(updated.fileName) to category \(updated.effectiveCategory.rawValue).")
    }

    private static func runDelete(args: [String], organizer: OrganizerService) throws {
        guard let idValue = args.first else {
            print("Usage: swift run DocumentOrganizer delete <document-id>")
            return
        }

        let id = try organizer.parseDocumentID(idValue)
        try organizer.deleteDocument(documentID: id)
        print("Deleted document \(id.uuidString) from organizer state.")
    }

    private static func runTools(args: [String], organizer: OrganizerService) throws {
        guard let idValue = args.first else {
            print("Usage: swift run DocumentOrganizer tools <document-id>")
            return
        }

        let id = try organizer.parseDocumentID(idValue)
        let tools = try organizer.availableTools(documentID: id)
        guard !tools.isEmpty else {
            print("No available tools for this document.")
            return
        }

        print("Available tools:")
        for tool in tools {
            print("- \(tool.identifier) | \(tool.displayName) | \(tool.summary)")
        }
    }

    private static func runTool(args: [String], organizer: OrganizerService) throws {
        guard args.count >= 2 else {
            print("Usage: swift run DocumentOrganizer run-tool <document-id> <plugin-id>")
            return
        }

        let id = try organizer.parseDocumentID(args[0])
        let pluginIdentifier = args[1]
        let result = try organizer.runTool(documentID: id, pluginIdentifier: pluginIdentifier)

        print("Executed tool on \(result.source.fileName): \(pluginIdentifier)")
        print("Derived document: \(result.derived.fileName)")
        print("Derived document ID: \(result.derived.id.uuidString)")
        print("Summary: \(result.summary)")
    }

    private static func runAudit(args: [String], organizer: OrganizerService) {
        let limit = args.first.flatMap(Int.init)
        let events = organizer.auditTimeline(limit: limit)
        guard !events.isEmpty else {
            print("No audit events yet.")
            return
        }

        for event in events {
            let name = event.fileName ?? "n/a"
            let id = event.documentID?.uuidString ?? "n/a"
            print("- [\(event.timestamp)] \(event.eventType.rawValue) | file=\(name) | id=\(id) | actor=\(event.actor)")
            print("  \(event.detail)")
        }
    }

    private static func runExportAudit(args: [String], organizer: OrganizerService) throws {
        guard let path = args.first else {
            print("Usage: swift run DocumentOrganizer export-audit <output-path>")
            return
        }

        let outputURL = URL(fileURLWithPath: path)
        try organizer.saveAuditTimeline(to: outputURL)
        print("Audit timeline exported to \(outputURL.path)")
    }

    private static func runExportState(args: [String], organizer: OrganizerService) throws {
        guard let path = args.first else {
            print("Usage: swift run DocumentOrganizer export-state <output-path>")
            return
        }

        let outputURL = URL(fileURLWithPath: path)
        try organizer.exportState(to: outputURL)
        print("Organizer state exported to \(outputURL.path)")
    }

    private static func runEnforceRetention(organizer: OrganizerService) throws {
        let result = try organizer.enforceRetentionPolicy()
        print("Retention policy enforcement:")
        print("  auto-delete enabled : \(result.autoDeleteEnabled ? "yes" : "no")")
        print("  retention days      : \(result.retentionDays)")
        print("  scanned documents   : \(result.scannedDocuments)")
        print("  deleted documents   : \(result.deletedDocumentIDs.count)")

        if !result.deletedDocumentIDs.isEmpty {
            print("Deleted IDs:")
            for id in result.deletedDocumentIDs {
                print("- \(id.uuidString)")
            }
        }
    }

    private static func runStateHealth(organizer: OrganizerService) {
        let report = organizer.stateHealthReport()
        print("State health: \(report.healthy ? "healthy" : "attention-needed")")
        print("State file: \(report.stateFilePath)")
        print("Key file: \(report.keyFilePath)")
        print("State file exists: \(report.stateFileExists ? "yes" : "no")")
        print("State file encrypted: \(report.stateFileEncrypted ? "yes" : "no")")
        print("Key file exists: \(report.keyFileExists ? "yes" : "no")")
        if let keyLengthBytes = report.keyLengthBytes {
            print("Key length (bytes): \(keyLengthBytes)")
        }
        if let loadIssue = report.loadIssue {
            print("Load issue: \(loadIssue)")
        }

        print("Recommendations:")
        for item in report.recommendations {
            print("- \(item)")
        }
    }

    private static func runToolPermissions(organizer: OrganizerService, privacyConfig: PrivacyConfiguration) {
        let statuses = organizer.pluginPermissionStatus()
        guard !statuses.isEmpty else {
            print("No plugins registered.")
            return
        }

        print("Active privacy preset : \(privacyConfig.presetName)")
        print("Plugin permission status:")
        for status in statuses {
            let grantedList = status.granted.isEmpty ? "none" : status.granted.map(\.rawValue).sorted().joined(separator: ", ")
            let requiredList = status.required.map(\.rawValue).sorted().joined(separator: ", ")
            let fullyGranted = status.required.isSubset(of: status.granted)
            let indicator = fullyGranted ? "[enabled]" : "[needs grant]"
            print("  \(status.plugin.identifier) \(indicator)")
            print("    required : \(requiredList)")
            print("    granted  : \(grantedList)")
        }
    }

    private static func runGrantTool(args: [String], organizer: OrganizerService) throws {
        guard args.count >= 2 else {
            print("Usage: swift run DocumentOrganizer grant-tool <plugin-id> <permission> [<permission> ...]")
            print("Permissions: \(ToolPermission.allCases.map(\.rawValue).joined(separator: ", "))")
            return
        }

        let pluginIdentifier = args[0]
        let rawPermissions = Array(args.dropFirst())
        var permissions = Set<ToolPermission>()
        for raw in rawPermissions {
            guard let perm = ToolPermission(rawValue: raw) else {
                print("Unknown permission: \(raw). Valid values: \(ToolPermission.allCases.map(\.rawValue).joined(separator: ", "))")
                return
            }
            permissions.insert(perm)
        }

        try organizer.grantPermissions(permissions, to: pluginIdentifier)
        print("Granted [\(permissions.map(\.rawValue).sorted().joined(separator: ", "))] to '\(pluginIdentifier)'.")
    }

    private static func runRevokeTool(args: [String], organizer: OrganizerService) throws {
        guard args.count >= 2 else {
            print("Usage: swift run DocumentOrganizer revoke-tool <plugin-id> <permission>|all")
            return
        }

        let pluginIdentifier = args[0]
        let permissionArg = args[1]

        if permissionArg.lowercased() == "all" {
            try organizer.revokeAllPermissions(from: pluginIdentifier)
            print("Revoked all permissions from '\(pluginIdentifier)'.")
        } else {
            guard let permission = ToolPermission(rawValue: permissionArg) else {
                print("Unknown permission: \(permissionArg). Valid values: \(ToolPermission.allCases.map(\.rawValue).joined(separator: ", "))")
                return
            }
            try organizer.revokePermission(permission, from: pluginIdentifier)
            print("Revoked '\(permissionArg)' from '\(pluginIdentifier)'.")
        }
    }

    private static func runDashboard(organizer: OrganizerService) {
        let allRecords = organizer.listDocuments()
        let summary = organizer.categorySummary()

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
        }
        func lpad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
        }

        print("Category Dashboard")
        print(String(repeating: "=", count: 62))
        print("\(pad("Category", 22)) \(lpad("Docs", 5))  \(lpad("Avg Conf", 8))  \(lpad("Last Import", 12))  Corrections")
        print(String(repeating: "-", count: 62))

        for item in summary where item.count > 0 {
            let lastImport = item.lastImportedAt.map { df.string(from: $0) } ?? "—"
            let pct = String(format: "%.0f%%", item.averageConfidence * 100)
            print("\(pad(item.category.rawValue, 22)) \(lpad(String(item.count), 5))  \(lpad(pct, 8))  \(lpad(lastImport, 12))  \(item.correctedCount)")
        }

        print(String(repeating: "-", count: 62))
        print("\(pad("TOTAL", 22)) \(lpad(String(allRecords.count), 5))")
        print("")

        if allRecords.isEmpty {
            print("No documents have been imported yet.")
            return
        }

        let recent = organizer.auditTimeline(limit: 8)
        if !recent.isEmpty {
            print("Recent Activity")
            print(String(repeating: "-", count: 62))
            let tf = DateFormatter()
            tf.dateFormat = "yyyy-MM-dd HH:mm"
            for event in recent {
                let name = event.fileName.map { " | \($0)" } ?? ""
                print("  [\(tf.string(from: event.timestamp))] \(event.eventType.rawValue)\(name)")
            }
        }
    }
}
