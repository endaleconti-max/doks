import Core
import Foundation

public final class ToolRegistry {
    private var plugins: [String: any ToolPlugin] = [:]
    public private(set) var grantedPermissions: [String: Set<ToolPermission>] = [:]

    public init() {}

    public func register(
        _ plugin: any ToolPlugin,
        grantedPermissions permissions: Set<ToolPermission>? = nil
    ) {
        plugins[plugin.identifier] = plugin
        // Only apply caller-supplied grants; nil means start with no permissions.
        if let permissions {
            grantedPermissions[plugin.identifier] = permissions
        }
    }

    public func grantPermissions(_ permissions: Set<ToolPermission>, for identifier: String) {
        grantedPermissions[identifier, default: []].formUnion(permissions)
    }

    public func revokePermission(_ permission: ToolPermission, from identifier: String) {
        grantedPermissions[identifier]?.remove(permission)
    }

    public func revokeAllPermissions(from identifier: String) {
        grantedPermissions[identifier] = []
    }

    public func setGrantedPermissions(_ permissions: Set<ToolPermission>, for identifier: String) {
        grantedPermissions[identifier] = permissions
    }

    public func plugin(identifier: String) -> (any ToolPlugin)? {
        plugins[identifier]
    }

    public func allPlugins() -> [any ToolPlugin] {
        plugins.values.sorted { $0.displayName < $1.displayName }
    }

    public func availableTools(for document: DocumentRecord) -> [any ToolPlugin] {
        plugins.values
            .filter { plugin in
                plugin.canProcess(document: document)
                    && permissionsGranted(for: plugin)
            }
            .sorted { $0.displayName < $1.displayName }
    }

    public func permissionsGranted(for plugin: any ToolPlugin) -> Bool {
        let granted = grantedPermissions[plugin.identifier] ?? []
        return plugin.requiredPermissions.isSubset(of: granted)
    }

    public static func defaultRegistry() -> ToolRegistry {
        let registry = ToolRegistry()
        // Plugins are registered without any permissions granted.
        // Use grant-tool CLI command (or OrganizerService.grantPermissions) to enable.
        registry.register(VersionedTextCleanupPlugin())
        registry.register(PlainTextToMarkdownPlugin())
        return registry
    }
}
