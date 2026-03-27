import Core
import Foundation
import Ingestion
import PluginKit
import Privacy
import Services
import Testing
import UniformTypeIdentifiers

#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif

@Suite("OrganizerService critical flows")
struct OrganizerServiceTests {
    @Test("Import deduplicates and categorizes known invoice content")
    func importDeduplicatesAndCategorizes() throws {
        let fixture = try TestFixture()

        let invoiceURL = try fixture.writeTextFile(
            named: "invoice.txt",
            contents: "Invoice #2026-001\nPayment terms: net 15\nTotal due: 1200 EUR\n"
        )

        let first = try fixture.organizer.processDocument(at: invoiceURL.path)
        let second = try fixture.organizer.processDocument(at: invoiceURL.path)

        #expect(first.id == second.id)
        #expect(fixture.organizer.listDocuments().count == 1)
        #expect(first.effectiveCategory == .invoice)
    }

    @Test("Export state writes documents, audit events, and granted plugin permissions")
    func exportStateIncludesCoreData() throws {
        let fixture = try TestFixture()

        let sourceURL = try fixture.writeTextFile(
            named: "resume.txt",
            contents: "Resume\nExperience\nEducation\nSkills\n"
        )
        _ = try fixture.organizer.processDocument(at: sourceURL.path)

        try fixture.organizer.grantPermissions(
            [.readDocument, .createDerivedFile],
            to: "text-to-markdown"
        )

        let exportURL = fixture.rootURL.appendingPathComponent("export/state-export.json")
        try fixture.organizer.exportState(to: exportURL)

        let exportedData = try Data(contentsOf: exportURL)
        let jsonObject = try JSONSerialization.jsonObject(with: exportedData)
        guard let json = jsonObject as? [String: Any] else {
            Issue.record("Export payload is not a JSON object")
            return
        }

        let documents = json["documents"] as? [[String: Any]]
        let events = json["events"] as? [[String: Any]]
        let permissions = json["grantedPluginPermissions"] as? [String: Any]

        #expect((documents?.count ?? 0) >= 1)
        #expect((events?.count ?? 0) >= 2)
        #expect(permissions?["text-to-markdown"] != nil)
    }

    @Test("Grant/revoke controls plugin execution permissions")
    func grantRevokeControlsToolExecution() throws {
        let fixture = try TestFixture()

        let sourceURL = try fixture.writeTextFile(
            named: "notes.txt",
            contents: "A plain text document with multiple paragraphs.\n\nSecond paragraph.\n"
        )
        let record = try fixture.organizer.processDocument(at: sourceURL.path)

        do {
            _ = try fixture.organizer.runTool(documentID: record.id, pluginIdentifier: "text-to-markdown")
            Issue.record("Expected permission denial before grant")
        } catch let error as ToolPluginError {
            guard case .permissionDenied = error else {
                Issue.record("Expected permissionDenied, got: \(error)")
                return
            }
        }

        try fixture.organizer.grantPermissions(
            [.readDocument, .createDerivedFile],
            to: "text-to-markdown"
        )

        let result = try fixture.organizer.runTool(
            documentID: record.id,
            pluginIdentifier: "text-to-markdown"
        )
        #expect(FileManager.default.fileExists(atPath: result.derived.filePath))

        try fixture.organizer.revokePermission(.createDerivedFile, from: "text-to-markdown")

        do {
            _ = try fixture.organizer.runTool(documentID: record.id, pluginIdentifier: "text-to-markdown")
            Issue.record("Expected permission denial after revoke")
        } catch let error as ToolPluginError {
            guard case .permissionDenied = error else {
                Issue.record("Expected permissionDenied after revoke, got: \(error)")
                return
            }
        }
    }

    @Test("Image files are accepted by the ingestion pipeline")
    func imageFilesUseOCRPath() throws {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let fixture = try TestFixture()
        let imageURL = try fixture.writeBlankPNG(named: "blank-scan.png")
        let ingestion = DocumentIngestionService()

        do {
            _ = try ingestion.extractText(from: imageURL)
        } catch let error as DocumentIngestionError {
            switch error {
            case .unsupportedFileType:
                Issue.record("PNG should be treated as a supported OCR input")
            case .unreadableData, .ocrUnavailable:
                break
            case .docxArchiveTooLarge, .docxContentTooLarge, .docxExtractionTimedOut:
                Issue.record("PNG ingestion should not fail with DOCX-specific guard errors")
            }
        }
        #else
        Issue.record("CoreGraphics/ImageIO unavailable for image ingestion test")
        #endif
    }

