import AppleAppCore
import Foundation
import Testing

@Suite("AppleAppCore facade flows")
struct DocumentOrganizerFacadeTests {
    @Test("Facade imports and exposes dashboard snapshot")
    func facadeImportsAndBuildsDashboard() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("DocumentOrganizerAppleAppCoreTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let env = AppEnvironment(
            privacyPreset: .balanced,
            applicationSupportDirectoryURL: tempRoot,
            workingDirectoryName: "AppCoreHarness"
        )

        let sample = tempRoot.appendingPathComponent("invoice.txt")
        try "Invoice #A-42\nPayment terms\nTotal due 100 EUR\n".write(to: sample, atomically: true, encoding: .utf8)

        let facade = try DocumentOrganizerFacade(environment: env)
        let imported = try facade.importDocuments(paths: [sample.path])

        #expect(imported.count == 1)

        let listed = facade.listDocuments()
        #expect(listed.count == 1)

        let snapshot = facade.dashboardSnapshot()
        #expect(snapshot.totalDocuments == 1)
        #expect(snapshot.categoryBreakdown.contains { $0.count == 1 })

        let stateURL = facade.appStateURL()
        #expect(stateURL.path.hasSuffix("audit/organizer-state.json"))
    }
}
