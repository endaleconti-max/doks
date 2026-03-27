import Foundation

/// Persisted user preferences for DocumentOrganizer.
@MainActor
public final class AppSettings: ObservableObject {
    @MainActor public static let shared = AppSettings()

    private let store = UserDefaults.standard

    // MARK: - Watched Folder Toggles

    @Published public var watchDownloads: Bool {
        didSet { store.set(watchDownloads, forKey: Keys.watchDownloads) }
    }

    @Published public var watchDesktop: Bool {
        didSet { store.set(watchDesktop, forKey: Keys.watchDesktop) }
    }

    @Published public var watchDocuments: Bool {
        didSet { store.set(watchDocuments, forKey: Keys.watchDocuments) }
    }

    // MARK: - Organization Root

    @Published public var organizationRootBookmark: Data? {
        didSet { store.set(organizationRootBookmark, forKey: Keys.organizationRootBookmark) }
    }

    /// The human-readable path, derived from the bookmark or default.
    @Published public var organizationRootPath: String

    // MARK: - Privacy Preset

    @Published public var privacyPreset: PrivacyPreset {
        didSet { store.set(privacyPreset.rawValue, forKey: Keys.privacyPreset) }
    }

    // MARK: - Naming

    @Published public var namingPattern: NamingPattern {
        didSet { store.set(namingPattern.rawValue, forKey: Keys.namingPattern) }
    }

    // MARK: - Auto-start

    @Published public var autoStartWatching: Bool {
        didSet { store.set(autoStartWatching, forKey: Keys.autoStartWatching) }
    }

    // MARK: - Init

    private init() {
        let defaults: [String: Any] = [
            Keys.watchDownloads: true,
            Keys.watchDesktop: true,
            Keys.watchDocuments: false,
            Keys.privacyPreset: PrivacyPreset.balanced.rawValue,
            Keys.namingPattern: NamingPattern.categoryDateOriginal.rawValue,
            Keys.autoStartWatching: false,
        ]
        store.register(defaults: defaults)

        watchDownloads = store.bool(forKey: Keys.watchDownloads)
        watchDesktop = store.bool(forKey: Keys.watchDesktop)
        watchDocuments = store.bool(forKey: Keys.watchDocuments)
        autoStartWatching = store.bool(forKey: Keys.autoStartWatching)
        organizationRootBookmark = store.data(forKey: Keys.organizationRootBookmark)
        privacyPreset = PrivacyPreset(rawValue: store.string(forKey: Keys.privacyPreset) ?? "") ?? .balanced
        namingPattern = NamingPattern(rawValue: store.string(forKey: Keys.namingPattern) ?? "") ?? .categoryDateOriginal

        // Default first so all stored properties are initialized
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        organizationRootPath = docs.appendingPathComponent("Organized Documents").path

        // Resolve bookmark or use default
        var stale = false
        if let bookmark = organizationRootBookmark,
           let resolvedURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            organizationRootPath = resolvedURL.path
        }
    }

    /// Best-effort resolved URL for where organized files go.
    public var resolvedOrganizationRoot: URL {
        var stale = false
        if let bookmark = organizationRootBookmark,
           let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            return url
        }
        return URL(fileURLWithPath: organizationRootPath)
    }

    /// Update the organization root from a user-selected URL (storing a security-scoped bookmark).
    public func setOrganizationRoot(_ url: URL) {
        organizationRootPath = url.path
        organizationRootBookmark = try? url.bookmarkData(options: .withSecurityScope)
    }

    /// The list of directories that should currently be watched.
    public var watchedDirectories: [URL] {
        let fm = FileManager.default
        var dirs: [URL] = []
        if watchDownloads, let url = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            dirs.append(url)
        }
        if watchDesktop, let url = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            dirs.append(url)
        }
        if watchDocuments, let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            dirs.append(url)
        }
        return dirs
    }

    private enum Keys {
        static let watchDownloads = "settings.watchDownloads"
        static let watchDesktop = "settings.watchDesktop"
        static let watchDocuments = "settings.watchDocuments"
        static let organizationRootBookmark = "settings.organizationRootBookmark"
        static let privacyPreset = "settings.privacyPreset"
        static let namingPattern = "settings.namingPattern"
        static let autoStartWatching = "settings.autoStartWatching"
    }
}

// MARK: - Privacy Preset

public enum PrivacyPreset: String, CaseIterable, Identifiable {
    case strict
    case balanced
    case permissive

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .strict: return "Strict"
        case .balanced: return "Balanced"
        case .permissive: return "Permissive"
        }
    }

    public var description: String {
        switch self {
        case .strict:
            return "No metadata stored beyond category. 30-day auto-deletion. No content previews."
        case .balanced:
            return "Metadata and short previews stored. 90-day retention. Encryption at rest."
        case .permissive:
            return "Full metadata and previews stored. No auto-deletion. Enhanced search."
        }
    }

    public var retentionDays: Int {
        switch self {
        case .strict: return 30
        case .balanced: return 90
        case .permissive: return 365
        }
    }
}

// MARK: - Naming Pattern

public enum NamingPattern: String, CaseIterable, Identifiable {
    case categoryDateOriginal = "category-date-original"
    case dateOriginal = "date-original"
    case originalOnly = "original"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .categoryDateOriginal: return "[Category]-[Date]-[Original]"
        case .dateOriginal: return "[Date]-[Original]"
        case .originalOnly: return "[Original] (no rename)"
        }
    }

    public var example: String {
        switch self {
        case .categoryDateOriginal: return "invoice-2026-03-26-payment.txt"
        case .dateOriginal: return "2026-03-26-payment.txt"
        case .originalOnly: return "payment.txt"
        }
    }
}
