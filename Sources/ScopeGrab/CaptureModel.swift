import AppKit
import Observation
import ScopeGrabCore

/// The app's state and actions, shared by the window, its toolbar and the menu bar.
@Observable @MainActor
final class CaptureModel {
    enum Status: Equatable {
        case ready
        case capturing
        case saved(String)
        case copied(String)
        case failed(String)
    }

    var folder: String {
        didSet { UserDefaults.standard.set(folder, forKey: "folder") }
    }
    /// The filename pattern, e.g. `{date} {time} {label}`; see `FilenameTemplate`.
    var template: String {
        didSet { UserDefaults.standard.set(template, forKey: "filenameTemplate") }
    }
    var label = ""
    private(set) var preview: NSImage?
    private(set) var lastFile: URL?
    private(set) var status = Status.ready
    private(set) var busy = false
    private(set) var scopeOnUSB: Bool?
    /// Counts finished captures, so the window can flash the preview and reselect the label.
    private(set) var captures = 0

    @ObservationIgnored private var watcher: ScopeWatcher?

    init() {
        folder = UserDefaults.standard.string(forKey: "folder") ?? ""
        template = UserDefaults.standard.string(forKey: "filenameTemplate") ?? FilenameTemplate.standard
        #if DEBUG
        // Layout checks without the scope: SCOPEGRAB_PREVIEW=<png> shows that file as the last capture.
        if let path = ProcessInfo.processInfo.environment["SCOPEGRAB_PREVIEW"] {
            let url = URL(fileURLWithPath: path)
            preview = NSImage(contentsOf: url)
            lastFile = url
            status = .saved(url.lastPathComponent)
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
        #endif
    }

    func start() {
        guard watcher == nil else { return }
        watcher = ScopeWatcher { [weak self] in self?.scopeOnUSB = $0 }
        // Pick the save folder at first launch; after that it's remembered.
        if folder.isEmpty { DispatchQueue.main.async { _ = self.pickFolder() } }
    }

    var folderName: String { folderURL?.lastPathComponent ?? "Choose Folder…" }

    var folderURL: URL? { folder.isEmpty ? nil : URL(fileURLWithPath: folder) }

    /// Shows a folder picker; returns false if cancelled.
    @discardableResult
    func pickFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Save Here"
        panel.message = "Choose where Scope Grab saves captures"
        panel.directoryURL = folderURL
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        folder = url.path
        return true
    }

    func capture() {
        guard !busy else { return }
        if folder.isEmpty, !pickFolder() { return }
        busy = true
        status = .capturing
        let label = label
        let dir = URL(fileURLWithPath: folder)
        let started = Date()
        let template = FilenameTemplate(template)

        Task {
            defer { busy = false; captures += 1 }
            do {
                // USB calls block, so they run off the main thread.
                let bmp = try await Task.detached { try Scope.session { try $0.screen() } }.value
                guard let rep = NSBitmapImageRep(data: bmp),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    throw CaptureError.notAnImage
                }
                let name = template.filename(label: label, date: started) {
                    FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
                }
                let file = dir.appendingPathComponent(name)
                try png.write(to: file, options: .withoutOverwriting)
                lastFile = file
                preview = NSImage(data: png)
                status = .saved(name)
            } catch {
                status = .failed("Capture failed: \(error.localizedDescription)")
            }
        }
    }

    /// Puts the last capture on the clipboard as PNG and TIFF, so any app can paste it.
    func copyImage() {
        guard let lastFile, let png = try? Data(contentsOf: lastFile) else {
            status = .failed("Can't copy: the last capture's file is gone")
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        status = .copied(lastFile.lastPathComponent)
    }

    func showInFinder() {
        if let lastFile { NSWorkspace.shared.activateFileViewerSelecting([lastFile]) }
    }

    func openFolder() {
        if let folderURL { NSWorkspace.shared.open(folderURL) }
    }
}

enum CaptureError: Error, LocalizedError {
    case notAnImage
    var errorDescription: String? { "the scope's reply isn't a readable image" }
}
