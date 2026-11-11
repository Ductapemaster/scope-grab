import AppKit
import Observation
import ScopeGrabCore

/// The app's state and actions, shared by the window and the menu bar. A capture is held
/// in memory until Save writes it to the save folder.
@Observable @MainActor
final class CaptureModel {
    /// The last action taken, for the status bar.
    enum Status: Equatable {
        case none
        case capturing
        case captured(Date)
        case saved(URL)
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
    /// The last capture as PNG, and when it was taken; the filename's date and time come from it.
    private(set) var png: Data?
    private(set) var capturedAt: Date?
    /// Where the last capture was saved, or nil while it's unsaved.
    private(set) var savedFile: URL?
    private(set) var status = Status.none
    private(set) var busy = false
    private(set) var scopeOnUSB: Bool?
    /// Counts finished captures, so the window can flash the preview and reselect the label.
    private(set) var captures = 0
    /// Counts saves, so the window can reselect the label.
    private(set) var saves = 0

    @ObservationIgnored private var watcher: ScopeWatcher?

    var hasCapture: Bool { png != nil }
    var canSave: Bool { png != nil && savedFile == nil && !busy }

    init() {
        folder = UserDefaults.standard.string(forKey: "folder") ?? ""
        template = UserDefaults.standard.string(forKey: "filenameTemplate") ?? FilenameTemplate.standard
        #if DEBUG
        // Layout checks without the scope: SCOPEGRAB_PREVIEW=<png> shows that file as an unsaved
        // capture, and SCOPEGRAB_SAVED=1 marks it saved where it is.
        let env = ProcessInfo.processInfo.environment
        if let path = env["SCOPEGRAB_PREVIEW"], let data = FileManager.default.contents(atPath: path) {
            png = data
            preview = NSImage(data: data)
            capturedAt = .now
            status = .captured(.now)
            if env["SCOPEGRAB_SAVED"] != nil {
                savedFile = URL(fileURLWithPath: path)
                status = .saved(URL(fileURLWithPath: path))
            }
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
        #endif
    }

    func start() {
        guard watcher == nil else { return }
        watcher = ScopeWatcher { [weak self] in self?.scopeOnUSB = $0 }
    }

    var folderURL: URL? { folder.isEmpty ? nil : URL(fileURLWithPath: folder) }

    /// The name Save will use now: the capture's time, or the clock's before a capture.
    func pendingName(at now: Date = .now) -> String {
        FilenameTemplate(template).filename(label: label, date: capturedAt ?? now) { _ in false }
    }

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

    /// Grabs the scope's screen into the preview. Nothing is written until Save.
    func capture() {
        guard !busy else { return }
        busy = true
        status = .capturing
        let started = Date()

        Task {
            defer { busy = false; captures += 1 }
            do {
                // USB calls block, so they run off the main thread.
                let bmp = try await Task.detached { try Scope.session { try $0.screen() } }.value
                guard let rep = NSBitmapImageRep(data: bmp),
                      let data = rep.representation(using: .png, properties: [:]) else {
                    throw CaptureError.notAnImage
                }
                png = data
                preview = NSImage(data: data)
                capturedAt = started
                savedFile = nil
                status = .captured(started)
            } catch {
                status = .failed("Capture failed: \(error.localizedDescription)")
            }
        }
    }

    /// Writes the last capture into the save folder, named by the pattern.
    func save() {
        guard canSave, let png, let capturedAt else { return }
        if folder.isEmpty, !pickFolder() { return }
        let dir = URL(fileURLWithPath: folder)
        let name = FilenameTemplate(template).filename(label: label, date: capturedAt) {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
        let file = dir.appendingPathComponent(name)
        do {
            try png.write(to: file, options: .withoutOverwriting)
            savedFile = file
            status = .saved(file)
            saves += 1
        } catch {
            status = .failed("Save failed: \(error.localizedDescription)")
        }
    }

    /// Puts the last capture on the clipboard as PNG and TIFF, so any app can paste it.
    func copyImage() {
        guard let png else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        status = .copied(savedFile?.lastPathComponent ?? "the capture")
    }

    func showInFinder() {
        if let savedFile { NSWorkspace.shared.activateFileViewerSelecting([savedFile]) }
    }

    func openFolder() {
        if let folderURL { NSWorkspace.shared.open(folderURL) }
    }
}

enum CaptureError: Error, LocalizedError {
    case notAnImage
    var errorDescription: String? { "the scope's reply isn't a readable image" }
}
