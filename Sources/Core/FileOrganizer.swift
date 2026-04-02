import Foundation

/// Organizes files into category-based folder structures with intelligent naming.
public struct FileOrganizer {
    private let organizationRoot: URL
    private let dateFormatter: DateFormatter

    public init(organizationRoot: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.organizationRoot = organizationRoot
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    /// Organize a document by moving it to category-based folder and renaming it.
    public func organize(file: URL, document: DocumentRecord) throws -> URL {
        let categoryFolder = organizationRoot.appendingPathComponent(document.effectiveCategory.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: categoryFolder, withIntermediateDirectories: true)

        let newFileName = generateFileName(for: document, originalFile: file)
        let requestedPath = categoryFolder.appendingPathComponent(newFileName)

        // If file is being moved to same location, skip
        if file.standardizedFileURL == requestedPath.standardizedFileURL {
            return requestedPath
        }

        let destinationPath = uniqueDestinationURL(for: requestedPath, source: file)

        try FileManager.default.moveItem(at: file, to: destinationPath)
        return destinationPath
    }

    /// Generate an organized filename following: [Category]-[Date]-[OriginalName]
    private func generateFileName(for document: DocumentRecord, originalFile: URL) -> String {
        let dateString = dateFormatter.string(from: document.importedAt)
        let baseFileName = originalFile.deletingPathExtension().lastPathComponent
        let fileExtension = originalFile.pathExtension

        let sanitizedBase = baseFileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(60) // Limit length

        let organisedName = "\(document.effectiveCategory.rawValue)-\(dateString)-\(sanitizedBase)"

        return fileExtension.isEmpty ? String(organisedName) : "\(organisedName).\(fileExtension)"
    }

    private func uniqueDestinationURL(for requestedURL: URL, source: URL) -> URL {
        if !FileManager.default.fileExists(atPath: requestedURL.path) {
            return requestedURL
        }

        if source.standardizedFileURL == requestedURL.standardizedFileURL {
            return requestedURL
        }

        let directory = requestedURL.deletingLastPathComponent()
        let baseName = requestedURL.deletingPathExtension().lastPathComponent
        let ext = requestedURL.pathExtension

        var counter = 2
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(baseName)-\(counter)"
            } else {
                candidateName = "\(baseName)-\(counter).\(ext)"
            }

            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    /// Get the assigned folder path for a category.
    public func folderPath(for category: DocumentCategory) -> URL {
        organizationRoot.appendingPathComponent(category.rawValue, isDirectory: true)
    }

    /// List all organized documents in a folder.
    public func listOrganizedFiles(in category: DocumentCategory? = nil) throws -> [URL] {
        let searchPath: URL
        if let category = category {
            searchPath = folderPath(for: category)
        } else {
            searchPath = organizationRoot
        }

        guard FileManager.default.fileExists(atPath: searchPath.path) else {
            return []
        }

        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: searchPath, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                    files.append(fileURL)
                }
            }
        }
        return files
    }

    /// Get folder statistics for dashboard.
    public func folderStatistics() throws -> [CategoryStatistic] {
        var stats: [CategoryStatistic] = []

        for category in DocumentCategory.allCases {
            let path = folderPath(for: category)
            var fileCount = 0
            var totalSize: Int64 = 0

            if FileManager.default.fileExists(atPath: path.path),
               let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                        fileCount += 1
                        if let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let size = resources.fileSize {
                            totalSize += Int64(size)
                        }
                    }
                }
            }

            if fileCount > 0 {
                stats.append(CategoryStatistic(category: category, fileCount: fileCount, totalSizeBytes: totalSize))
            }
        }

        return stats.sorted { $0.fileCount > $1.fileCount }
    }
}

public struct CategoryStatistic {
    public let category: DocumentCategory
    public let fileCount: Int
    public let totalSizeBytes: Int64

    public var totalSizeString: String {
        let bytes = Double(totalSizeBytes)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
}
