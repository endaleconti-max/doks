import Categorization
import CryptoKit
import Core
import Foundation
import Ingestion
import PluginKit
import Privacy
#if canImport(Security)
import Security
#endif

public enum OrganizerError: Error, LocalizedError {
    case fileMissing(String)
    case invalidDocumentID(String)
    case documentNotFound(UUID)
    case persistenceFailure(String)
    case pluginOutputDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .fileMissing(let path):
            return "File not found at path: \(path)"
        case .invalidDocumentID(let value):
            return "Invalid document id: \(value)"
        case .documentNotFound(let id):
            return "No document found for id: \(id.uuidString)"
        case .persistenceFailure(let message):
            return "State persistence error: \(message)"
        case .pluginOutputDirectoryUnavailable:
            return "Unable to resolve plugin output directory."
        }
    }
}

private struct OrganizerState: Codable {
    var documents: [DocumentRecord]
    var events: [AuditEvent]
    /// Serialized as [pluginIdentifier: [permissionRawValue]].
    var grantedPluginPermissions: [String: [String]]?
}

private struct EncryptedOrganizerState: Codable {
    var version: Int
    var algorithm: String
    var combinedCiphertext: String
}

public struct StateHealthReport {
    public let stateFilePath: String
    public let keyFilePath: String
    public let keyStorage: String
    public let keyAvailable: Bool
    public let stateFileExists: Bool
    public let keyFileExists: Bool
    public let keyLengthBytes: Int?
    public let stateFileEncrypted: Bool
    public let loadIssue: String?
    public let recommendations: [String]

    public var healthy: Bool {
        loadIssue == nil && (!stateFileEncrypted || keyAvailable)
    }
}

public struct RetentionEnforcementResult {
    public let autoDeleteEnabled: Bool
    public let retentionDays: Int
    public let scannedDocuments: Int
    public let deletedDocumentIDs: [UUID]
}

public struct CategorySummaryItem {
    public let category: DocumentCategory
    public let count: Int
    public let averageConfidence: Double
    public let lastImportedAt: Date?
    public let correctedCount: Int
}

public final class OrganizerService {
    private let ingestion: DocumentIngestionProviding
    private let categorizer: CategoryEngineProviding
    private let privacy: PrivacyConfiguration
    private let toolRegistry: ToolRegistry
    private let stateURL: URL?
    private let stateKeyURL: URL?
    private var documentsByID: [UUID: DocumentRecord] = [:]
    private var auditEvents: [AuditEvent] = []
    private var stateLoadError: String?
    private var migratedLegacyKeyFileToKeychain = false

    private static let keychainServiceName = "com.documentorganizer.statekey.v1"

    public init(
        ingestion: DocumentIngestionProviding = DocumentIngestionService(),
        categorizer: CategoryEngineProviding = KeywordCategoryEngine(),
        privacy: PrivacyConfiguration = PrivacyConfiguration(),
        toolRegistry: ToolRegistry = .defaultRegistry(),
        stateURL: URL? = nil
    ) {
        self.ingestion = ingestion
        self.categorizer = categorizer
        self.privacy = privacy
        self.toolRegistry = toolRegistry
        self.stateURL = stateURL
        self.stateKeyURL = stateURL?.deletingLastPathComponent().appendingPathComponent("organizer-state.key")

        applyDefaultPluginPermissionsFromPrivacy()

        if let stateURL {
            loadState(from: stateURL)
        }
    }

    private func applyDefaultPluginPermissionsFromPrivacy() {
        let defaults = privacy.pluginPermissionPolicy.defaultGrantedPermissionsByPlugin
        for (pluginIdentifier, rawValues) in defaults {
            let permissions = Set(rawValues.compactMap(ToolPermission.init(rawValue:)))
            guard !permissions.isEmpty else {
                continue
            }
            toolRegistry.grantPermissions(permissions, for: pluginIdentifier)
        }
    }

    public func processDocument(at path: String) throws -> DocumentRecord {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw OrganizerError.fileMissing(path)
        }

        let text = try ingestion.extractText(from: url)
        let contentHash = hash(text)

        if let existing = findDuplicateDocument(contentHash: contentHash) {
            appendAuditEvent(
                .imported,
                documentID: existing.id,
                fileName: existing.fileName,
                actor: "system",
                detail: "Duplicate import skipped for matching content hash."
            )
            try persistStateIfNeeded()
            return existing
        }

