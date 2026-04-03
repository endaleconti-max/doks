import AppleAppCore
import AppKit
import Core
import Foundation
import SwiftUI
import SystemConfiguration
import UniformTypeIdentifiers

extension DocumentRecord: Identifiable {}

// MARK: - App Entry

@main
struct DocumentOrganizerMacApp: App {
    @StateObject private var model = DocumentOrganizerViewModel()

    var body: some Scene {
        // MARK: Main Window
        WindowGroup("DocumentOrganizer", id: "main-window") {
            MainWindowContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // MARK: Settings Window
        Settings {
            SettingsView()
        }

        // MARK: Menu Bar
        MenuBarExtra("DocumentOrganizer", systemImage: "menubar.dock.rectangle") {
            MenuBarDashboardView(model: model)
        }
    }
}

// MARK: - Main Window Content

private struct MainWindowContentView: View {
    @ObservedObject var model: DocumentOrganizerViewModel
    @State private var supportMessageDraft = ""
    @State private var supportReply = "Ask us anything."
    @State private var isStatusPillHovered = false
    @State private var isStatusPillPressed = false
    @State private var isProcessingPillHovered = false
    @State private var isProcessingPillPressed = false
    @State private var showHealthDetails = false

    private let outerInset: CGFloat = 24
    private let rightInset: CGFloat = 48
    private let leftActionColumnWidth: CGFloat = 220
    private let panelMinWidth: CGFloat = 320
    private let panelMaxWidth: CGFloat = 760
    private let pillSpacing: CGFloat = 20
    private let searchBarTopPadding: CGFloat = 10
    private let searchBarHeight: CGFloat = 44
    private let searchBarToGridSpacing: CGFloat = 16
    private let pillMinHeight: CGFloat = 68

