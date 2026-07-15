// v2.0 2026-07-15 STABLE-DEPENDANT (depend de NotePlan.app installe pour l'action finale
//   du raccourci genere ; non verifie ce tour-ci, voir PREUVE)
// DEMANDE: Repars de zero, app macOS "NotePlan Shortcut Maker" avec drag&drop Finder
//   robuste (NSViewRepresentable + NSView + registerForDraggedTypes plutot que
//   SwiftUI .onDrop), qui genere DESTINATION/<nom note>.app ouvrant
//   noteplan://x-callback-url/openNote?noteTitle=<nom encode>.
// SORTIE: Remplace le drop SwiftUI .onDrop/NSItemProvider (fragile: completion
//   asynchrone, pertes intermittentes de drop Finder) par une NSView AppKit
//   (draggingEntered/prepareForDragOperation/performDragOperation, lecture via
//   NSPasteboard.readObjects(forClasses:[NSURL.self], options:[.urlReadingFileURLsOnly: true])),
//   enveloppee en NSViewRepresentable superposee au visuel SwiftUI existant.
//   Ajoute un mode CLI cache (--cli-generate) qui appelle exactement le meme
//   generateur que le drop et le bouton "Choisir une note .md", pour permettre
//   un test automatise du binaire compile. Corrige au passage un bug decouvert en
//   testant : URL/FileManager/Process decomposent les caracteres accentues (NFD)
//   meme pour des fichiers source en NFC, ce qui aurait produit des noms .app et
//   des URL NotePlan avec les mauvais octets pour "Été & idées.md". Fix : nom
//   recompose en NFC, plist ecrit via PropertyListSerialization (pas plutil en
//   sous-processus), renommage final via le syscall rename() brut.
// PREUVE: swift build -c release OK. test-generation.sh (mode --cli-generate, exerce
//   le vrai binaire) passe : "TODO Suisse" + relance sur la meme note (pas de
//   "TODO Suisse 2.app", remplacement en place) + "Été & idées" avec verification des
//   octets exacts du nom et de l'URL stockee (NFC). Drag & drop Finder reel teste via
//   automatisation GUI (computer-use) : fichier "Idée GUI.md" glisse depuis une vraie
//   fenetre Finder jusque dans la zone de drop de l'app compilee (dist/), statut
//   "Note recue: Idée GUI" affiche, .app cree avec les bons octets et le bon plist,
//   bouton "Reveler le raccourci" verifie (ouvre Finder, selectionne l'app). Non
//   verifie : que le .app genere ouvre effectivement NotePlan et navigue vers la
//   bonne note (necessite NotePlan.app installe et lance).
// Fichier precedent: main_v1.0.swift (archive a la racine du projet)

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
                .frame(width: 640, height: 440)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var destinationURL: URL?
    @State private var iconURL: URL?
    @State private var generatedAppURL: URL?
    @State private var status = "Choisis un dossier destination, puis depose une ou plusieurs notes .md."
    @State private var isDropTargeted = false
    @State private var useCustomIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NotePlan Shortcut Maker")
                .font(.title2.weight(.semibold))

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

            dropZone

            HStack(spacing: 10) {
                Toggle("Icone personnalisee", isOn: $useCustomIcon)

                Button("Choisir image") {
                    chooseIcon()
                }
                .disabled(!useCustomIcon)

                Text(iconURL?.lastPathComponent ?? "Aucune image")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

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

    private var dropZone: some View {
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
        .frame(height: 130)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            status = "Destination choisie: \(url.path)"
        }
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, UTType(filenameExtension: "icns")].compactMap { $0 }

        if panel.runModal() == .OK {
            iconURL = panel.url
            status = "Image icone choisie: \(panel.url?.lastPathComponent ?? "")"
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
                    iconURL: useCustomIcon ? iconURL : nil,
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
        let iconLine = results.contains { $0.iconApplied } ? "\nIcone optimisee appliquee" : ""
        let failureLine = failures.isEmpty ? "" : "\nErreurs: \(failures.count)"
        status = "\(results.count) raccourci(s) cree(s)\nDernier: \(results.last?.noteName ?? "-")\nDestination: \(destinationURL.path)\(iconLine)\(failureLine)"
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

/// SwiftUI bridge for a native AppKit drop target, overlaid on the SwiftUI
/// visual so hit-testing and pasteboard reading happen entirely in AppKit.
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

/// Native AppKit drag & drop target. Deliberately avoids SwiftUI's `.onDrop`
/// (backed by `NSItemProvider.loadItem`, which resolves asynchronously and
/// intermittently drops Finder file drags). Reads the dropped file URL
/// synchronously from the pasteboard, which is the reliable path for local
/// Finder drags. Only `.fileURL`/`.URL` are registered: NotePlan notes are
/// always local files on disk, never file promises (Photos/Mail-style virtual
/// files), so `NSFilePromiseReceiver` handling is not needed here.
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
    let iconApplied: Bool
}

