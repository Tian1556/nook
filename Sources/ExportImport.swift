import AppKit
import UniformTypeIdentifiers

// MARK: - Archive format

struct StickyArchive: Codable {
    var version = 3
    var app = "Nook"
    var exported = Date()
    var notes: [StickyNote]
    /// Image id → base64 file bytes for every `noty-img` token used by `notes`,
    /// so an archive is self-contained. Optional because archives written
    /// before image support (version ≤ 2) simply lack the key.
    var images: [String: String]?
}

struct StickyNote: Codable {
    var id: String
    var title: String
    var body: String
    var color: Int
    var colorName: String
    var created: Date
    var modified: Date
    var archived: Bool
    var order: Double
    var textDirection: NoteTextDirection?
    var pinned: Bool?

    init(_ n: Note) {
        id = n.id; title = n.title; body = n.body
        color = n.color; colorName = n.palette.name
        created = n.created; modified = n.modified
        archived = n.archived; order = n.order
        textDirection = n.textDirection
        pinned = n.pinned
    }

    var note: Note {
        Note(id: id, title: title,
             body: body, color: color, created: created, modified: modified,
             archived: archived, pinned: pinned ?? false, textDirection: textDirection ?? .automatic,
             order: order)
    }
}

struct CurrentNoteMarkdownAsset {
    let fileName: String
    let data: Data
}

struct CurrentNoteMarkdownPackage {
    let markdown: String
    let assetsDirectoryName: String?
    let assets: [CurrentNoteMarkdownAsset]
}

enum CurrentNoteMarkdownError: LocalizedError {
    case missingImage(String)
    case assetsPathIsFile(String)
    case imageVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingImage(let id):
            return L10n.format("export.image_missing", id)
        case .assetsPathIsFile(let name):
            return L10n.format("export.assets_conflict", name)
        case .imageVerificationFailed(let name):
            return L10n.format("export.image_verify_failed", name)
        }
    }
}

// MARK: - Export / import

enum Transfer {

    enum Format { case markdown, plainText, singleFile, stickies }

    static func export(_ format: Format, notes: [Note]) {
        guard !notes.isEmpty else {
            alert(L10n.text("export.empty_title"), L10n.text("export.empty_body"))
            return
        }
        _ = NoteStore.shared.flushAll()
        NSApp.activate()
        switch format {
        case .markdown:  exportPerFile(notes, ext: "md",  render: markdownBody)
        case .plainText: exportPerFile(notes, ext: "txt", render: { $0.body })
        case .singleFile: exportSingle(notes)
        case .stickies:  exportArchive(notes)
        }
    }

    // One file per note, into a folder the user picks.
    private static func exportPerFile(_ notes: [Note], ext: String, render: (Note) -> String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("export.here")
        panel.message = L10n.plural("export.choose_folder", notes.count, ext.uppercased())
        guard panel.runModal() == .OK, let dir = panel.url else { return }

        var used = Set<String>()
        var written = 0
        for n in notes {
            do {
                _ = try writeUniqueFile(render(n), named: safeName(n), ext: ext,
                                        directory: dir, used: &used)
                written += 1
            } catch {
                NSLog("Nook export failed: \(error.localizedDescription)")
            }
        }
        reveal(dir)
        if written < notes.count {
            alert(L10n.text("export.incomplete_title"),
                  L10n.format("export.incomplete_body", written,
                              L10n.plural("notes.count", notes.count)))
        }
    }

    private static func exportSingle(_ notes: [Note]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = L10n.format(
            "export.markdown_filename", Fmt.fileStamp.string(from: Date()))
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let doc = notes.map { n -> String in
            let archiveSuffix = n.archived ? L10n.text("export.metadata_archived_suffix") : ""
            let metadata = L10n.format(
                "export.metadata", n.palette.localizedName,
                Fmt.stamp.string(from: n.created), Fmt.stamp.string(from: n.modified),
                archiveSuffix)
            return """
            ## \(n.displayTitle)
            <!-- \(metadata) -->

            \(Tasks.toMarkdown(n.body))
            """
        }.joined(separator: "\n\n---\n\n")

        let header = "# \(L10n.text("export.document_title"))\n\n"
            + "\(L10n.plural("notes.count", notes.count)) · \(Fmt.stamp.string(from: Date()))\n\n---\n\n"
        write(header + doc, to: url)
    }