    private func openSettings() {
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = rightPanelWidth(for: geometry.size.width)

            ZStack {
                LinearGradient(
                    colors: AppTheme.canvasGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.50)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.09),
                        Color(nsColor: NSColor(calibratedWhite: 0.82, alpha: 0.12)),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.10), location: 0.00),
                        .init(color: Color.clear, location: 0.06),
                        .init(color: Color.white.opacity(0.06), location: 0.12),
                        .init(color: Color.clear, location: 0.18),
                        .init(color: Color.white.opacity(0.05), location: 0.24),
                        .init(color: Color.clear, location: 0.30),
                        .init(color: Color.white.opacity(0.04), location: 0.36),
                        .init(color: Color.clear, location: 0.42),
                        .init(color: Color.white.opacity(0.03), location: 0.48),
                        .init(color: Color.clear, location: 0.54),
                        .init(color: Color.white.opacity(0.02), location: 0.60),
                        .init(color: Color.clear, location: 1.00),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.40)
                .blendMode(.screen)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 700
                )
                .ignoresSafeArea()
            }
            // Top-right: standalone search bar aligned to pill grid bounds
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search documents", text: $model.searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .font(.caption)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(width: panelWidth, alignment: .leading)
                .background {
                    metallicCardBackground(cornerRadius: 10)
                }
                .padding(.top, searchBarTopPadding)
                .padding(.trailing, rightInset)
            }
            // Top-left: Import + Turbo buttons
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        model.importFolderFromOpenPanel()
                    } label: {
                        Label("Import", systemImage: "folder.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.startFolderWatching()
                    } label: {
                        Label("Turbo", systemImage: "bolt.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)

                }
                .frame(width: leftActionColumnWidth, alignment: .leading)
                .padding(.top, outerInset)
                .padding(.leading, outerInset)
            }
            // Top-right: responsive pill grid
            .overlay(alignment: .topTrailing) {
                LazyVGrid(columns: pillGridColumns(for: panelWidth), alignment: .trailing, spacing: pillSpacing) {
                    pillGridContent
                }
                .frame(width: panelWidth)
                .padding(.trailing, rightInset)
                .padding(.top, searchBarTopPadding + searchBarHeight + searchBarToGridSpacing)
            }
            // Bottom-left: support chat (above quick links bar)
            .overlay(alignment: .bottomLeading) {
                supportChatCard
                    .padding(.leading, outerInset)
                    .padding(.bottom, 70)
            }
            // Bottom center: quick links
            .overlay(alignment: .bottom) {
                quickLinksBar
                    .padding(.bottom, 20)
            }
            .background(WindowTitleBarConfigurator())
            .alert("DocumentOrganizer Error",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) { model.errorMessage = nil } },
                message: { Text(model.errorMessage ?? "Unknown error") }
            )
        }
    }

    @ViewBuilder
    private var pillGridContent: some View {
        pillContainer {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }

        pillContainer(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.isNetworkConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(model.isNetworkConnected ? "Connected" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Storage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(model.storageAvailable)
                        .font(.caption)
                        .foregroundStyle(.white)
                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.storageTotal)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        pillContainer(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Documents")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(model.totalDocuments) total · \(model.activeCategoryCount) categories")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if !model.documents.isEmpty {
                Divider().overlay(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(Array(model.documents.prefix(3))) { doc in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(doc.fileName)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }

        pillContainer(alignment: .leading, spacing: 8) {
            Text("Status / Feedback")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(statusFeedbackText)
                .font(.caption)
                .foregroundStyle(statusFeedbackColor)
                .lineLimit(2)
            Text("Health: \(healthWarningCount) warning(s) · \(healthErrorCount) error(s)")
                .font(.caption2)
                .foregroundStyle(healthSummaryColor)
                .lineLimit(1)
            Text("Click for details")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .scaleEffect(isStatusPillPressed ? 0.988 : 1.0)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isStatusPillHovered ? Color.white.opacity(0.36) : Color.white.opacity(0.14),
                    lineWidth: isStatusPillHovered ? 1.1 : 0.75
                )
        }
        .animation(.easeOut(duration: 0.14), value: isStatusPillHovered)
        .animation(.easeOut(duration: 0.08), value: isStatusPillPressed)
        .onHover { isStatusPillHovered = $0 }
        .onLongPressGesture(minimumDuration: 0, pressing: { isStatusPillPressed = $0 }, perform: {})
        .onTapGesture {
            model.refresh()
            model.updateFolderStatistics()
            showHealthDetails = true
        }
        .popover(isPresented: $showHealthDetails, arrowEdge: .bottom) {
            healthDetailsPopover
        }

        pillContainer(alignment: .leading, spacing: 8) {
            Text("Active Watched Folders")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(model.watchedFoldersSummary)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(model.isFolderWatchingEnabled ? "Auto-watch: On" : "Auto-watch: Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        pillContainer(alignment: .leading, spacing: 8) {
            Text("Processing Activity")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if model.isFolderWatchingEnabled {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                }
                Text(model.isFolderWatchingEnabled ? "Monitoring for new files" : "Idle")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            Text(model.isFolderWatchingEnabled ? "Click to stop watching" : "Click to start watching")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .scaleEffect(isProcessingPillPressed ? 0.988 : 1.0)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isProcessingPillHovered ? Color.white.opacity(0.36) : Color.white.opacity(0.14),
                    lineWidth: isProcessingPillHovered ? 1.1 : 0.75
                )
        }
        .animation(.easeOut(duration: 0.14), value: isProcessingPillHovered)
        .animation(.easeOut(duration: 0.08), value: isProcessingPillPressed)
        .onHover { isProcessingPillHovered = $0 }
        .onLongPressGesture(minimumDuration: 0, pressing: { isProcessingPillPressed = $0 }, perform: {})
        .onTapGesture {
            model.toggleFolderWatching()
        }

        pillContainer(alignment: .leading, spacing: 8) {
            Text("Quick Action")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                model.importDocumentsFromOpenPanel()
            } label: {
                Label("Import Documents", systemImage: "square.and.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Text("Pick files and add them now")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        pillContainer(alignment: .leading, spacing: 8) {
            Text("Quick Action")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                model.revealOrganizationFolder()
            } label: {
                Label("Open Organized Folder", systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Text("Jump to destination folder")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func rightPanelWidth(for windowWidth: CGFloat) -> CGFloat {
        let available = windowWidth - leftActionColumnWidth - rightInset - outerInset
        return min(panelMaxWidth, max(panelMinWidth, available))
    }

    private func pillGridColumns(for panelWidth: CGFloat) -> [GridItem] {
        if panelWidth >= 560 {
            return [
                GridItem(.flexible(minimum: 220), spacing: pillSpacing),
                GridItem(.flexible(minimum: 220), spacing: pillSpacing),
            ]
        }
        return [GridItem(.flexible(minimum: 220), spacing: pillSpacing)]
    }

    private var supportChatCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Support Chat")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(supportReply)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(width: 130, alignment: .leading)

            TextField("Message support", text: $supportMessageDraft)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 130)
                .frame(minHeight: 30)

            Button("Send") {
                sendSupportMessage()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(width: 130, alignment: .leading)
        }
        .padding(12)
        .background {
            metallicCardBackground(cornerRadius: 10)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var quickLinksBar: some View {
        HStack(spacing: 16) {
            quickLinkButton("FAQ")
            quickLinkButton("Impressum")
            quickLinkButton("Privacy")
            quickLinkButton("Contact")
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func quickLinkButton(_ title: String) -> some View {
        Button(title) {
            supportReply = "\(title) link selected. Configure destination in app settings."
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func sendSupportMessage() {
        let trimmed = supportMessageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        supportReply = "Support received: \(trimmed)"
        supportMessageDraft = ""
    }

    private func pillContainer<Content: View>(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, minHeight: pillMinHeight, alignment: .topLeading)
        .padding(10)
        .background {
            metallicCardBackground(cornerRadius: 10)
        }
    }

    private func metallicCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.50),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    private var statusFeedbackText: String {
        if let error = model.errorMessage, !error.isEmpty { return error }
        if let success = model.successMessage, !success.isEmpty { return success }
        return model.isStateHealthy ? "State healthy" : "State needs attention"
    }

    private var statusFeedbackColor: Color {
        if model.errorMessage != nil { return .red }
        if model.successMessage != nil { return .green }
        return model.isStateHealthy ? .green : .orange
    }

    private var healthErrorCount: Int {
        model.errorMessage == nil ? 0 : 1
    }

    private var healthWarningCount: Int {
        var warnings = 0
        if !model.isNetworkConnected { warnings += 1 }
        if !model.isFolderWatchingEnabled { warnings += 1 }
        if !model.isStateHealthy { warnings += 1 }
        return warnings
    }

    private var healthSummaryColor: Color {
        if healthErrorCount > 0 { return .red }
        if healthWarningCount > 0 { return .orange }
        return .green
    }

    private var healthDetailsPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Health")
                .font(.headline)
                .foregroundStyle(.white)

            Text("\(healthWarningCount) warning(s) · \(healthErrorCount) error(s)")
                .font(.caption)
                .foregroundStyle(healthSummaryColor)

            Divider().overlay(Color.white.opacity(0.2))

            if healthDetailItems.isEmpty {
                Text("All checks look healthy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(healthDetailItems, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background {
            metallicCardBackground(cornerRadius: 10)
        }
    }

    private var healthDetailItems: [String] {
        var items: [String] = []
        if !model.isNetworkConnected { items.append("Network is offline.") }
        if !model.isFolderWatchingEnabled { items.append("Folder watching is currently off.") }
        if !model.isStateHealthy { items.append("State requires attention.") }
        if let error = model.errorMessage, !error.isEmpty { items.append("Latest error: \(error)") }
        return items
    }

}

// MARK: - Window Chrome Configurator

/// Removes the native macOS title bar, toolbar, and sidebar toggle.
private struct WindowTitleBarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.titleVisibility = .hidden
    }
}

// MARK: - Menu Bar Dashboard

private struct MenuBarDashboardView: View {
    @ObservedObject var model: DocumentOrganizerViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var quickSelectedDocumentID: UUID?
    @State private var quickSelectedCategory: DocumentCategory = .general
    @State private var quickReason = "Updated from menu bar"

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            actions
            Divider()
            recentDocuments
            if !model.documents.isEmpty {
                Divider()
                quickReview
            }
            Divider()
            autoOrganization
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
        .background(
            LinearGradient(
                colors: [AppTheme.vividBlue.opacity(0.16), AppTheme.vividPurple.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if quickSelectedDocumentID == nil {
                quickSelectedDocumentID = model.documents.first?.id
                syncQuickCategory()
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DocumentOrganizer")
                .font(.headline.weight(.semibold))
            Text("\(model.totalDocuments) documents \u{00b7} \(model.activeCategoryCount) categories")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Open Organizer") { openMainWindow() }
            Button("Import Documents") { model.importDocumentsFromOpenPanel() }
            Button("Refresh") { model.refresh() }
        }
    }

    private var recentDocuments: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Documents")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.documents.isEmpty {
                Text("No documents imported yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.documents.prefix(5))) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.fileName)
                            .font(.subheadline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.riskColor(for: record.effectiveCategory))
                                .frame(width: 8, height: 8)
                            Text(record.effectiveCategory.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(model.riskColor(for: record.effectiveCategory))
                            Text("\u{00b7} \(model.sensitivityLabel(for: record.effectiveCategory))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var quickReview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Review")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Document", selection: Binding(
                get: { quickSelectedDocumentID ?? model.documents.first?.id },
                set: { quickSelectedDocumentID = $0; syncQuickCategory() }
            )) {
                ForEach(Array(model.documents.prefix(8))) { record in
                    Text(record.fileName).tag(Optional(record.id))
                }
            }
            .pickerStyle(.menu)

            if let selected = selectedQuickDocument {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.riskColor(for: selected.effectiveCategory))
                        .frame(width: 9, height: 9)
                    Text("Sensitivity: \(model.sensitivityLabel(for: selected.effectiveCategory))")
                        .font(.caption)
                        .foregroundStyle(model.riskColor(for: selected.effectiveCategory))
                }
                Text(selected.contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                Picker("Category", selection: $quickSelectedCategory) {
                    ForEach(DocumentCategory.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }
                .pickerStyle(.menu)
                Button("Apply Category") {
                    model.recategorize(documentID: selected.id, to: quickSelectedCategory, reason: quickReason)
                    syncQuickCategory()
                }
            }
        }
    }

    private var autoOrganization: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Auto-Organization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { model.isFolderWatchingEnabled },
                    set: { _ in model.toggleFolderWatching() }
                ))
                .scaleEffect(0.8, anchor: .trailing)
            }

            if model.isFolderWatchingEnabled {
                Text(model.watchedFoldersSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !model.folderStatistics.isEmpty {
                    ForEach(model.folderStatistics, id: \.category) { stat in
                        HStack {
                            Text(stat.category.rawValue.capitalized).font(.caption2)
                            Spacer()
                            Text("\(stat.fileCount) file\(stat.fileCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Reveal Organized Files") { model.revealOrganizationFolder() }
                    .font(.caption)
                    .controlSize(.small)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Settings\u{2026}", systemImage: "gearshape") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: Helpers

    private var selectedQuickDocument: DocumentRecord? {
        guard let id = quickSelectedDocumentID else { return model.documents.first }
        return model.documents.first { $0.id == id }
    }

    private func syncQuickCategory() {
        quickSelectedCategory = selectedQuickDocument?.effectiveCategory ?? .general
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// MARK: - ViewModel

@MainActor
final class DocumentOrganizerViewModel: ObservableObject {

    // MARK: Published State

    @Published var documents: [DocumentRecord] = []
    @Published var selectedDocumentID: UUID?
    @Published var selectedCategory: DocumentCategory = .general
    @Published var searchQuery = ""
    @Published var recategorizationReason = "Updated after user review"
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isFolderWatchingEnabled = false
    @Published var folderStatistics: [CategoryStatistic] = []
    @Published var organizationRoot: URL?
    @Published var storageAvailable = "—"
    @Published var storageTotal = "—"
    @Published var isNetworkConnected = false

    // MARK: Private State

    private var facade: DocumentOrganizerFacade?
    private var snapshot: DashboardSnapshot?
    private var fileSystemWatcher: FileSystemWatcher?
    private var fileOrganizer: FileOrganizer?
    private var securityScopedOrganizationRoot: URL?

    // MARK: Init / Deinit

    init() {
        do {
            facade = try DocumentOrganizerFacade()
            refresh()
            updateDeviceMetrics()
            if AppSettings.shared.autoStartWatching { startFolderWatching() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        securityScopedOrganizationRoot?.stopAccessingSecurityScopedResource()
    }

    // MARK: Computed Properties

    var filteredDocuments: [DocumentRecord] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return documents }
        return documents.filter {
            $0.fileName.lowercased().contains(q)
            || $0.contentPreview.lowercased().contains(q)
            || $0.effectiveCategory.rawValue.lowercased().contains(q)
        }
    }

    var selectedDocument: DocumentRecord? {
        guard let id = selectedDocumentID else { return nil }
        return documents.first { $0.id == id }
    }

    var totalDocuments: Int { snapshot?.totalDocuments ?? documents.count }
    var activeCategoryCount: Int { (snapshot?.categoryBreakdown ?? []).filter { $0.count > 0 }.count }
    var isStateHealthy: Bool { facade?.stateHealthReport().healthy ?? false }
    var stateLocationText: String { facade?.appStateURL().path ?? "Unavailable" }

    var watchedFoldersSummary: String {
        let names = AppSettings.shared.watchedDirectories.map(\.lastPathComponent)
        return names.isEmpty ? "Watching: none" : "Watching: \(names.joined(separator: ", "))"
    }

    // MARK: Document Actions

    func refresh() {
        guard let facade else { return }
        documents = facade.listDocuments()
        snapshot = facade.dashboardSnapshot()
        if let id = selectedDocumentID, !documents.contains(where: { $0.id == id }) {
            selectedDocumentID = nil
        }
        syncSelectedCategory()
    }

    func importDocumentsFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = supportedImportTypes
        if panel.runModal() == .OK { importDocuments(from: panel.urls) }
    }

    func importFolderFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Import"
        if panel.runModal() == .OK { importDocuments(fromFolders: panel.urls) }
    }

    func importDocuments(fromFolders folderURLs: [URL]) {
        let filesToImport = folderURLs.flatMap { collectImportableFiles(in: $0) }
        guard !filesToImport.isEmpty else {
            errorMessage = "No supported files were found in the selected folder(s)."
            return
        }

        importDocuments(
            from: filesToImport,
            summarySuffix: "from \(folderURLs.count) folder(s)"
        )
    }

    func importDocuments(from urls: [URL], summarySuffix: String? = nil) {
        guard let facade else { return }
        do {
            let imported = try facade.importDocuments(paths: urls.map(\.path))
            refresh()
            if imported.isEmpty {
                successMessage = "No documents were imported."
            } else {
                let note = summarySuffix.map { " \($0)" } ?? ""
                successMessage = "Imported \(imported.count) document(s).\(note)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDocuments(fromDroppedProviders providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let collector = ThreadSafeURLCollector()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    collector.append(url)
                } else if let url = item as? URL {
                    collector.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            let fileURLs = collector.values().filter { $0.isFileURL }
            guard !fileURLs.isEmpty else {
                self.errorMessage = "Dropped items did not contain importable file URLs."
                return
            }

            var accepted: [URL] = []
            var skippedDirs = 0
            var skippedUnsupported = 0

            for url in fileURLs {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { skippedDirs += 1; continue }
                if self.supportedImportExtensions.contains(url.pathExtension.lowercased()) {
                    accepted.append(url)
                } else {
                    skippedUnsupported += 1
                }
            }

            guard !accepted.isEmpty else {
                self.errorMessage = "No dropped files were importable (skipped \(skippedDirs) dir(s), \(skippedUnsupported) unsupported)."
                return
            }

            var notes: [String] = []
            if skippedDirs > 0 { notes.append("skipped \(skippedDirs) dir(s)") }
            if skippedUnsupported > 0 { notes.append("skipped \(skippedUnsupported) unsupported") }
            self.importDocuments(from: accepted, summarySuffix: notes.isEmpty ? nil : notes.joined(separator: "; "))
        }

        return true
    }

    func recategorizeSelectedDocument() {
        guard let facade, let doc = selectedDocument else { return }
        do {
            _ = try facade.recategorize(documentID: doc.id, to: selectedCategory, reason: recategorizationReason)
            refresh()
            successMessage = "Updated category for \(doc.fileName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recategorize(documentID: UUID, to category: DocumentCategory, reason: String) {
        guard let facade else { return }
        do {
            _ = try facade.recategorize(documentID: documentID, to: category, reason: reason)
            refresh()
            successMessage = documents.first(where: { $0.id == documentID })
                .map { "Updated category for \($0.fileName)." } ?? "Updated document category."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedDocument() {
        guard let facade, let doc = selectedDocument else { return }
        do {
            try facade.deleteDocument(documentID: doc.id)
            refresh()
            successMessage = "Deleted \(doc.fileName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncSelectedCategory() {
        selectedCategory = selectedDocument?.effectiveCategory ?? .general
    }

    // MARK: Risk & Sensitivity

    func riskColor(for category: DocumentCategory) -> Color {
        switch category {
        case .medical, .legal, .identification:  return AppTheme.riskHigh
        case .finance, .invoice, .contract:      return AppTheme.riskMedium
        case .education, .resume:                return AppTheme.riskLow
        case .correspondence, .general:          return AppTheme.riskMinimal
        }
    }

    func sensitivityLabel(for category: DocumentCategory) -> String {
        switch category {
        case .medical, .legal, .identification:  return "High"
        case .finance, .invoice, .contract:      return "Medium"
        case .education, .resume:                return "Low"
        case .correspondence, .general:          return "Minimal"
        }
    }

    // MARK: Folder Watching

    func toggleFolderWatching() {
        isFolderWatchingEnabled ? stopFolderWatching() : startFolderWatching()
    }

    func startFolderWatching() {
        let settings = AppSettings.shared
        let watchedDirs = settings.watchedDirectories

        guard !watchedDirs.isEmpty else {
            errorMessage = "No folders selected. Go to Settings \u{2192} Watching."
            return
        }

        let orgRoot = settings.resolvedOrganizationRoot
        var startedScope = false
        if settings.organizationRootBookmark != nil {
            startedScope = orgRoot.startAccessingSecurityScopedResource()
            guard startedScope else {
                errorMessage = "Unable to access the organization folder. Re-select it in Settings > Storage."
                return
            }
            securityScopedOrganizationRoot = orgRoot
        }

        do {
            let watcher = FileSystemWatcher()
            watcher.setOnFilesAdded { [weak self] urls in
                DispatchQueue.main.async { self?.processNewFiles(urls) }
            }
            let organizer = FileOrganizer(organizationRoot: orgRoot)
            for dir in watchedDirs { try watcher.startWatching(directory: dir) }

            fileSystemWatcher = watcher
            fileOrganizer = organizer
            organizationRoot = orgRoot
            isFolderWatchingEnabled = true
            successMessage = "Watching: \(watchedDirs.map(\.lastPathComponent).joined(separator: ", "))."
            updateFolderStatistics()
        } catch {
            if startedScope {
                orgRoot.stopAccessingSecurityScopedResource()
                securityScopedOrganizationRoot = nil
            }
            errorMessage = "Failed to start watching: \(error.localizedDescription)"
            isFolderWatchingEnabled = false
        }
    }

    func stopFolderWatching() {
        fileSystemWatcher?.stopAll()
        fileSystemWatcher = nil
        securityScopedOrganizationRoot?.stopAccessingSecurityScopedResource()
        securityScopedOrganizationRoot = nil
        isFolderWatchingEnabled = false
        successMessage = "Stopped watching folders."
    }

    func updateFolderStatistics() {
        guard let organizer = fileOrganizer else { return }
        do {
            folderStatistics = try organizer.folderStatistics()
        } catch {
            errorMessage = "Failed to update folder statistics: \(error.localizedDescription)"
        }
    }

    func revealOrganizationFolder() {
        guard let organizationRoot else { errorMessage = "Organization folder not available."; return }
        NSWorkspace.shared.open(organizationRoot)
        successMessage = "Opened organization folder."
    }

    private func processNewFiles(_ urls: [URL]) {
        guard let facade, let organizer = fileOrganizer else { return }

        var organized = 0, duplicates = 0, failures = 0

        for sourceURL in urls {
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }
            do {
                guard let record = try facade.importDocuments(paths: [sourceURL.path]).first else { continue }
                let isDuplicate = URL(fileURLWithPath: record.filePath).standardizedFileURL != sourceURL.standardizedFileURL
                if isDuplicate { duplicates += 1; continue }
                let dest = try organizer.organize(file: sourceURL, document: record)
                _ = try facade.updateDocumentFilePath(documentID: record.id, to: dest.path, actor: "system")
                organized += 1
            } catch {
                failures += 1
                print("Failed to organize \(sourceURL.lastPathComponent): \(error)")
            }
        }

        refresh()
        updateFolderStatistics()

        if organized > 0 || duplicates > 0 {
            var parts = ["Auto-organized \(organized) document(s)"]
            if duplicates > 0 { parts.append("skipped \(duplicates) duplicate(s)") }
            if failures > 0   { parts.append("\(failures) failed") }
            successMessage = parts.joined(separator: "; ") + "."
        } else if failures > 0 {
            errorMessage = "Failed to organize \(failures) file(s)."
        }
    }

    // MARK: Supported Types

    private var supportedImportTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .pdf, .rtf, .image, .json, .xml]
        for ext in ["html", "docx", "csv", "md"] {
            if let t = UTType(filenameExtension: ext) { types.append(t) }
        }
        return types
    }

    private var supportedImportExtensions: Set<String> {
        ["txt", "md", "csv", "rtf", "json", "xml", "html", "pdf", "docx",
         "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "gif", "bmp"]
    }

    private func collectImportableFiles(in folderURL: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }
            if supportedImportExtensions.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
        }
        return files
    }

    // MARK: Thread-Safe URL Collector

    private final class ThreadSafeURLCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [URL] = []
        func append(_ url: URL) { lock.lock(); storage.append(url); lock.unlock() }
        func values() -> [URL] { lock.lock(); defer { lock.unlock() }; return storage }
    }

    // MARK: Device Metrics

    private func updateDeviceMetrics() {
        let fileManager = FileManager.default
        
        // Storage info
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            let totalSpace = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let freeSpace = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            storageTotal = formatBytes(totalSpace)
            storageAvailable = formatBytes(freeSpace)
        }
        
        // Network connectivity check
        isNetworkConnected = checkNetworkConnectivity()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }

    private func checkNetworkConnectivity() -> Bool {
        var flags: SCNetworkReachabilityFlags = []
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com") else { return false }
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
}
