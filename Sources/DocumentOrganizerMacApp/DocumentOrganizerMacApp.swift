import AppleAppCore
import AppKit
import Core
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension DocumentRecord: Identifiable {}

@main
struct DocumentOrganizerMacApp: App {
    @StateObject private var model = DocumentOrganizerViewModel()
    @State private var isDropTargeted = false

    var body: some Scene {
        WindowGroup("DocumentOrganizer", id: "main-window") {
            ZStack {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                NavigationSplitView {
                    sidebar
                } detail: {
                    detail
                }
                .frame(minWidth: 980, minHeight: 620)
                .searchable(text: $model.searchQuery, prompt: "Search documents")
                .toolbar {
                    ToolbarItemGroup {
                        Button("Import") {
                            model.importDocumentsFromOpenPanel()
                        }

                        Button("Refresh") {
                            model.refresh()
                        }

                        Button("Delete") {
                            model.deleteSelectedDocument()
                        }
                        .disabled(model.selectedDocument == nil)

                        Divider()

                        Button("Settings", systemImage: "gearshape") {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        }
                    }
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .foregroundStyle(Color.accentColor)
                        .padding(18)

                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 34, weight: .semibold))
                        Text("Drop files to import")
                            .font(.headline)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                model.importDocuments(fromDroppedProviders: providers)
            }
            .alert(
                "DocumentOrganizer Error",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            model.errorMessage = nil
                        }
                    }
                ),
                actions: {
                    Button("OK", role: .cancel) {
                        model.errorMessage = nil
                    }
                },
                message: {
                    Text(model.errorMessage ?? "Unknown error")
                }
            )
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }

        MenuBarExtra("DocumentOrganizer", systemImage: "menubar.dock.rectangle") {
            MenuBarDashboardView(model: model)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            metricsPanel

            if let successMessage = model.successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.mint.opacity(0.12), in: Capsule())
            }

            List(model.filteredDocuments, selection: $model.selectedDocumentID) { record in
                documentRow(record)
                .tag(record.id)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .overlay {
                if model.filteredDocuments.isEmpty {
                    emptyState(
                        title: "No Documents",
                        systemImage: "doc.text.magnifyingglass",
                        description: "Import files to build a local, privacy-first document index."
                    )
                }
            }
        }
        .padding()
    }

    private var detail: some View {
        Group {
            if let record = model.selectedDocument {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.fileName)
                                .font(.largeTitle)
                                .bold()
                            Text(record.filePath)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        HStack(spacing: 18) {
                            infoChip(title: "Category", value: record.effectiveCategory.rawValue.capitalized)
                            infoChip(title: "Confidence", value: String(format: "%.0f%%", record.categoryResult.confidence * 100))
                            infoChip(title: "Imported", value: record.importedAt.formatted(date: .abbreviated, time: .shortened))
                        }

                        premiumPanel("Why it was categorized this way") {
                            Text(record.categoryResult.explanation)
                                .foregroundStyle(.secondary)
                        }

                        premiumPanel("Preview") {
                            Text(record.contentPreview)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        }

                        premiumPanel("Manual Review") {
                            Picker("Category", selection: $model.selectedCategory) {
                                ForEach(DocumentCategory.allCases, id: \.self) { category in
                                    Text(category.rawValue.capitalized).tag(category)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("Reason for recategorization", text: $model.recategorizationReason)

                            Button("Apply Category Update") {
                                model.recategorizeSelectedDocument()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.selectedDocument == nil)
                        }

                        premiumPanel("State Storage") {
                            Text(model.stateLocationText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(24)
                }
            } else {
                emptyState(
                    title: "Select a Document",
                    systemImage: "doc.richtext",
                    description: "Choose a document from the sidebar to inspect its category, preview, and review actions."
                )
            }
        }
        .onChange(of: model.selectedDocumentID) { _ in
            model.syncSelectedCategory()
        }
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Organizer Overview")
                        .font(.title3.weight(.semibold))
                    Text("Local-first intelligence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(model.isStateHealthy ? Color.mint.opacity(0.2) : Color.orange.opacity(0.2))
                    .overlay(
                        Image(systemName: model.isStateHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(model.isStateHealthy ? .mint : .orange)
                    )
                    .frame(width: 28, height: 28)
            }

            HStack(spacing: 12) {
                metricCard(title: "Documents", value: String(model.totalDocuments))
                metricCard(title: "Categories", value: String(model.activeCategoryCount))
                metricCard(title: "Healthy", value: model.isStateHealthy ? "Yes" : "No")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Folder Organization")
                        .font(.subheadline)
                        .bold()

                    Spacer()

                    Button(model.isFolderWatchingEnabled ? "Disable" : "Enable") {
                        model.toggleFolderWatching()
                    }
                    .font(.caption)
                    .controlSize(.small)
                }

                if model.isFolderWatchingEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Organized Files")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if model.folderStatistics.isEmpty {
                            Text("No organized files yet")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(model.folderStatistics, id: \.category) { stat in
                                    HStack {
                                        Circle()
                                            .fill(model.riskColor(for: stat.category))
                                            .frame(width: 8, height: 8)

                                        Text(stat.category.rawValue.capitalized)
                                            .font(.caption)

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(stat.fileCount) file\(stat.fileCount == 1 ? "" : "s")")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            Text(stat.totalSizeString)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }

                        if let root = model.organizationRoot {
                            Button("Open Organization Folder", systemImage: "folder") {
                                NSWorkspace.shared.open(root)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    private func emptyState(title: String, systemImage: String, description: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func premiumPanel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func documentRow(_ record: DocumentRecord) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(model.riskColor(for: record.effectiveCategory))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.fileName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(record.effectiveCategory.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.importedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MenuBarDashboardView: View {
    @ObservedObject var model: DocumentOrganizerViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var quickSelectedDocumentID: UUID?
    @State private var quickSelectedCategory: DocumentCategory = .general
    @State private var quickReason = "Updated from menu bar"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DocumentOrganizer")
                    .font(.headline.weight(.semibold))
                Text("\(model.totalDocuments) documents across \(model.activeCategoryCount) active categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Open Organizer") {
                    openMainWindow()
                }

                Button("Import Documents") {
                    model.importDocumentsFromOpenPanel()
                }

                Button("Refresh") {
                    model.refresh()
                }
            }

            Divider()

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

                                Text("• \(model.sensitivityLabel(for: record.effectiveCategory))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !model.documents.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Review")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Document", selection: Binding(
                        get: { quickSelectedDocumentID ?? model.documents.first?.id },
                        set: { newValue in
                            quickSelectedDocumentID = newValue
                            syncQuickCategoryWithSelection()
                        }
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
                            ForEach(DocumentCategory.allCases, id: \.self) { category in
                                Text(category.rawValue.capitalized).tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        Button("Apply Category") {
                            model.recategorize(documentID: selected.id, to: quickSelectedCategory, reason: quickReason)
                            syncQuickCategoryWithSelection()
                        }
                    }
                }
            }

            Divider()

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Watching: Downloads, Desktop")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if !model.folderStatistics.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(model.folderStatistics, id: \.category) { stat in
                                    HStack {
                                        Text(stat.category.rawValue.capitalized)
                                            .font(.caption2)
                                        Spacer()
                                        Text("\(stat.fileCount) file\(stat.fileCount == 1 ? "" : "s")")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Button("Reveal Organized Files") {
                            model.revealOrganizationFolder()
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }
                }
            }

            Divider()

            Divider()

            Button("Settings…", systemImage: "gearshape") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear {
            if quickSelectedDocumentID == nil {
                quickSelectedDocumentID = model.documents.first?.id
                syncQuickCategoryWithSelection()
            }
        }
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private var selectedQuickDocument: DocumentRecord? {
        guard let quickSelectedDocumentID else {
            return model.documents.first
        }
        return model.documents.first { $0.id == quickSelectedDocumentID }
    }

    private func syncQuickCategoryWithSelection() {
        if let selectedQuickDocument {
            quickSelectedCategory = selectedQuickDocument.effectiveCategory
        }
    }
}

@MainActor
final class DocumentOrganizerViewModel: ObservableObject {
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

    private var facade: DocumentOrganizerFacade?
    private var snapshot: DashboardSnapshot?
    private var healthDescription = "Unavailable"
    private var fileSystemWatcher: FileSystemWatcher?
    private var fileOrganizer: FileOrganizer?
    private var securityScopedOrganizationRoot: URL?

    private final class ThreadSafeURLCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [URL] = []

        func append(_ url: URL) {
            lock.lock()
            storage.append(url)
            lock.unlock()
        }

        func values() -> [URL] {
            lock.lock()
            let copy = storage
            lock.unlock()
            return copy
        }
    }

    init() {
        do {
            facade = try DocumentOrganizerFacade()
            refresh()
            if AppSettings.shared.autoStartWatching {
                startFolderWatching()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        if let securityScopedOrganizationRoot {
            securityScopedOrganizationRoot.stopAccessingSecurityScopedResource()
        }
    }

    var filteredDocuments: [DocumentRecord] {
        let normalized = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return documents
        }

        return documents.filter { record in
            record.fileName.lowercased().contains(normalized)
                || record.contentPreview.lowercased().contains(normalized)
                || record.effectiveCategory.rawValue.lowercased().contains(normalized)
        }
    }

    var selectedDocument: DocumentRecord? {
        guard let selectedDocumentID else {
            return nil
        }
        return documents.first { $0.id == selectedDocumentID }
    }

    var totalDocuments: Int {
        snapshot?.totalDocuments ?? documents.count
    }

    var activeCategoryCount: Int {
        (snapshot?.categoryBreakdown ?? []).filter { $0.count > 0 }.count
    }

    var isStateHealthy: Bool {
        facade?.stateHealthReport().healthy ?? false
    }

    var stateLocationText: String {
        facade?.appStateURL().path ?? healthDescription
    }

    func refresh() {
        guard let facade else {
            return
        }

        documents = facade.listDocuments()
        snapshot = facade.dashboardSnapshot()
        healthDescription = facade.appStateURL().path

        if let selectedDocumentID,
           !documents.contains(where: { $0.id == selectedDocumentID }) {
            self.selectedDocumentID = nil
        }

        syncSelectedCategory()
    }

    func importDocuments(from urls: [URL], summarySuffix: String? = nil) {
        guard let facade else {
            return
        }

        do {
            let imported = try facade.importDocuments(paths: urls.map(\.path))
            refresh()
            if imported.isEmpty {
                successMessage = "No documents were imported."
            } else if let summarySuffix {
                successMessage = "Imported \(imported.count) document(s). \(summarySuffix)"
            } else {
                successMessage = "Imported \(imported.count) document(s)."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDocumentsFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = supportedImportTypes

        if panel.runModal() == .OK {
            importDocuments(from: panel.urls)
        }
    }

    func importDocuments(fromDroppedProviders providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let collector = ThreadSafeURLCollector()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    collector.append(url)
                    return
                }

                if let url = item as? URL {
                    collector.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            let droppedFileURLs = collector.values().filter { $0.isFileURL }
            if droppedFileURLs.isEmpty {
                self.errorMessage = "Dropped items did not contain importable file URLs."
                return
            }

            var accepted: [URL] = []
            var skippedDirectories = 0
            var skippedUnsupported = 0

            for fileURL in droppedFileURLs {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    skippedDirectories += 1
                    continue
                }

                let ext = fileURL.pathExtension.lowercased()
                if self.supportedImportExtensions.contains(ext) {
                    accepted.append(fileURL)
                } else {
                    skippedUnsupported += 1
                }
            }

            if accepted.isEmpty {
                self.errorMessage = "No dropped files were importable. Skipped \(skippedDirectories) director\(skippedDirectories == 1 ? "y" : "ies") and \(skippedUnsupported) unsupported file(s)."
                return
            }

            var notes: [String] = []
            if skippedDirectories > 0 {
                notes.append("skipped \(skippedDirectories) director\(skippedDirectories == 1 ? "y" : "ies")")
            }
            if skippedUnsupported > 0 {
                notes.append("skipped \(skippedUnsupported) unsupported file(s)")
            }

            let suffix = notes.isEmpty ? nil : notes.joined(separator: "; ") + "."
            self.importDocuments(from: accepted, summarySuffix: suffix)
        }

        return true
    }

    func recategorizeSelectedDocument() {
        guard let facade, let selectedDocument else {
            return
        }

        do {
            _ = try facade.recategorize(
                documentID: selectedDocument.id,
                to: selectedCategory,
                reason: recategorizationReason
            )
            refresh()
            successMessage = "Updated category for \(selectedDocument.fileName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recategorize(documentID: UUID, to category: DocumentCategory, reason: String) {
        guard let facade else {
            return
        }

        do {
            _ = try facade.recategorize(documentID: documentID, to: category, reason: reason)
            refresh()
            if let updated = documents.first(where: { $0.id == documentID }) {
                successMessage = "Updated category for \(updated.fileName)."
            } else {
                successMessage = "Updated document category."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedDocument() {
        guard let facade, let selectedDocument else {
            return
        }

        do {
            try facade.deleteDocument(documentID: selectedDocument.id)
            refresh()
            successMessage = "Deleted \(selectedDocument.fileName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncSelectedCategory() {
        guard let selectedDocument else {
            return
        }
        selectedCategory = selectedDocument.effectiveCategory
    }

    private var supportedImportTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .pdf, .rtf, .image, .json, .xml]
        if let html = UTType(filenameExtension: "html") {
            types.append(html)
        }
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        if let csv = UTType(filenameExtension: "csv") {
            types.append(csv)
        }
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        return types
    }

    private var supportedImportExtensions: Set<String> {
        ["txt", "md", "csv", "rtf", "json", "xml", "html", "pdf", "docx", "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "gif", "bmp"]
    }

    func riskColor(for category: DocumentCategory) -> Color {
        switch category {
        case .medical, .legal, .identification:
            return .red
        case .finance, .invoice, .contract:
            return .orange
        case .education, .resume:
            return .yellow
        case .correspondence, .general:
            return .green
        }
    }

    func sensitivityLabel(for category: DocumentCategory) -> String {
        switch category {
        case .medical, .legal, .identification:
            return "High"
        case .finance, .invoice, .contract:
            return "Medium"
        case .education, .resume:
            return "Low"
        case .correspondence, .general:
            return "Minimal"
        }
    }

    // MARK: - Folder Watching & Organization

    func toggleFolderWatching() {
        if isFolderWatchingEnabled {
            stopFolderWatching()
        } else {
            startFolderWatching()
        }
    }

    func startFolderWatching() {
        let s = AppSettings.shared
        let watchedDirs = s.watchedDirectories

        guard !watchedDirs.isEmpty else {
            errorMessage = "No folders selected for watching. Go to Settings → Watching to enable at least one folder."
            return
        }

        let resolvedOrganizationRoot = s.resolvedOrganizationRoot
        var startedSecurityScope = false
        if s.organizationRootBookmark != nil {
            startedSecurityScope = resolvedOrganizationRoot.startAccessingSecurityScopedResource()
            guard startedSecurityScope else {
                errorMessage = "Unable to access the selected organization folder. Re-select it in Settings > Storage."
                return
            }
            securityScopedOrganizationRoot = resolvedOrganizationRoot
        }

        do {
            fileSystemWatcher = FileSystemWatcher()
            fileOrganizer = FileOrganizer(organizationRoot: resolvedOrganizationRoot)

            organizationRoot = resolvedOrganizationRoot

            for dir in watchedDirs {
                try fileSystemWatcher?.startWatching(directory: dir)
            }

            fileSystemWatcher?.setOnFilesAdded { [weak self] urls in
                DispatchQueue.main.async {
                    self?.processNewFiles(urls)
                }
            }

            isFolderWatchingEnabled = true
            let folderNames = watchedDirs.map(\.lastPathComponent).joined(separator: ", ")
            successMessage = "Watching: \(folderNames)."
            updateFolderStatistics()
        } catch {
            if startedSecurityScope {
                resolvedOrganizationRoot.stopAccessingSecurityScopedResource()
                securityScopedOrganizationRoot = nil
            }
            errorMessage = "Failed to start folder watching: \(error.localizedDescription)"
            isFolderWatchingEnabled = false
        }
    }

    func stopFolderWatching() {
        fileSystemWatcher?.stopAll()
        fileSystemWatcher = nil
        if let securityScopedOrganizationRoot {
            securityScopedOrganizationRoot.stopAccessingSecurityScopedResource()
            self.securityScopedOrganizationRoot = nil
        }
        isFolderWatchingEnabled = false
        successMessage = "Stopped watching folders."
    }

    private func processNewFiles(_ urls: [URL]) {
        guard let facade, let organizer = fileOrganizer else {
            return
        }

        do {
            let imported = try facade.importDocuments(paths: urls.map(\.path))

            for document in imported {
                do {
                    let sourceURL = URL(fileURLWithPath: document.filePath)
                    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                        continue
                    }

                    let organizedURL = try organizer.organize(file: sourceURL, document: document)
                    _ = try facade.updateDocumentFilePath(
                        documentID: document.id,
                        to: organizedURL.path,
                        actor: "system"
                    )
                } catch {
                    print("Failed to organize file: \(error)")
                }
            }

            refresh()
            updateFolderStatistics()
            if !imported.isEmpty {
                successMessage = "Auto-organized \(imported.count) new document(s)."
            }
        } catch {
            errorMessage = "Failed to organize new files: \(error.localizedDescription)"
        }
    }

    func updateFolderStatistics() {
        guard let organizer = fileOrganizer else {
            return
        }

        do {
            folderStatistics = try organizer.folderStatistics()
        } catch {
            errorMessage = "Failed to update folder statistics: \(error.localizedDescription)"
        }
    }

    func revealOrganizationFolder() {
        guard let organizationRoot else {
            errorMessage = "Organization folder path not available."
            return
        }

        NSWorkspace.shared.open(organizationRoot)
        successMessage = "Opened organization folder."
    }
}