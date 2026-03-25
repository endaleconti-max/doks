import Foundation

public enum DocumentCategory: String, CaseIterable, Codable {
    case invoice
    case contract
    case resume
    case legal
    case medical
    case education
    case finance
    case identification
    case correspondence
    case general
}

public struct CategoryResult: Codable {
    public let category: DocumentCategory
    public let confidence: Double
    public let explanation: String

    public init(category: DocumentCategory, confidence: Double, explanation: String) {
        self.category = category
        self.confidence = confidence
        self.explanation = explanation
    }
}

public struct CategoryCorrection: Codable {
    public let previousCategory: DocumentCategory
    public let newCategory: DocumentCategory
    public let reason: String
    public let correctedAt: Date

    public init(
        previousCategory: DocumentCategory,
        newCategory: DocumentCategory,
        reason: String,
        correctedAt: Date = Date()
    ) {
        self.previousCategory = previousCategory
        self.newCategory = newCategory
        self.reason = reason
        self.correctedAt = correctedAt
    }
}

public enum AuditEventType: String, Codable {
    case imported
    case recategorized
    case deleted
    case exported
    case toolExecuted
    case permissionChanged
}

public struct AuditEvent: Codable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AuditEventType
    public let documentID: UUID?
    public let fileName: String?
    public let actor: String
    public let detail: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: AuditEventType,
        documentID: UUID?,
        fileName: String?,
        actor: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.documentID = documentID
        self.fileName = fileName
        self.actor = actor
        self.detail = detail
    }
}

public struct DocumentRecord: Codable {
    public let id: UUID
    public let fileName: String
    public let filePath: String
    public let contentHash: String?
    public let importedAt: Date
    public let contentPreview: String
    public let categoryResult: CategoryResult
    public let correction: CategoryCorrection?

    public init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        contentHash: String? = nil,
        importedAt: Date = Date(),
        contentPreview: String,
        categoryResult: CategoryResult,
        correction: CategoryCorrection? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.contentHash = contentHash
        self.importedAt = importedAt
        self.contentPreview = contentPreview
        self.categoryResult = categoryResult
        self.correction = correction
    }

    public var effectiveCategory: DocumentCategory {
        correction?.newCategory ?? categoryResult.category
    }
}