    @Test("DOCX files are accepted by the ingestion pipeline")
    func docxFilesAreSupported() throws {
        #if os(macOS)
        let fixture = try TestFixture()
        let docxURL = try fixture.writeMinimalDOCX(
            named: "invoice.docx",
            contents: "Invoice 2026\nPayment terms\nTotal due 499 EUR"
        )
        let ingestion = DocumentIngestionService()
        let extracted = try ingestion.extractText(from: docxURL)

        #expect(extracted.contains("Invoice 2026"))
        #expect(extracted.contains("Payment terms"))
        #expect(extracted.contains("499 EUR"))
        #else
        // DOCX extraction currently uses macOS unzip tooling.
        #expect(true)
        #endif
    }

    @Test("DOCX archive size guard rejects oversized files")
    func docxArchiveSizeGuardRejectsOversizedInput() throws {
        #if os(macOS)
        let fixture = try TestFixture()
        let oversizedURL = fixture.rootURL.appendingPathComponent("oversized.docx")
        let oversizedData = Data(repeating: 0x41, count: 10_000_001)
        try oversizedData.write(to: oversizedURL)

        let ingestion = DocumentIngestionService()
        do {
            _ = try ingestion.extractText(from: oversizedURL)
            Issue.record("Expected docxArchiveTooLarge guard to reject oversized DOCX input")
        } catch let error as DocumentIngestionError {
            guard case .docxArchiveTooLarge = error else {
                Issue.record("Expected docxArchiveTooLarge, got: \(error)")
                return
            }
        }
        #else
        #expect(true)
        #endif
    }

    @Test("Updating stored file path keeps subsequent tool runs functional")
    func updateDocumentFilePathAfterMove() throws {
        let fixture = try TestFixture()

        let sourceURL = try fixture.writeTextFile(
            named: "move-me.txt",
            contents: "Paragraph one.\n\nParagraph two.\n"
        )

        let record = try fixture.organizer.processDocument(at: sourceURL.path)

        let movedURL = fixture.rootURL
            .appendingPathComponent("organized", isDirectory: true)
            .appendingPathComponent("invoice-2026-03-27-move-me.txt")
        try FileManager.default.createDirectory(
            at: movedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: sourceURL, to: movedURL)

        let updated = try fixture.organizer.updateDocumentFilePath(documentID: record.id, to: movedURL.path)
        #expect(updated.filePath == movedURL.path)
        #expect(updated.fileName == movedURL.lastPathComponent)

        try fixture.organizer.grantPermissions([.readDocument, .createDerivedFile], to: "text-to-markdown")
        let toolRun = try fixture.organizer.runTool(documentID: record.id, pluginIdentifier: "text-to-markdown")
        #expect(FileManager.default.fileExists(atPath: toolRun.derived.filePath))
    }
}

private struct TestFixture {
    let rootURL: URL
    let organizer: OrganizerService

    init() throws {
        let tempBase = FileManager.default.temporaryDirectory
        let suiteURL = tempBase.appendingPathComponent("DocumentOrganizerTests-\(UUID().uuidString)", isDirectory: true)
        let auditURL = suiteURL.appendingPathComponent("audit", isDirectory: true)
        try FileManager.default.createDirectory(at: auditURL, withIntermediateDirectories: true)

        let stateURL = auditURL.appendingPathComponent("organizer-state.json")

        self.rootURL = suiteURL
        self.organizer = OrganizerService(
            privacy: .preset(.balanced),
            stateURL: stateURL
        )
    }

    func writeTextFile(named fileName: String, contents: String) throws -> URL {
        let fileURL = rootURL.appendingPathComponent(fileName)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func writeBlankPNG(named fileName: String) throws -> URL {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let fileURL = rootURL.appendingPathComponent(fileName)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CocoaError(.coderInvalidValue)
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return fileURL
        #else
        throw CocoaError(.featureUnsupported)
        #endif
    }

    func writeMinimalDOCX(named fileName: String, contents: String) throws -> URL {
        #if os(macOS)
        let workingURL = rootURL.appendingPathComponent("docx-src-\(UUID().uuidString)", isDirectory: true)
        let wordURL = workingURL.appendingPathComponent("word", isDirectory: true)
        try FileManager.default.createDirectory(at: wordURL, withIntermediateDirectories: true)

        let contentTypes = """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
          <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>
        </Types>
        """

        let paragraphs = contents.split(separator: "\n").map {
            "<w:p><w:r><w:t>\($0)</w:t></w:r></w:p>"
        }.joined()
        let documentXML = """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
          <w:body>
            \(paragraphs)
          </w:body>
        </w:document>
        """

        try contentTypes.write(
            to: workingURL.appendingPathComponent("[Content_Types].xml"),
            atomically: true,
            encoding: .utf8
        )
        try documentXML.write(
            to: wordURL.appendingPathComponent("document.xml"),
            atomically: true,
            encoding: .utf8
        )

        let fileURL = rootURL.appendingPathComponent(fileName)
        let process = Process()
        process.currentDirectoryURL = workingURL
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qr", fileURL.path, "."]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }

        return fileURL
        #else
        throw CocoaError(.featureUnsupported)
        #endif
    }
}
