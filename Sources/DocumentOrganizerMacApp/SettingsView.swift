import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppTheme.canvasGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView {
                WatchingTab(settings: settings)
                    .tabItem {
                        Label("Watching", systemImage: "folder.badge.gearshape")
                    }
                    .tag(0)

                PrivacyTab(settings: settings)
                    .tabItem {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                    .tag(1)

                NamingTab(settings: settings)
                    .tabItem {
                        Label("Naming", systemImage: "tag")
                    }
                    .tag(2)

                StorageTab(settings: settings)
                    .tabItem {
                        Label("Storage", systemImage: "internaldrive")
                    }
                    .tag(3)
            }
            .tint(AppTheme.actionAccent)
        }
        .frame(width: 500, height: 380)
    }
}

// MARK: - Watching Tab

private struct WatchingTab: View {
    @ObservedObject var settings: AppSettings

    private let fm = FileManager.default

    var body: some View {
        Form {
            Section("Watched Folders") {
                Text("DocumentOrganizer will automatically process new files placed in these folders.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                folderRow(
                    label: "Downloads",
                    systemImage: "arrow.down.circle",
                    path: fm.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads",
                    isOn: $settings.watchDownloads
                )

                folderRow(
                    label: "Desktop",
                    systemImage: "desktopcomputer",
                    path: fm.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "~/Desktop",
                    isOn: $settings.watchDesktop
                )

                folderRow(
                    label: "Documents",
                    systemImage: "folder",
                    path: fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "~/Documents",
                    isOn: $settings.watchDocuments
                )
            }
            .padding(.top, 6)

            Section("Startup") {
                Toggle(isOn: $settings.autoStartWatching) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Start watching on launch")
                        Text("Automatically begin monitoring folders when app opens.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.panelStroke)
        )
    }

    private func folderRow(label: String, systemImage: String, path: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Privacy Tab

private struct PrivacyTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Privacy Preset") {
                Text("Controls how much metadata is stored, how long documents are retained, and what processing is allowed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(PrivacyPreset.allCases) { preset in
                    presetRow(preset: preset)
                }
            }
            .padding(.top, 6)

            Section("Current Settings") {
                LabeledContent("Retention Window") {
                    Text("\(settings.privacyPreset.retentionDays) days")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Auto-delete Expired") {
                    Text(settings.privacyPreset == .permissive ? "Off" : "On")
                        .foregroundStyle(settings.privacyPreset == .permissive ? Color.secondary : Color.orange)
                }

                LabeledContent("Content Previews") {
                    Text(settings.privacyPreset == .strict ? "Disabled" : "Enabled")
                        .foregroundStyle(settings.privacyPreset == .strict ? .secondary : .primary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.panelStroke)
        )
    }

    private func presetRow(preset: PrivacyPreset) -> some View {
        Button {
            settings.privacyPreset = preset
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: settings.privacyPreset == preset ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(settings.privacyPreset == preset ? Color.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.label)
                        .bold()
                    Text(preset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Naming Tab

private struct NamingTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("File Naming Pattern") {
                Text("Choose how organized files are renamed. The pattern is applied when files are moved into their category folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(NamingPattern.allCases) { pattern in
                    patternRow(pattern: pattern)
                }
            }
            .padding(.top, 6)

            Section("Preview") {
                LabeledContent("Example") {
                    Text(settings.namingPattern.example)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.panelStroke)
        )
    }

    private func patternRow(pattern: NamingPattern) -> some View {
        Button {
            settings.namingPattern = pattern
        } label: {
            HStack(spacing: 12) {
                Image(systemName: settings.namingPattern == pattern ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(settings.namingPattern == pattern ? Color.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pattern.label)
                        .font(.system(.body, design: .monospaced))
                    Text(pattern.example)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Storage Tab

private struct StorageTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isPickingFolder = false

    var body: some View {
        Form {
            Section("Organization Folder") {
                Text("All organized documents will be moved here, sorted into category subfolders.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LabeledContent("Current Location") {
                    Text(settings.organizationRootPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 260, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Button("Choose Folder…") {
                        pickFolder()
                    }

                    Button("Reveal in Finder") {
                        NSWorkspace.shared.open(settings.resolvedOrganizationRoot)
                    }
                }
            }
            .padding(.top, 6)

            Section("State File") {
                Text("The encrypted organizer state (document index) is stored separately from the organized files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LabeledContent("Stored at") {
                    let stateDir = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                        .appendingPathComponent("DocumentOrganizer").path ?? "~/.local/share"
                    Text(stateDir)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 260, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.panelStroke)
        )
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Organization Folder"
        panel.message = "Choose where organized documents will be placed."

        if panel.runModal() == .OK, let url = panel.url {
            settings.setOrganizationRoot(url)
        }
    }
}