        let learnedCorrections = documentsByID.values.compactMap(\.correction)
        let category = categorizer.classify(text: text, learnedCorrections: learnedCorrections)

        let preview = String(text.prefix(220))
        let record = DocumentRecord(
            fileName: url.lastPathComponent,
            filePath: path,
            contentHash: contentHash,
            contentPreview: privacy.storesRawContent ? preview : "Stored preview disabled by privacy policy.",
            categoryResult: category
        )

        documentsByID[record.id] = record
        appendAuditEvent(
            .imported,
            documentID: record.id,
            fileName: record.fileName,
            actor: "system",
            detail: "Document imported with category \(record.effectiveCategory.rawValue)."
        )
        try persistStateIfNeeded()

        return record
    }

    public func listDocuments() -> [DocumentRecord] {
        documentsByID.values.sorted { $0.importedAt > $1.importedAt }
    }

    public func searchDocuments(query: String) -> [DocumentRecord] {
        let normalized = query.lowercased()
        return listDocuments().filter { record in
            record.fileName.lowercased().contains(normalized)
                || record.contentPreview.lowercased().contains(normalized)
                || record.effectiveCategory.rawValue.lowercased().contains(normalized)
        }
    }

    public func categorySummary() -> [CategorySummaryItem] {
        var groups: [DocumentCategory: [DocumentRecord]] = [:]
        for record in documentsByID.values {
            groups[record.effectiveCategory, default: []].append(record)
        }
        return DocumentCategory.allCases.map { category in
            let docs = groups[category] ?? []
            let avgConfidence = docs.isEmpty ? 0.0
                : docs.map(\.categoryResult.confidence).reduce(0, +) / Double(docs.count)
            let lastImport = docs.map(\.importedAt).max()
            let corrected = docs.filter { $0.correction != nil }.count
            return CategorySummaryItem(
                category: category,
                count: docs.count,
                averageConfidence: avgConfidence,
                lastImportedAt: lastImport,
                correctedCount: corrected
            )
        }
    }

    public func availableTools(documentID: UUID) throws -> [any ToolPlugin] {
        guard let document = documentsByID[documentID] else {
            throw OrganizerError.documentNotFound(documentID)
        }

        return toolRegistry.availableTools(for: document)
    }

    @discardableResult
    public func runTool(
        documentID: UUID,
        pluginIdentifier: String,
        actor: String = "user"
    ) throws -> (source: DocumentRecord, derived: DocumentRecord, summary: String) {
        guard let sourceDocument = documentsByID[documentID] else {
            throw OrganizerError.documentNotFound(documentID)
        }

        guard let plugin = toolRegistry.plugin(identifier: pluginIdentifier) else {
            throw ToolPluginError.pluginNotFound(pluginIdentifier)
        }

        guard toolRegistry.permissionsGranted(for: plugin) else {
            throw ToolPluginError.permissionDenied(pluginIdentifier)
        }

        guard plugin.canProcess(document: sourceDocument) else {
            throw ToolPluginError.unsupportedFileType(sourceDocument.fileName)
        }

        let outputDirectory = try pluginOutputDirectory(for: sourceDocument)
        let result = try plugin.process(
            document: sourceDocument,
            context: ToolExecutionContext(outputDirectory: outputDirectory)
        )
        let derivedRecord = try processDocument(at: result.outputFileURL.path)

        appendAuditEvent(
            .toolExecuted,
            documentID: sourceDocument.id,
            fileName: sourceDocument.fileName,
            actor: actor,
            detail: "Executed tool '\(plugin.displayName)' and created '\(derivedRecord.fileName)'. \(result.summary)"
        )
        try persistStateIfNeeded()

        return (sourceDocument, derivedRecord, result.summary)
    }

    // MARK: - Plugin permission management

    /// Returns the granted permissions for every registered plugin.
    public func pluginPermissionStatus() -> [(plugin: any ToolPlugin, granted: Set<ToolPermission>, required: Set<ToolPermission>)] {
        toolRegistry.allPlugins().map { plugin in
            let granted = toolRegistry.grantedPermissions[plugin.identifier] ?? []
            return (plugin, granted, plugin.requiredPermissions)
        }
    }

    public func grantPermissions(_ permissions: Set<ToolPermission>, to pluginIdentifier: String) throws {
        guard toolRegistry.plugin(identifier: pluginIdentifier) != nil else {
            throw ToolPluginError.pluginNotFound(pluginIdentifier)
        }
        toolRegistry.grantPermissions(permissions, for: pluginIdentifier)
        appendAuditEvent(
            .permissionChanged,
            documentID: nil,
            fileName: nil,
            actor: "user",
            detail: "Granted permissions [\(permissions.map(\.rawValue).sorted().joined(separator: ", "))] to '\(pluginIdentifier)'."
        )
        try persistStateIfNeeded()
    }

    public func revokePermission(_ permission: ToolPermission, from pluginIdentifier: String) throws {
        guard toolRegistry.plugin(identifier: pluginIdentifier) != nil else {
            throw ToolPluginError.pluginNotFound(pluginIdentifier)
        }
        toolRegistry.revokePermission(permission, from: pluginIdentifier)
        appendAuditEvent(
            .permissionChanged,
            documentID: nil,
            fileName: nil,
            actor: "user",
            detail: "Revoked permission '\(permission.rawValue)' from '\(pluginIdentifier)'."
        )
        try persistStateIfNeeded()
    }

    public func revokeAllPermissions(from pluginIdentifier: String) throws {
        guard toolRegistry.plugin(identifier: pluginIdentifier) != nil else {
            throw ToolPluginError.pluginNotFound(pluginIdentifier)
        }
        toolRegistry.revokeAllPermissions(from: pluginIdentifier)
        appendAuditEvent(
            .permissionChanged,
            documentID: nil,
            fileName: nil,
            actor: "user",
            detail: "Revoked all permissions from '\(pluginIdentifier)'."
        )
        try persistStateIfNeeded()
    }

    // MARK: - Other public API

    public func recategorize(
        documentID: UUID,
        to newCategory: DocumentCategory,
        reason: String,
        actor: String = "user"
    ) throws -> DocumentRecord {
        guard let existing = documentsByID[documentID] else {
            throw OrganizerError.documentNotFound(documentID)
        }

        let currentCategory = existing.effectiveCategory
        if newCategory == currentCategory {
            return existing
        }

        let baseCategory = existing.categoryResult.category
        let updatedCorrection: CategoryCorrection?
        if newCategory == baseCategory {
            updatedCorrection = nil
        } else {
            updatedCorrection = CategoryCorrection(
                previousCategory: baseCategory,
                newCategory: newCategory,
                reason: reason
            )
        }

        let updated = DocumentRecord(
            id: existing.id,
            fileName: existing.fileName,
            filePath: existing.filePath,
            contentHash: existing.contentHash,
            importedAt: existing.importedAt,
            contentPreview: existing.contentPreview,
            categoryResult: existing.categoryResult,
            correction: updatedCorrection
        )

        documentsByID[documentID] = updated
        appendAuditEvent(
            .recategorized,
            documentID: updated.id,
            fileName: updated.fileName,
            actor: actor,
            detail: "Category changed from \(currentCategory.rawValue) to \(newCategory.rawValue): \(reason)"
        )
        try persistStateIfNeeded()

        return updated
    }

    public func deleteDocument(documentID: UUID, actor: String = "user") throws {
        _ = try removeDocument(
            documentID: documentID,
            actor: actor,
            detail: "Document removed from organizer state."
        )
        try persistStateIfNeeded()
    }

    public func updateDocumentFilePath(
        documentID: UUID,
        to newPath: String,
        actor: String = "system"
    ) throws -> DocumentRecord {
        guard let existing = documentsByID[documentID] else {
            throw OrganizerError.documentNotFound(documentID)
        }

        guard FileManager.default.fileExists(atPath: newPath) else {
            throw OrganizerError.fileMissing(newPath)
        }

        if existing.filePath == newPath {
            return existing
        }

        let updatedURL = URL(fileURLWithPath: newPath)
        let updated = DocumentRecord(
            id: existing.id,
            fileName: updatedURL.lastPathComponent,
            filePath: newPath,
            contentHash: existing.contentHash,
            importedAt: existing.importedAt,
            contentPreview: existing.contentPreview,
            categoryResult: existing.categoryResult,
            correction: existing.correction
        )

        documentsByID[documentID] = updated
        appendAuditEvent(
            .exported,
            documentID: updated.id,
            fileName: updated.fileName,
            actor: actor,
            detail: "Document file location updated to \(newPath)."
        )
        try persistStateIfNeeded()

        return updated
    }

    public func enforceRetentionPolicy(referenceDate: Date = Date()) throws -> RetentionEnforcementResult {
        if let stateLoadError {
            throw OrganizerError.persistenceFailure(
                "Cannot enforce retention policy while state load failed. \(stateLoadError)"
            )
        }

        let retentionDays = max(0, privacy.retentionPolicy.retentionDays)
        let scannedCount = documentsByID.count
        guard privacy.retentionPolicy.autoDeleteEnabled else {
            return RetentionEnforcementResult(
                autoDeleteEnabled: false,
                retentionDays: retentionDays,
                scannedDocuments: scannedCount,
                deletedDocumentIDs: []
            )
        }

        let secondsPerDay: TimeInterval = 86_400
        let cutoff = referenceDate.addingTimeInterval(-Double(retentionDays) * secondsPerDay)
        let candidates = documentsByID.values
            .filter { $0.importedAt < cutoff }
            .sorted { $0.importedAt < $1.importedAt }

        var deletedIDs: [UUID] = []
        for candidate in candidates {
            _ = try removeDocument(
                documentID: candidate.id,
                actor: "system",
                detail: "Document removed by retention policy (older than \(retentionDays) days)."
            )
            deletedIDs.append(candidate.id)
        }

        if !deletedIDs.isEmpty {
            try persistStateIfNeeded()
        }

        return RetentionEnforcementResult(
            autoDeleteEnabled: true,
            retentionDays: retentionDays,
            scannedDocuments: scannedCount,
            deletedDocumentIDs: deletedIDs
        )
    }

    public func auditTimeline(limit: Int? = nil) -> [AuditEvent] {
        let sorted = auditEvents.sorted { $0.timestamp > $1.timestamp }
        guard let limit else {
            return sorted
        }
        return Array(sorted.prefix(limit))
    }

    public func saveAuditTimeline(to outputURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(auditTimeline())
        let parent = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: outputURL)

        appendAuditEvent(
            .exported,
            documentID: nil,
            fileName: nil,
            actor: "system",
            detail: "Audit timeline exported to \(outputURL.path)."
        )
        try persistStateIfNeeded()
    }

    public func exportState(to outputURL: URL) throws {
        if let stateLoadError {
            throw OrganizerError.persistenceFailure(
                "Cannot export organizer state while load failed. \(stateLoadError)"
            )
        }

        let state = OrganizerState(
            documents: listDocuments(),
            events: auditEvents,
            grantedPluginPermissions: toolRegistry.grantedPermissions
                .mapValues { permissions in permissions.map(\.rawValue) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(state)
        let parent = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: outputURL)

        appendAuditEvent(
            .exported,
            documentID: nil,
            fileName: nil,
            actor: "system",
            detail: "Organizer state exported to \(outputURL.path)."
        )
        try persistStateIfNeeded()
    }

    public func parseDocumentID(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw OrganizerError.invalidDocumentID(value)
        }
        return id
    }

    public func stateLoadIssue() -> String? {
        stateLoadError
    }

    public func stateHealthReport() -> StateHealthReport {
        let statePath = stateURL?.path ?? "(not configured)"
        let keyPath = stateKeyURL?.path ?? "(not configured)"
        let stateExists = stateURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let keyFileExists = stateKeyURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

        let keychainData = try? fetchKeyDataFromKeychain()
        let keychainExists = keychainData != nil
        let keyAvailable = keychainExists || keyFileExists

        let keyStorage: String
        if keychainExists {
            keyStorage = "keychain"
        } else if keyFileExists {
            keyStorage = "file"
        } else {
            keyStorage = "missing"
        }

        var keyLength: Int?
        if let keychainData {
            keyLength = keychainData.count
        } else if keyFileExists, let stateKeyURL {
            keyLength = try? Data(contentsOf: stateKeyURL).count
        }

        var stateEncrypted = false
        if stateExists, let stateURL,
           let data = try? Data(contentsOf: stateURL),
           let decoderState = try? JSONDecoder().decode(EncryptedOrganizerState.self, from: data) {
            stateEncrypted = decoderState.algorithm == "AES.GCM"
        }

        var recommendations: [String] = []
        if !stateExists {
            recommendations.append("No state file exists yet. Run an import command to initialize state.")
        }
        if stateEncrypted && !keyAvailable {
            recommendations.append("Encrypted state detected but key material is missing. Restore keychain entry or legacy key file backup.")
        }
        if let keyLength, keyLength != 32 {
            recommendations.append("Key file length is invalid. Expected 32 bytes for AES-256 key material.")
        }
        if migratedLegacyKeyFileToKeychain {
            recommendations.append("Legacy key file was migrated to Keychain for stronger local key protection.")
        }
        if let loadIssue = stateLoadError {
            recommendations.append("Resolve state load issue first; write operations are blocked to protect existing state.")
            recommendations.append("Current load issue: \(loadIssue)")
        }
        if recommendations.isEmpty {
            recommendations.append("State and key configuration look healthy.")
        }

        return StateHealthReport(
            stateFilePath: statePath,
            keyFilePath: keyPath,
            keyStorage: keyStorage,
            keyAvailable: keyAvailable,
            stateFileExists: stateExists,
            keyFileExists: keyFileExists,
            keyLengthBytes: keyLength,
            stateFileEncrypted: stateEncrypted,
            loadIssue: stateLoadError,
            recommendations: recommendations
        )
    }

    private func appendAuditEvent(
        _ eventType: AuditEventType,
        documentID: UUID?,
        fileName: String?,
        actor: String,
        detail: String
    ) {
        auditEvents.append(
            AuditEvent(
                eventType: eventType,
                documentID: documentID,
                fileName: fileName,
                actor: actor,
                detail: detail
            )
        )
    }

    @discardableResult
    private func removeDocument(
        documentID: UUID,
        actor: String,
        detail: String
    ) throws -> DocumentRecord {
        guard let removed = documentsByID.removeValue(forKey: documentID) else {
            throw OrganizerError.documentNotFound(documentID)
        }

        appendAuditEvent(
            .deleted,
            documentID: removed.id,
            fileName: removed.fileName,
            actor: actor,
            detail: detail
        )
        return removed
    }

    private func loadState(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            stateLoadError = nil
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try decodeState(from: data)
            documentsByID = Dictionary(uniqueKeysWithValues: state.documents.map { ($0.id, $0) })
            auditEvents = state.events
            stateLoadError = nil

            // Restore persisted plugin permission grants into the registry.
            if let saved = state.grantedPluginPermissions {
                for (identifier, rawValues) in saved {
                    let permissions = Set(rawValues.compactMap(ToolPermission.init(rawValue:)))
                    toolRegistry.setGrantedPermissions(permissions, for: identifier)
                }
            }
        } catch {
            stateLoadError = "Unable to load organizer state: \(error.localizedDescription)"
        }
    }

    private func persistStateIfNeeded() throws {
        guard let stateURL else {
            return
        }

        if let stateLoadError, FileManager.default.fileExists(atPath: stateURL.path) {
            throw OrganizerError.persistenceFailure(
                "Refusing to overwrite existing state because initial load failed. \(stateLoadError)"
            )
        }

        do {
            let state = OrganizerState(
                documents: listDocuments(),
                events: auditEvents,
                grantedPluginPermissions: toolRegistry.grantedPermissions
                    .mapValues { permissions in permissions.map(\.rawValue) }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let stateData = try encoder.encode(state)
            let data: Data
            if privacy.encryptStateAtRest {
                let key = try resolveOrCreateStateEncryptionKey()
                let sealedBox = try AES.GCM.seal(stateData, using: key)
                guard let combined = sealedBox.combined else {
                    throw OrganizerError.persistenceFailure("Missing combined ciphertext for encrypted state")
                }

                let encryptedState = EncryptedOrganizerState(
                    version: 1,
                    algorithm: "AES.GCM",
                    combinedCiphertext: combined.base64EncodedString()
                )
                data = try encoder.encode(encryptedState)
            } else {
                data = stateData
            }

            let parent = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: stateURL)
        } catch {
            throw OrganizerError.persistenceFailure(error.localizedDescription)
        }
    }

    private func findDuplicateDocument(contentHash: String) -> DocumentRecord? {
        listDocuments().first { record in
            record.contentHash == contentHash
        }
    }

    private func pluginOutputDirectory(for document: DocumentRecord) throws -> URL {
        let sourceURL = URL(fileURLWithPath: document.filePath)
        let parentDirectory = sourceURL.deletingLastPathComponent()
        let outputDirectory = parentDirectory.appendingPathComponent("DocumentOrganizerDerived", isDirectory: true)

        guard !outputDirectory.path.isEmpty else {
            throw OrganizerError.pluginOutputDirectoryUnavailable
        }

        return outputDirectory
    }

    private func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func decodeState(from data: Data) throws -> OrganizerState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let encrypted = try? decoder.decode(EncryptedOrganizerState.self, from: data),
           encrypted.algorithm == "AES.GCM",
           let combined = Data(base64Encoded: encrypted.combinedCiphertext) {
            let key = try resolveExistingStateEncryptionKey()
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(box, using: key)
            return try decoder.decode(OrganizerState.self, from: decrypted)
        }

        // Backward compatibility: load legacy plaintext JSON state.
        return try decoder.decode(OrganizerState.self, from: data)
    }

    private func resolveOrCreateStateEncryptionKey() throws -> SymmetricKey {
        if let keyData = try fetchKeyDataFromKeychain() {
            guard keyData.count == 32 else {
                throw OrganizerError.persistenceFailure("Invalid state encryption key length")
            }
            return SymmetricKey(data: keyData)
        }

        guard let stateKeyURL else {
            throw OrganizerError.persistenceFailure("Missing state encryption key path")
        }

        if FileManager.default.fileExists(atPath: stateKeyURL.path) {
            let existing = try Data(contentsOf: stateKeyURL)
            guard existing.count == 32 else {
                throw OrganizerError.persistenceFailure("Invalid state encryption key length")
            }

            do {
                try saveKeyDataToKeychain(existing)
                try? FileManager.default.removeItem(at: stateKeyURL)
                migratedLegacyKeyFileToKeychain = true
            } catch {
                // Preserve legacy file fallback if keychain is unavailable.
            }

            return SymmetricKey(data: existing)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        do {
            try saveKeyDataToKeychain(keyData)
        } catch {
            let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
            try keyData.write(to: stateKeyURL, options: .atomic)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: stateKeyURL.path)
        }

        return newKey
    }

    private func resolveExistingStateEncryptionKey() throws -> SymmetricKey {
        if let keyData = try fetchKeyDataFromKeychain() {
            guard keyData.count == 32 else {
                throw OrganizerError.persistenceFailure("Invalid state encryption key length")
            }
            return SymmetricKey(data: keyData)
        }

        guard let stateKeyURL else {
            throw OrganizerError.persistenceFailure("Missing state encryption key path")
        }

        guard FileManager.default.fileExists(atPath: stateKeyURL.path) else {
            throw OrganizerError.persistenceFailure("Missing state encryption key material for encrypted organizer state")
        }

        let existing = try Data(contentsOf: stateKeyURL)
        guard existing.count == 32 else {
            throw OrganizerError.persistenceFailure("Invalid state encryption key length")
        }

        do {
            try saveKeyDataToKeychain(existing)
            try? FileManager.default.removeItem(at: stateKeyURL)
            migratedLegacyKeyFileToKeychain = true
        } catch {
            // Keep file-based fallback when keychain is unavailable.
        }

        return SymmetricKey(data: existing)
    }

    private func keychainAccountIdentifier() throws -> String {
        guard let stateURL else {
            throw OrganizerError.persistenceFailure("Missing state URL for keychain account derivation")
        }
        let digest = SHA256.hash(data: Data(stateURL.path.utf8))
        let account = digest.map { String(format: "%02x", $0) }.joined()
        return "statekey-\(account)"
    }

    private func fetchKeyDataFromKeychain() throws -> Data? {
#if canImport(Security)
        let account = try keychainAccountIdentifier()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainServiceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw OrganizerError.persistenceFailure("Unable to read keychain state key (status \(status)).")
        }
        guard let data = item as? Data else {
            throw OrganizerError.persistenceFailure("Keychain returned unexpected key format.")
        }
        return data
#else
        return nil
#endif
    }

    private func saveKeyDataToKeychain(_ keyData: Data) throws {
#if canImport(Security)
        let account = try keychainAccountIdentifier()
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainServiceName,
            kSecAttrAccount as String: account
        ]

        let existingStatus = SecItemCopyMatching(identityQuery as CFDictionary, nil)
        if existingStatus == errSecSuccess {
            let updateAttrs: [String: Any] = [
                kSecValueData as String: keyData
            ]
            let updateStatus = SecItemUpdate(identityQuery as CFDictionary, updateAttrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw OrganizerError.persistenceFailure("Unable to update keychain state key (status \(updateStatus)).")
            }
            return
        }

        if existingStatus != errSecItemNotFound {
            throw OrganizerError.persistenceFailure("Unable to query keychain state key (status \(existingStatus)).")
        }

        var addQuery = identityQuery
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecValueData as String] = keyData
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw OrganizerError.persistenceFailure("Unable to store keychain state key (status \(addStatus)).")
        }
#else
        _ = keyData
        throw OrganizerError.persistenceFailure("Keychain storage is unavailable on this platform.")
#endif
    }
}
