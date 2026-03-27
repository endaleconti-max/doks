import Core
import Foundation
import Services

public struct DashboardSnapshot {
    public let generatedAt: Date
    public let totalDocuments: Int
    public let categoryBreakdown: [CategorySummaryItem]
    public let recentAuditEvents: [AuditEvent]

    public init(
        generatedAt: Date,
        totalDocuments: Int,
        categoryBreakdown: [CategorySummaryItem],
        recentAuditEvents: [AuditEvent]
    ) {
        self.generatedAt = generatedAt
        self.totalDocuments = totalDocuments
        self.categoryBreakdown = categoryBreakdown
        self.recentAuditEvents = recentAuditEvents
    }
}

public final class DocumentOrganizerFacade {
    private let environment: AppEnvironment
    private let organizer: OrganizerService

    public init(environment: AppEnvironment = AppEnvironment()) throws {
        self.environment = environment
        try environment.ensureDirectoriesExist()
        self.organizer = OrganizerService(
            privacy: environment.privacyConfiguration,
            stateURL: environment.stateURL
        )
    }

    public func importDocuments(paths: [String]) throws -> [DocumentRecord] {
        try paths.map { try organizer.processDocument(at: $0) }
    }

    public func listDocuments() -> [DocumentRecord] {
        organizer.listDocuments()
    }

    public func searchDocuments(query: String) -> [DocumentRecord] {
        organizer.searchDocuments(query: query)
    }

    public func recategorize(documentID: UUID, to category: DocumentCategory, reason: String) throws -> DocumentRecord {
        try organizer.recategorize(documentID: documentID, to: category, reason: reason)
    }

    public func deleteDocument(documentID: UUID) throws {
        try organizer.deleteDocument(documentID: documentID)
    }

    public func updateDocumentFilePath(documentID: UUID, to newPath: String, actor: String = "system") throws -> DocumentRecord {
        try organizer.updateDocumentFilePath(documentID: documentID, to: newPath, actor: actor)
    }

    public func dashboardSnapshot(auditLimit: Int = 12) -> DashboardSnapshot {
        DashboardSnapshot(
            generatedAt: Date(),
            totalDocuments: organizer.listDocuments().count,
            categoryBreakdown: organizer.categorySummary(),
            recentAuditEvents: organizer.auditTimeline(limit: auditLimit)
        )
    }

    public func stateHealthReport() -> StateHealthReport {
        organizer.stateHealthReport()
    }

    public func appStateURL() -> URL {
        environment.stateURL
    }
}