    private static func exportArchive(_ notes: [Note]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = L10n.format(
            "export.archive_filename", Fmt.fileStamp.string(from: Date()))
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var archive = StickyArchive(notes: notes.map(StickyNote.init))
        let images = archiveImages(for: notes)
        archive.images = images.isEmpty ? nil : images
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        do {
            try enc.encode(archive).write(to: url, options: .atomic)
            reveal(url)
        } catch {
            alert(L10n.text("export.failed_title"), error.localizedDescription)
        }
    }

    /// The bytes behind every image token in the exported notes, keyed by id.
    /// Ids are stable across export/import, so one image shared by several
    /// notes is stored once.
    private static func archiveImages(for notes: [Note]) -> [String: String] {
        var out: [String: String] = [:]
        for n in notes {
            for id in ImageStore.referencedIDs(in: n.body) {
                guard out[id] == nil, let data = ImageStore.data(id: id) else { continue }
                out[id] = data.base64EncodedString()
            }
        }
        return out
    }

    private static func markdownBody(_ n: Note) -> String {
        let source = Tasks.toMarkdown(n.body)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let first = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        // Promote a bare first line to an H1 so the file reads as a document.
        // An image token must stay verbatim, or the round trip loses the image.
        if !first.isEmpty && !first.hasPrefix("#") && !first.hasPrefix("- [")
            && !Note.isImageTokenLine(first) {
            return (["# " + first] + lines.dropFirst()).joined(separator: "\n")
        }
        return source
    }

    // MARK: Current note Markdown

