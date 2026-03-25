import Foundation

public struct DataRetentionPolicy {
    public let retentionDays: Int
    public let autoDeleteEnabled: Bool

    public init(retentionDays: Int = 365, autoDeleteEnabled: Bool = false) {
        self.retentionDays = retentionDays
        self.autoDeleteEnabled = autoDeleteEnabled
    }
}

public struct PluginPermissionPolicy {
    /// Map of plugin identifier to default granted permission raw values.
    public let defaultGrantedPermissionsByPlugin: [String: Set<String>]

    public init(defaultGrantedPermissionsByPlugin: [String: Set<String>] = [:]) {
        self.defaultGrantedPermissionsByPlugin = defaultGrantedPermissionsByPlugin
    }
}

public enum PrivacyPreset: String, CaseIterable {
    case strict
    case balanced
    case permissive
}

public struct PrivacyConfiguration {
    public let processingMode: String
    public let storesRawContent: Bool
    public let exportsAuditLog: Bool
    public let encryptStateAtRest: Bool
    public let retentionPolicy: DataRetentionPolicy
    public let pluginPermissionPolicy: PluginPermissionPolicy
    public let presetName: String

    public init(
        processingMode: String = "local-only",
        storesRawContent: Bool = false,
        exportsAuditLog: Bool = true,
        encryptStateAtRest: Bool = true,
        retentionPolicy: DataRetentionPolicy = DataRetentionPolicy(),
        pluginPermissionPolicy: PluginPermissionPolicy = PluginPermissionPolicy(),
        presetName: String = "custom"
    ) {
        self.processingMode = processingMode
        self.storesRawContent = storesRawContent
        self.exportsAuditLog = exportsAuditLog
        self.encryptStateAtRest = encryptStateAtRest
        self.retentionPolicy = retentionPolicy
        self.pluginPermissionPolicy = pluginPermissionPolicy
        self.presetName = presetName
    }

    public static func preset(_ preset: PrivacyPreset) -> PrivacyConfiguration {
        switch preset {
        case .strict:
            return PrivacyConfiguration(
                processingMode: "local-only",
                storesRawContent: false,
                exportsAuditLog: true,
                encryptStateAtRest: true,
                retentionPolicy: DataRetentionPolicy(retentionDays: 90, autoDeleteEnabled: true),
                pluginPermissionPolicy: PluginPermissionPolicy(defaultGrantedPermissionsByPlugin: [:]),
                presetName: preset.rawValue
            )
        case .balanced:
            return PrivacyConfiguration(
                processingMode: "local-only",
                storesRawContent: false,
                exportsAuditLog: true,
                encryptStateAtRest: true,
                retentionPolicy: DataRetentionPolicy(retentionDays: 180, autoDeleteEnabled: false),
                pluginPermissionPolicy: PluginPermissionPolicy(defaultGrantedPermissionsByPlugin: [:]),
                presetName: preset.rawValue
            )
        case .permissive:
            let allToolPermissions = Set(["readDocument", "createDerivedFile"])
            return PrivacyConfiguration(
                processingMode: "local-only",
                storesRawContent: true,
                exportsAuditLog: true,
                encryptStateAtRest: true,
                retentionPolicy: DataRetentionPolicy(retentionDays: 365, autoDeleteEnabled: false),
                pluginPermissionPolicy: PluginPermissionPolicy(
                    defaultGrantedPermissionsByPlugin: [
                        "text-to-markdown": allToolPermissions,
                        "versioned-text-cleanup": allToolPermissions,
                    ]
                ),
                presetName: preset.rawValue
            )
        }
    }

    public var gdprNotes: [String] {
        [
            "Privacy preset: \(presetName).",
            "Data minimization: only metadata and preview snippets are stored by default.",
            "Purpose limitation: categorization output is used only for organization features.",
            "Encryption at rest: local organizer state is encrypted with AES-GCM.",
            "Storage limitation: retention policy can enforce deletion windows.",
            "User rights support: records can be exported and deleted by identifier."
        ]
    }
}