struct NotePlanShortcutGenerator {
    static func generate(
        noteURL: URL,
        destinationURL: URL,
        iconURL: URL? = nil,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard noteURL.pathExtension.lowercased() == "md" else {
            throw NotePlanShortcutError.notMarkdown
        }

        // URL.lastPathComponent decomposes accented characters (NFD) even when the
        // file on disk is NFC-encoded. Re-compose so the generated NotePlan URL and
        // .app name match what the user actually typed/sees, not the decomposed form.
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

        let noteURLString = "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(noteName))"

        // Foundation's URL/Process path handling decomposes any accented path to NFD,
        // even though the filesystem itself preserves whatever bytes it's given (verified
        // with a raw POSIX mkdir/rename). Build the final path as a plain Swift String,
        // never round-tripped through URL.path, so the .app lands on disk with the exact
        // NFC name the user typed.
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(noteURLString: noteURLString, appName: noteName, iconURL: iconURL, finalAppPath: finalAppPath, destinationDir: destinationURL)
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString, expectsCustomIcon: iconURL != nil)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL, iconApplied: iconURL != nil)
    }

    private static func compileShortcutApp(noteURLString: String, appName: String, iconURL: URL?, finalAppPath: String, destinationDir: URL) throws {
        let script = """
        tell application "NotePlan" to activate
        open location "\(noteURLString)"
        """

        // osacompile is invoked as a subprocess: Process argument marshaling decomposes
        // Unicode too, so compile into an ASCII-only temp name first (immune to NFD/NFC
        // issues) and only introduce the accented name via a raw rename(2) at the end.
        let tempAppURL = destinationDir.appendingPathComponent(".nps-tmp-\(UUID().uuidString).app")

        do {
            try run("/usr/bin/osacompile", ["-o", tempAppURL.path, "-e", script])

            let plistURL = tempAppURL.appendingPathComponent("Contents/Info.plist")
            try setPlistStrings(
                [
                    "CFBundleName": appName,
                    "CFBundleDisplayName": appName,
                    "NotePlanShortcutURL": noteURLString,
                    "CFBundleIconFile": iconURL == nil ? "" : "CustomIcon"
                ],
                plistURL: plistURL
            )

            if let iconURL {
                try applyOptimizedIcon(from: iconURL, toAppURL: tempAppURL)
            } else {
                try removeDefaultAppletIcon(fromAppURL: tempAppURL)
            }

            try renamePreservingUnicode(fromPath: tempAppURL.path, toPath: finalAppPath)
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func applyOptimizedIcon(from sourceURL: URL, toAppURL appURL: URL) throws {
        let iconURL: URL
        if sourceURL.pathExtension.lowercased() == "icns" {
            iconURL = sourceURL
        } else {
            iconURL = try makeOptimizedICNS(from: sourceURL)
        }

        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let targetURL = resourcesURL.appendingPathComponent("CustomIcon.icns")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: iconURL, to: targetURL)
        try removeConflictingAppletIconKeys(fromAppURL: appURL)
        try run("/usr/bin/touch", [appURL.path])
    }

    private static func removeConflictingAppletIconKeys(fromAppURL appURL: URL) throws {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        var data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
        }
        plist.removeValue(forKey: "CFBundleIconName")
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)

        let defaultIconURL = appURL.appendingPathComponent("Contents/Resources/applet.icns")
        if FileManager.default.fileExists(atPath: defaultIconURL.path) {
            try FileManager.default.removeItem(at: defaultIconURL)
        }
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

        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        for fileName in ["applet.icns"] {
            let fileURL = resourcesURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private static func makeOptimizedICNS(from sourceURL: URL) throws -> URL {
        let workURL = FileManager.default.temporaryDirectory.appendingPathComponent("nps-icon-\(UUID().uuidString)", isDirectory: true)
        let iconsetURL = workURL.appendingPathComponent("CustomIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        let specs = [
            ("16x16", 16),
            ("16x16@2x", 32),
            ("32x32", 32),
            ("32x32@2x", 64),
            ("128x128", 128),
            ("128x128@2x", 256),
            ("256x256", 256),
            ("256x256@2x", 512),
            ("512x512", 512)
        ]

        for (name, pixels) in specs {
            let outputURL = iconsetURL.appendingPathComponent("icon_\(name).png")
            try run("/usr/bin/sips", ["-z", "\(pixels)", "\(pixels)", sourceURL.path, "--out", outputURL.path])
        }

        let icnsURL = workURL.appendingPathComponent("CustomIcon.icns")
        try run("/usr/bin/iconutil", ["-c", "icns", iconsetURL.path, "-o", icnsURL.path])
        return icnsURL
    }

    /// Writes plist string values via `PropertyListSerialization` instead of `plutil`
    /// as a subprocess argument: subprocess argument marshaling on Darwin decomposes
    /// Unicode (NFD), which would corrupt accented CFBundleName/NotePlanShortcutURL values.
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

    /// Renames using the raw POSIX syscall (bypassing FileManager/URL, which decompose
    /// accented paths to NFD) so the final .app keeps the exact NFC bytes it was given.
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

    private static func verify(appURL: URL, noteName: String, noteURLString: String, expectsCustomIcon: Bool) throws {
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

        if expectsCustomIcon {
            let iconFile = try plistValue("CFBundleIconFile", plistURL: plistURL)
            guard iconFile == "CustomIcon" else {
                throw NotePlanShortcutError.verificationFailed("Verification echouee: icone personnalisee non referencee.")
            }
            let customIconURL = appURL.appendingPathComponent("Contents/Resources/CustomIcon.icns")
            guard FileManager.default.fileExists(atPath: customIconURL.path) else {
                throw NotePlanShortcutError.verificationFailed("Verification echouee: CustomIcon.icns absent.")
            }
        } else {
            let defaultIconURL = appURL.appendingPathComponent("Contents/Resources/applet.icns")
            guard !FileManager.default.fileExists(atPath: defaultIconURL.path) else {
                throw NotePlanShortcutError.verificationFailed("Verification echouee: icone par defaut non supprimee.")
            }
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

    static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Hidden CLI entry point so an automated test script can exercise the real
/// compiled binary's generator logic (identical code path as drag & drop and
/// the file picker) without driving the GUI. Only the drag & drop mechanism
/// itself still requires a real, manual/GUI-driven Finder drag to verify.
enum CLIRunner {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--cli-generate") else { return }

        var remaining = Array(args[(flagIndex + 1)...])
        var iconURL: URL?
        if let iconIndex = remaining.firstIndex(of: "--icon") {
            guard remaining.indices.contains(iconIndex + 1) else {
                FileHandle.standardError.write("Usage: --cli-generate <note.md> [note2.md ...] <destinationDir> [--icon image]\n".data(using: .utf8)!)
                exit(64)
            }
            iconURL = URL(fileURLWithPath: remaining[iconIndex + 1])
            remaining.removeSubrange(iconIndex...(iconIndex + 1))
        }

        guard remaining.count >= 2 else {
            FileHandle.standardError.write("Usage: --cli-generate <note.md> [note2.md ...] <destinationDir> [--icon image]\n".data(using: .utf8)!)
            exit(64)
        }

        let destinationURL = URL(fileURLWithPath: remaining.removeLast())
        let noteURLs = remaining.map { URL(fileURLWithPath: $0) }

        do {
            for noteURL in noteURLs {
                let result = try NotePlanShortcutGenerator.generate(
                    noteURL: noteURL,
                    destinationURL: destinationURL,
                    iconURL: iconURL,
                    confirmReplace: { _ in true }
                )
                print("APP_PATH=\(result.appURL.path)")
                print("NOTE_NAME=\(result.noteName)")
                print("NOTE_URL=\(result.noteURLString)")
                print("ICON_APPLIED=\(result.iconApplied)")
            }
            print("COUNT=\(noteURLs.count)")
            exit(0)
        } catch {
            FileHandle.standardError.write("ERROR: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }
}
