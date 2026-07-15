// v1.0 date inconnue (fichier initial, avant mise en place du versioning) ARCHIVE
// DEMANDE: (retroactif) app macOS pour creer un raccourci .app depuis une note NotePlan .md deposee.
// SORTIE: premiere version, drop via SwiftUI .onDrop([.fileURL, .item]) + NSItemProvider.
// PREUVE: (non documentee au moment de l'ecriture)
// Fichier suivant: main_v2.0.swift (refonte: drop via NSViewRepresentable + NSView AppKit natif, jugé plus robuste pour Finder)
// Ce fichier est archive a plat, hors de Sources/, et n'est plus compile.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct NotePlanShortcutMakerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 560, height: 360)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var destinationURL: URL?
    @State private var generatedAppURL: URL?
    @State private var status = "Choisis un dossier destination, puis depose une note .md."
    @State private var isDropTargeted = false

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

            HStack {
                Button("Choisir une note .md") {
                    chooseNote()
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
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
            .background(Color.secondary.opacity(isDropTargeted ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                    Text("Deposer une note .md")
                        .font(.callout)
                }
            }
            .frame(height: 130)
            .onDrop(of: [.fileURL, .item], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
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

    private func chooseNote() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }

        if panel.runModal() == .OK {
            createShortcutFromNote(panel.url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        loadDroppedFileURL(from: providers) { url in
            createShortcutFromNote(url)
        }
        return true
    }

    private func createShortcutFromNote(_ noteURL: URL?) {
        guard let destinationURL else {
            status = "Choisis d'abord un dossier destination."
            return
        }

        guard let noteURL else {
            status = "Note non lue depuis le drop. Utilise le bouton Choisir une note .md."
            return
        }

        do {
            let result = try NotePlanShortcutGenerator.generate(
                noteURL: noteURL,
                destinationURL: destinationURL,
                confirmReplace: confirmReplace(appURL:)
            )
            generatedAppURL = result.appURL
            status = "Note recue: \(result.noteName)\nNom extrait: \(result.noteName)\nApp creee: \(result.appURL.path)"
        } catch NotePlanShortcutError.cancelled {
            status = "Creation annulee."
        } catch {
            status = "Erreur: \(error.localizedDescription)"
        }
    }

    private func confirmReplace(appURL: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Remplacer le raccourci existant ?"
        alert.informativeText = appURL.path
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remplacer")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func revealGeneratedApp() {
        guard let generatedAppURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([generatedAppURL])
    }

    private func loadDroppedFileURL(from providers: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        guard let provider = providers.first(where: { itemProvider in
            itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            itemProvider.hasItemConformingToTypeIdentifier(UTType.item.identifier)
        }) else {
            completion(nil)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    completion(droppedURL(from: item))
                }
            }
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.item.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                completion(droppedURL(from: item))
            }
        }
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

        let noteName = noteURL.deletingPathExtension().lastPathComponent
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
        try compileShortcutApp(noteURLString: noteURLString, appName: noteName, outputURL: appURL)
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    private static func compileShortcutApp(noteURLString: String, appName: String, outputURL: URL) throws {
        let script = """
        tell application "NotePlan" to activate
        open location "\(noteURLString)"
        """

        try run("/usr/bin/osacompile", ["-o", outputURL.path, "-e", script])

        let plistURL = outputURL.appendingPathComponent("Contents/Info.plist")
        try run("/usr/bin/plutil", ["-replace", "CFBundleName", "-string", appName, plistURL.path])
        try run("/usr/bin/plutil", ["-replace", "CFBundleDisplayName", "-string", appName, plistURL.path])
        try run("/usr/bin/plutil", ["-replace", "NotePlanShortcutURL", "-string", noteURLString, plistURL.path])
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

private func droppedURL(from item: NSSecureCoding?) -> URL? {
    if let url = item as? URL {
        return url
    }

    if let url = item as? NSURL {
        return url as URL
    }

    if let data = item as? Data {
        if let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url
        }

        if let string = String(data: data, encoding: .utf8) {
            return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    if let string = item as? String {
        return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return nil
}
