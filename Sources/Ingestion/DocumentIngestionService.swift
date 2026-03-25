import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(Vision)
import Vision
#endif

public protocol DocumentIngestionProviding {
    func extractText(from fileURL: URL) throws -> String
}

public enum DocumentIngestionError: Error, LocalizedError {
    case unsupportedFileType(String)
    case unreadableData
    case ocrUnavailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported file type: \(ext)"
        case .unreadableData:
            return "Unable to decode file data as text."
        case .ocrUnavailable:
            return "OCR is unavailable on this platform for image documents."
        }
    }
}

public struct DocumentIngestionService: DocumentIngestionProviding {
    private let supportedExtensions: Set<String> = [
        "txt", "md", "csv", "rtf", "json", "xml", "html", "pdf", "docx",
        "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "gif", "bmp"
    ]

    public init() {}

    public func extractText(from fileURL: URL) throws -> String {
        let ext = fileURL.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw DocumentIngestionError.unsupportedFileType(ext)
        }

        if ext == "pdf" {
            return try extractPDFText(from: fileURL)
        }

        if ext == "docx" {
            return try extractDOCXText(from: fileURL)
        }

        if isImageExtension(ext) {
            return try extractImageText(from: fileURL)
        }

        guard let rawData = FileManager.default.contents(atPath: fileURL.path) else {
            throw DocumentIngestionError.unreadableData
        }

        if let utf8Text = String(data: rawData, encoding: .utf8) {
            return utf8Text
        }

        if let utf16Text = String(data: rawData, encoding: .utf16) {
            return utf16Text
        }

        if let isoText = String(data: rawData, encoding: .isoLatin1) {
            return isoText
        }

        throw DocumentIngestionError.unreadableData
    }

    private func extractPDFText(from fileURL: URL) throws -> String {
#if canImport(PDFKit)
        guard let pdf = PDFDocument(url: fileURL) else {
            throw DocumentIngestionError.unreadableData
        }
        var pages: [String] = []
        for index in 0 ..< pdf.pageCount {
            if let page = pdf.page(at: index), let text = page.string {
                pages.append(text)
            }
        }
        let full = pages.joined(separator: "\n")
        if full.isEmpty {
            throw DocumentIngestionError.unreadableData
        }
        return full
#else
        throw DocumentIngestionError.unsupportedFileType("pdf (PDFKit unavailable on this platform)")
#endif
    }

    private func extractDOCXText(from fileURL: URL) throws -> String {
#if os(macOS)
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", fileURL.path, "word/document.xml"]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw DocumentIngestionError.unreadableData
        }

        guard process.terminationStatus == 0 else {
            throw DocumentIngestionError.unreadableData
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else {
            throw DocumentIngestionError.unreadableData
        }

        let xml = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
        guard let xml else {
            throw DocumentIngestionError.unreadableData
        }

        let text = normalizeDOCXDocumentXML(xml)
        guard !text.isEmpty else {
            throw DocumentIngestionError.unreadableData
        }

        return text
#else
        throw DocumentIngestionError.unsupportedFileType("docx (available on macOS only)")
#endif
    }

    private func normalizeDOCXDocumentXML(_ xml: String) -> String {
        var normalized = xml
        let tokenReplacements = [
            ("<w:tab/>", "\t"),
            ("<w:br/>", "\n"),
            ("</w:p>", "\n")
        ]

        for (token, replacement) in tokenReplacements {
            normalized = normalized.replacingOccurrences(of: token, with: replacement)
        }

        normalized = normalized.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'"
        ]
        for (entity, replacement) in entities {
            normalized = normalized.replacingOccurrences(of: entity, with: replacement)
        }

        let lines = normalized
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    private func isImageExtension(_ ext: String) -> Bool {
        ["png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "gif", "bmp"].contains(ext)
    }

    private func extractImageText(from fileURL: URL) throws -> String {
#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(Vision)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DocumentIngestionError.unreadableData
        }

        var recognizedStrings: [String] = []
        let request = VNRecognizeTextRequest { request, error in
            if error != nil {
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    recognizedStrings.append(candidate.string)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw DocumentIngestionError.unreadableData
        }

        let text = recognizedStrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if text.isEmpty {
            throw DocumentIngestionError.unreadableData
        }

        return text
#else
        throw DocumentIngestionError.ocrUnavailable
#endif
    }
}
