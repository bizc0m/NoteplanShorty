// v3 2026-07-15
// Version minimale: generation de raccourcis NotePlan sans icone ni image.

import AppKit
import Darwin
import SwiftUI
import UniformTypeIdentifiers

@main
struct NotePlanShortcutMakerApp: App {
    init() {
        CLIRunner.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 620, height: 360)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var destinationURL: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    @State private var generatedAppURL: URL?
    @State private var status = "Destination par defaut: Downloads. Depose une ou plusieurs notes .md."
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if let logoImage {
                    Image(nsImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("NotePlan Shortcut Maker")
                    .font(.title2.weight(.semibold))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destinationURL?.path ?? "Aucun dossier choisi")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("Choisir destination") {
                    chooseDestination()
                }
            }

            notesDropZone

            HStack {
                Button("Choisir des notes .md") {
                    chooseNotes()
                }

                Button("Reveler le raccourci") {
                    revealGeneratedApp()
                }
                .disabled(generatedAppURL == nil)

                Spacer()
            }

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }

    private var logoImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "logo", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private var notesDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                .background(Color.secondary.opacity(isDropTargeted ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 30))
                        Text("Deposer une ou plusieurs notes .md")
                            .font(.callout)
                    }
                }
                .allowsHitTesting(false)

            FileDropZone(
                onDrop: { urls in createShortcutsFromNotes(urls) },
                onTargetedChange: { targeted in isDropTargeted = targeted }
            )
        }
        .frame(height: 150)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            status = "Destination choisie: \(url.path)"
        }
    }

    private func chooseNotes() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }

        if panel.runModal() == .OK {
            createShortcutsFromNotes(panel.urls)
        }
    }

    private func createShortcutsFromNotes(_ noteURLs: [URL]) {
        guard let destinationURL else {
            status = "Choisis d'abord un dossier destination."
            return
        }

        let markdownURLs = noteURLs.filter { $0.pathExtension.lowercased() == "md" }
        guard !markdownURLs.isEmpty else {
            status = "Aucune note .md lue. Utilise le bouton Choisir des notes .md."
            return
        }

        guard confirmBatchReplaceIfNeeded(noteURLs: markdownURLs, destinationURL: destinationURL) else {
            status = "Creation annulee."
            return
        }

        var results: [ShortcutResult] = []
        var failures: [String] = []

        for noteURL in markdownURLs {
            do {
                let result = try NotePlanShortcutGenerator.generate(
                    noteURL: noteURL,
                    destinationURL: destinationURL,
                    confirmReplace: { _ in true }
                )
                results.append(result)
            } catch {
                failures.append("\(noteURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        guard !results.isEmpty else {
            status = "Aucun raccourci cree.\n\(failures.prefix(2).joined(separator: "\n"))"
            return
        }

        generatedAppURL = results.last?.appURL
        let failureLine = failures.isEmpty ? "" : "\nErreurs: \(failures.count)"
        status = "\(results.count) raccourci(s) cree(s)\nDernier: \(results.last?.noteName ?? "-")\nDestination: \(destinationURL.path)\(failureLine)"
    }

    private func confirmBatchReplaceIfNeeded(noteURLs: [URL], destinationURL: URL) -> Bool {
        let existing = noteURLs.compactMap { noteURL -> URL? in
            let noteName = noteURL.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
            let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
            return FileManager.default.fileExists(atPath: appURL.path) ? appURL : nil
        }

        guard !existing.isEmpty else { return true }

        let alert = NSAlert()
        alert.messageText = "Remplacer les raccourcis existants ?"
        alert.informativeText = existing.prefix(6).map(\.lastPathComponent).joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remplacer tout")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func revealGeneratedApp() {
        guard let generatedAppURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([generatedAppURL])
    }
}

struct FileDropZone: NSViewRepresentable {
    let onDrop: ([URL]) -> Void
    let onTargetedChange: (Bool) -> Void

    func makeNSView(context: Context) -> FileDropCatcherView {
        let view = FileDropCatcherView()
        view.onDropFileURL = onDrop
        view.onTargetedChange = onTargetedChange
        return view
    }

    func updateNSView(_ nsView: FileDropCatcherView, context: Context) {
        nsView.onDropFileURL = onDrop
        nsView.onTargetedChange = onTargetedChange
    }
}

final class FileDropCatcherView: NSView {
    var onDropFileURL: (([URL]) -> Void)?
    var onTargetedChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !fileURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onDropFileURL?(urls)
        return true
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls
    }
}

enum NotePlanShortcutError: LocalizedError {
    case notMarkdown
    case emptyNoteName
    case cancelled
    case verificationFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notMarkdown:
            return "Le fichier depose doit etre une note .md."
        case .emptyNoteName:
            return "Le nom de la note est vide."
        case .cancelled:
            return "Operation annulee."
        case .verificationFailed(let message), .commandFailed(let message):
            return message
        }
    }
}

struct ShortcutResult {
    let noteName: String
    let noteURLString: String
    let appURL: URL
}

