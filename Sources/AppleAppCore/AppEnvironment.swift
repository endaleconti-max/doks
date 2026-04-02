import Foundation
import Privacy

public struct AppEnvironment {
    public let privacyPreset: PrivacyPreset
    public let workingDirectoryName: String
    public let rootURL: URL
    public let stateURL: URL

    public init(
        privacyPreset: PrivacyPreset = .balanced,
        fileManager: FileManager = .default,
        applicationSupportDirectoryURL: URL? = nil,
        workingDirectoryName: String = "DocumentOrganizer"
    ) {
        self.privacyPreset = privacyPreset
        self.workingDirectoryName = workingDirectoryName

        let baseDirectory = applicationSupportDirectoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)

        self.rootURL = baseDirectory.appendingPathComponent(workingDirectoryName, isDirectory: true)
        self.stateURL = rootURL.appendingPathComponent("audit/organizer-state.json")
    }

    public var privacyConfiguration: PrivacyConfiguration {
        PrivacyConfiguration.preset(privacyPreset)
    }

    public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}
