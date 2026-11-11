import AppKit
import ScopeGrabCore
import SwiftUI

@main
struct ScopeGrabApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Scope Grab", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 560)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @AppStorage("folder") private var folder = ""
    @State private var label = ""
    @State private var preview: NSImage?
    @State private var lastFile: URL?
    @State private var status = "Ready"
    @State private var isError = false
    @State private var busy = false
    @State private var scopeOnUSB: Bool?
    @State private var watcher: ScopeWatcher?
    @FocusState private var labelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Save to").gridColumnAlignment(.trailing)
                    HStack {
                        Text(folder.isEmpty ? "No folder chosen" : (folder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1).truncationMode(.head)
                            .foregroundStyle(folder.isEmpty ? .secondary : .primary)
                            .help(folder)
                            // Let a long path truncate rather than widen the window.
                            .frame(minWidth: 100, idealWidth: 200, maxWidth: .infinity, alignment: .leading)
                        Button("Change…") { _ = pickFolder() }
                    }
                }
                GridRow {
                    Text("Label")
                    HStack {
                        TextField("optional, used in the filename", text: $label)
                            .focused($labelFocused)
                            .onSubmit(capture)
                        Button("Capture", action: capture)
                            .keyboardShortcut(.defaultAction)
                            .disabled(busy)
                        Button("Copy", action: copyImage)
                            .keyboardShortcut("c", modifiers: [.command, .shift])
                            .disabled(lastFile == nil)
                            .help("Copy the last capture to the clipboard (⇧⌘C)")
                    }
                }
            }

            // The preview fills the window's width at the screen's 5:3 shape.
            ZStack {
                Rectangle().fill(.quaternary)
                if let preview {
                    Image(nsImage: preview).resizable().interpolation(.high)
                } else {
                    Text("No capture yet").foregroundStyle(.secondary)
                }
                if busy { ProgressView() }
            }
            .aspectRatio(800.0 / 480.0, contentMode: .fit)
            // Dragging the preview drags the saved PNG, so dropping it on a folder copies the file.
            .onDrag {
                guard let lastFile, let provider = NSItemProvider(contentsOf: lastFile) else { return NSItemProvider() }
                // Without this, Finder names the dropped file "PNG image.png".
                provider.suggestedName = lastFile.deletingPathExtension().lastPathComponent
                return provider
            }
            .contextMenu {
                Button("Copy Image", action: copyImage).disabled(lastFile == nil)
                Button("Show in Finder") {
                    if let lastFile { NSWorkspace.shared.activateFileViewerSelecting([lastFile]) }
                }
                .disabled(lastFile == nil)
            }
            .frame(minWidth: 400, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .firstTextBaseline) {
                Text(status)
                    .foregroundStyle(isError ? .red : .secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let scopeOnUSB {
                    Label {
                        Text(scopeOnUSB ? "DS2072A on USB" : "No scope on USB")
                    } icon: {
                        Circle().fill(scopeOnUSB ? .green : .secondary).frame(width: 7, height: 7)
                    }
                    .foregroundStyle(.secondary)
                    .fixedSize()
                }
            }
        }
        .padding(16)
        .onAppear {
            labelFocused = true
            watcher = ScopeWatcher { scopeOnUSB = $0 }
            // Pick the save folder at first launch; after that it's remembered.
            if folder.isEmpty { DispatchQueue.main.async { _ = pickFolder() } }
        }
    }

    /// Shows a folder picker; returns false if cancelled.
    private func pickFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Save Here"
        panel.message = "Choose where Scope Grab saves captures"
        if !folder.isEmpty { panel.directoryURL = URL(fileURLWithPath: folder) }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        folder = url.path
        return true
    }

    private func capture() {
        guard !busy else { return }
        if folder.isEmpty, !pickFolder() { return }
        busy = true
        isError = false
        status = "Capturing…"
        let label = label
        let dir = URL(fileURLWithPath: folder)
        let started = Date()

        Task {
            defer { busy = false; selectLabel() }
            do {
                // USB calls block, so they run off the main thread.
                let bmp = try await Task.detached { try Scope.session { try $0.screen() } }.value
                guard let rep = NSBitmapImageRep(data: bmp),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    throw CaptureError.notAnImage
                }
                let name = captureFilename(label: label, date: started) {
                    FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
                }
                let file = dir.appendingPathComponent(name)
                try png.write(to: file, options: .withoutOverwriting)
                lastFile = file
                preview = NSImage(data: png)
                status = "Captured \(started.formatted(date: .omitted, time: .standard)) · saved \(name)"
            } catch {
                isError = true
                status = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    /// Puts the last capture on the clipboard as PNG and TIFF, so any app can paste it.
    private func copyImage() {
        guard let lastFile, let png = try? Data(contentsOf: lastFile) else {
            status = "Can't copy: the last capture's file is gone"
            isError = true
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        status = "Copied \(lastFile.lastPathComponent) to the clipboard"
        isError = false
    }

    /// Keeps the label but selects it, so typing the next one replaces it.
    private func selectLabel() {
        labelFocused = true
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }
}

enum CaptureError: Error, LocalizedError {
    case notAnImage
    var errorDescription: String? { "the scope's reply isn't a readable image" }
}