struct NotePlanShortcutGenerator {
    static func generate(
        noteURL: URL,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard noteURL.pathExtension.lowercased() == "md" else {
            throw NotePlanShortcutError.notMarkdown
        }

        let noteName = noteURL.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
        guard !noteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw NotePlanShortcutError.cancelled
            }
            try FileManager.default.removeItem(at: appURL)
        }

        let noteFilename = notePlanFilename(for: noteURL)
        let noteURLString = "noteplan://x-callback-url/openNote?filename=\(urlEncodePath(noteFilename))"
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(noteURLString: noteURLString, appName: noteName, finalAppPath: finalAppPath, destinationDir: destinationURL)
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    private static func compileShortcutApp(noteURLString: String, appName: String, finalAppPath: String, destinationDir: URL) throws {
        let script = """
        tell application "NotePlan" to activate
        open location "\(noteURLString)"
        """

        let tempAppURL = destinationDir.appendingPathComponent(".nps-tmp-\(UUID().uuidString).app")

        do {
            try run("/usr/bin/osacompile", ["-o", tempAppURL.path, "-e", script])

            let plistURL = tempAppURL.appendingPathComponent("Contents/Info.plist")
            try setPlistStrings(
                [
                    "CFBundleName": appName,
                    "CFBundleDisplayName": appName,
                    "NotePlanShortcutURL": noteURLString
                ],
                plistURL: plistURL
            )
            try removeDefaultAppletIcon(fromAppURL: tempAppURL)
            try renamePreservingUnicode(fromPath: tempAppURL.path, toPath: finalAppPath)
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func setPlistStrings(_ values: [String: String], plistURL: URL) throws {
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
        }
        for (key, value) in values {
            plist[key] = value
        }
        let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: plistURL)
    }

    private static func removeDefaultAppletIcon(fromAppURL appURL: URL) throws {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        var data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
        }
        plist.removeValue(forKey: "CFBundleIconFile")
        plist.removeValue(forKey: "CFBundleIconName")
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)

        let defaultIconURL = appURL.appendingPathComponent("Contents/Resources/applet.icns")
        if FileManager.default.fileExists(atPath: defaultIconURL.path) {
            try FileManager.default.removeItem(at: defaultIconURL)
        }
    }

    private static func renamePreservingUnicode(fromPath: String, toPath: String) throws {
        let result = fromPath.withCString { src in
            toPath.withCString { dst in
                rename(src, dst)
            }
        }
        guard result == 0 else {
            throw NotePlanShortcutError.commandFailed("rename() a echoue: \(String(cString: strerror(errno)))")
        }
    }

    private static func verify(appURL: URL, noteName: String, noteURLString: String) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: le dossier .app n'existe pas.")
        }

        guard appURL.lastPathComponent == "\(noteName).app" else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: nom .app incorrect.")
        }

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let bundleName = try plistValue("CFBundleName", plistURL: plistURL)
        let displayName = try plistValue("CFBundleDisplayName", plistURL: plistURL)
        let storedURL = try plistValue("NotePlanShortcutURL", plistURL: plistURL)

        guard bundleName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: CFBundleName incorrect.")
        }

        guard displayName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: CFBundleDisplayName incorrect.")
        }

        guard storedURL == noteURLString else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: URL NotePlan incorrecte.")
        }

        let defaultIconURL = appURL.appendingPathComponent("Contents/Resources/applet.icns")
        guard !FileManager.default.fileExists(atPath: defaultIconURL.path) else {
            throw NotePlanShortcutError.verificationFailed("Verification echouee: icone par defaut non supprimee.")
        }
    }

    private static func plistValue(_ key: String, plistURL: URL) throws -> String {
        try runAndCapture("/usr/bin/plutil", ["-extract", key, "raw", plistURL.path])
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        _ = try runAndCapture(executable, arguments)
    }

    private static func runAndCapture(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let outputText = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw NotePlanShortcutError.commandFailed(errorText.isEmpty ? outputText : errorText)
        }

        return outputText
    }

    static func notePlanFilename(for noteURL: URL) -> String {
        let components = noteURL.pathComponents
        if let notesIndex = components.lastIndex(of: "Notes"), notesIndex < components.count - 1 {
            return components[(notesIndex + 1)...].joined(separator: "/").precomposedStringWithCanonicalMapping
        }
        return noteURL.lastPathComponent.precomposedStringWithCanonicalMapping
    }

    static func urlEncodePath(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?&=#%")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum CLIRunner {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--cli-generate") else { return }

        var remaining = Array(args[(flagIndex + 1)...])
        guard remaining.count >= 2 else {
            FileHandle.standardError.write("Usage: --cli-generate <note.md> [note2.md ...] <destinationDir>\n".data(using: .utf8)!)
            exit(64)
        }

        let destinationURL = URL(fileURLWithPath: remaining.removeLast())
        let noteURLs = remaining.map { URL(fileURLWithPath: $0) }

        do {
            for noteURL in noteURLs {
                let result = try NotePlanShortcutGenerator.generate(
                    noteURL: noteURL,
                    destinationURL: destinationURL,
                    confirmReplace: { _ in true }
                )
                print("APP_PATH=\(result.appURL.path)")
                print("NOTE_NAME=\(result.noteName)")
                print("NOTE_URL=\(result.noteURLString)")
            }
            print("COUNT=\(noteURLs.count)")
            exit(0)
        } catch {
            FileHandle.standardError.write("ERROR: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }
}