    static func saveCurrentNoteMarkdown(noteID: String) {
        guard NoteStore.shared.flush(id: noteID) else {
            alert(L10n.text("export.failed_title"),
                  L10n.text("export.note_save_failed"))
            return
        }
        guard let note = NoteStore.shared.note(id: noteID) else { return }

        NSApp.activate()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultMarkdownFilename(for: note)
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("action.save")
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let package = try prepareCurrentNoteMarkdown(
                note, destination: destination, imageLoader: ImageStore.exportPayload)
            try writeCurrentNoteMarkdown(package, destination: destination)
            reveal(destination)
        } catch {
            alert(L10n.text("export.failed_title"), error.localizedDescription)
        }
    }

    static func defaultMarkdownFilename(for note: Note) -> String {
        safeName(note) + ".md"
    }

    /// Builds a complete, portable export without touching the destination.
    /// Keeping planning separate from writing makes a missing image fail before
    /// an existing Markdown file can be replaced.
    static func prepareCurrentNoteMarkdown(
        _ note: Note,
        destination: URL,
        imageLoader: (String) -> ImageStore.ExportPayload?
    ) throws -> CurrentNoteMarkdownPackage {
        var markdown = currentNoteMarkdownBody(note)
        let tokens = ImageStore.tokens(in: markdown)
        guard !tokens.isEmpty else {
            return CurrentNoteMarkdownPackage(markdown: markdown,
                                              assetsDirectoryName: nil,
                                              assets: [])
        }

        let base = destination.deletingPathExtension().lastPathComponent
        let assetsDirectoryName = base + "_assets"
        var assets: [CurrentNoteMarkdownAsset] = []
        var fileNames: [String: String] = [:]

        for token in tokens where fileNames[token.id] == nil {
            guard let payload = imageLoader(token.id) else {
                throw CurrentNoteMarkdownError.missingImage(token.id)
            }
            let ext = payload.fileExtension.lowercased()
            let fileName = token.id + "." + ext
            fileNames[token.id] = fileName
            assets.append(CurrentNoteMarkdownAsset(fileName: fileName, data: payload.data))
        }

        var rewritten = markdown as NSString
        for token in tokens.reversed() {
            guard let fileName = fileNames[token.id] else { continue }
            let alt: String
            if let width = token.width, width > 0 {
                alt = width.rounded() == width
                    ? "image|\(Int(width))"
                    : "image|\(String(format: "%.1f", Double(width)))"
            } else {
                alt = "image"
            }
            let relative = markdownLinkPath(assetsDirectoryName + "/" + fileName)
            rewritten = rewritten.replacingCharacters(
                in: token.range, with: "![\(alt)](\(relative))") as NSString
        }
        markdown = rewritten as String

        return CurrentNoteMarkdownPackage(markdown: markdown,
                                          assetsDirectoryName: assetsDirectoryName,
                                          assets: assets)
    }

    /// Writes and verifies every image before atomically replacing Markdown.
    /// Existing unrelated files in the assets folder are intentionally kept.
    static func writeCurrentNoteMarkdown(
        _ package: CurrentNoteMarkdownPackage, destination: URL
    ) throws {
        if let directoryName = package.assetsDirectoryName, !package.assets.isEmpty {
            let directory = destination.deletingLastPathComponent()
                .appendingPathComponent(directoryName, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else {
                    throw CurrentNoteMarkdownError.assetsPathIsFile(directoryName)
                }
            } else {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true)
            }

            for asset in package.assets {
                let url = directory.appendingPathComponent(asset.fileName)
                try asset.data.write(to: url, options: .atomic)
                guard (try? Data(contentsOf: url)) == asset.data else {
                    throw CurrentNoteMarkdownError.imageVerificationFailed(asset.fileName)
                }
            }
        }
        try package.markdown.write(to: destination, atomically: true, encoding: .utf8)
    }

    private static func currentNoteMarkdownBody(_ note: Note) -> String {
        let customTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customTitle.isEmpty else { return markdownBody(note) }

        let source = Tasks.toMarkdown(note.body)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstLine = lines.first else { return "# " + customTitle }
        let first = firstLine.trimmingCharacters(in: .whitespaces)
        if first == "# " + customTitle { return source }
        if first == customTitle {
            return (["# " + customTitle] + lines.dropFirst()).joined(separator: "\n")
        }
        return source.isEmpty ? "# " + customTitle : "# \(customTitle)\n\n\(source)"
    }

    /// Keep readable Unicode names while escaping characters that CommonMark
    /// treats as link syntax or URL delimiters. The folder on disk keeps the
    /// exact filename chosen in the save panel.
    private static func markdownLinkPath(_ path: String) -> String {
        let unsafe = CharacterSet(charactersIn: "%()#?\\<>")
            .union(.whitespacesAndNewlines)
            .union(.controlCharacters)
        return path.unicodeScalars.map { scalar in
            unsafe.contains(scalar) ? String(format: "%%%02X", scalar.value) : String(scalar)
        }.joined()
    }

    // MARK: Import

    static func decodeArchive(_ data: Data) throws -> [Note] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(StickyArchive.self, from: data)
        guard (1...3).contains(archive.version) else {
            throw PersistenceError.database(L10n.text("import.invalid_archive"))
        }
        guard archive.notes.allSatisfy({ NoteColor.all.indices.contains($0.color) }) else {
            throw PersistenceError.invalidColor
        }
        let remapped = restoreImages(archive.images ?? [:])
        return archive.notes.map { sticky in
            var n = sticky.note
            if !remapped.isEmpty {
                n.body = remapImageIDs(in: n.body, mapping: remapped)
            }
            return n
        }
    }

    static func importFiles() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        var types: [UTType] = [.plainText, .text]
        if let sticky = UTType(filenameExtension: "stickies") { types.append(sticky) }
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true
        panel.message = L10n.text("import.choose_files")
        guard panel.runModal() == .OK else { return }

        var incoming: [Note] = []
        var failed: [String] = []

        for url in panel.urls {
            if url.pathExtension.lowercased() == "stickies" {
                guard let data = try? Data(contentsOf: url) else { failed.append(url.lastPathComponent); continue }
                if let notes = try? decodeArchive(data) {
                    incoming += notes
                } else {
                    failed.append(url.lastPathComponent)
                }
            } else {
                guard let body = try? String(contentsOf: url, encoding: .utf8) else {
                    failed.append(url.lastPathComponent); continue
                }
                var n = Note()
                n.body = Tasks.fromMarkdown(body)
                if Note.derivedTitle(from: n.body).isEmpty { n.title = url.deletingPathExtension().lastPathComponent }
                n.color = Int(url.lastPathComponent.hashValue.magnitude % UInt(NoteColor.all.count))
                incoming.append(n)
            }
        }

        let added = NoteStore.shared.ingest(incoming)
        if added < incoming.count { failed.append(L10n.text("storage.import_unsaved")) }
        if failed.isEmpty {
            alert(L10n.text("import.complete_title"), L10n.plural("import.added", added))
        } else {
            alert(L10n.text("import.problems_title"),
                  L10n.format("import.problems_body", L10n.plural("import.added", added),
                              failed.joined(separator: ", ")))
        }
    }

    // MARK: Helpers

    /// Reserve the destination exclusively so existing files (including symlinks)
    /// survive even if another export writes into the folder at the same time.
    static func writeUniqueFile(_ text: String, named base: String, ext: String,
                                directory: URL, used: inout Set<String>) throws -> URL {
        let existing = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        used.formUnion(existing.map { $0.precomposedStringWithCanonicalMapping.lowercased() })
        var suffix = 1
        while true {
            let name = (suffix == 1 ? base : "\(base)-\(suffix)") + "." + ext
            let folded = name.precomposedStringWithCanonicalMapping.lowercased()
            suffix += 1
            guard !used.contains(folded) else { continue }
            let url = directory.appendingPathComponent(name)
            do {
                try Data(text.utf8).write(to: url, options: .withoutOverwriting)
                used.insert(folded)
                return url
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain,
                      error.code == NSFileWriteFileExistsError else { throw error }
                used.insert(folded)
            }
        }
    }

    /// Writes an archive's bundled images back to disk. An id already present
    /// is the same image (export copies the file unchanged), so it is skipped
    /// and its tokens stay valid. `ImageStore.save` always mints a fresh id,
    /// so the returned old→new mapping must be applied to the imported bodies.
    private static func restoreImages(_ images: [String: String]) -> [String: String] {
        var remapped: [String: String] = [:]
        for (oldID, b64) in images {
            guard ImageStore.data(id: oldID) == nil else { continue }
            guard let data = Data(base64Encoded: b64),
                  let newID = ImageStore.save(
                    data: data,
                    ext: ImageStore.detectedFileExtension(for: data) ?? "png"
                  ) else { continue }
            if newID != oldID { remapped[oldID] = newID }
        }
        return remapped
    }

    /// Rewrites image tokens to the ids the images actually landed under.
    /// Tokens are replaced whole (preserving any width) in reverse order so
    /// the ranges stay valid against the original string.
    private static func remapImageIDs(in body: String, mapping: [String: String]) -> String {
        var result = body as NSString
        for token in ImageStore.tokens(in: body).reversed() {
            guard let newID = mapping[token.id] else { continue }
            result = result.replacingCharacters(
                in: token.range,
                with: ImageStore.token(id: newID, width: token.width)) as NSString
        }
        return result as String
    }

    static func safeName(_ n: Note) -> String {
        let raw = n.displayTitle
        let cleaned = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(cleaned.prefix(80))
        return trimmed.isEmpty
            ? L10n.format("export.default_note_name", String(n.id.prefix(8)))
            : trimmed
    }

    private static func write(_ s: String, to url: URL) {
        do {
            try s.write(to: url, atomically: true, encoding: .utf8)
            reveal(url)
        } catch {
            alert(L10n.text("export.failed_title"), error.localizedDescription)
        }
    }

    private static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func alert(_ title: String, _ body: String) {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = title
        a.informativeText = body
        a.alertStyle = .informational
        a.runModal()
    }
}
