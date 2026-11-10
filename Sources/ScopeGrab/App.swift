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
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @AppStorage("host") private var host = "192.168.0.114"
    @AppStorage("folder") private var folder = ""
    @State private var label = ""
    @State private var preview: NSImage?
    @State private var status = "Ready"
    @State private var isError = false
    @State private var busy = false
    @FocusState private var labelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Scope").gridColumnAlignment(.trailing)
                    TextField("IP address", text: $host).frame(width: 140)
                }
                GridRow {
                    Text("Save to")
                    HStack {
                        Text(folder.isEmpty ? "No folder chosen" : (folder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1).truncationMode(.head)
                            .foregroundStyle(folder.isEmpty ? .secondary : .primary)
                            .help(folder)
                        Spacer()
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
                    }
                }
            }

            ZStack {
                Rectangle().fill(.quaternary)
                if let preview {
                    Image(nsImage: preview).resizable().interpolation(.high)
                } else {
                    Text("No capture yet").foregroundStyle(.secondary)
                }
                if busy { ProgressView() }
            }
            .frame(width: 400, height: 240)

            Text(status)
                .foregroundStyle(isError ? .red : .secondary)
                .lineLimit(2)
                .textSelection(.enabled)
                .frame(width: 400, alignment: .leading)
        }
        .padding(16)
        .onAppear {
            labelFocused = true
            // Pick the save folder at first launch; after that it's remembered.
            if folder.isEmpty { DispatchQueue.main.async { _ = pickFolder() } }        }
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
        let host = host.trimmingCharacters(in: .whitespaces)
        let label = label
        let dir = URL(fileURLWithPath: folder)
        let started = Date()

        Task {
            defer { busy = false; selectLabel() }
            do {
                let bmp = try await Scope.session(host: host) { try await $0.screen() }
                guard let rep = NSBitmapImageRep(data: bmp),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    throw CaptureError.notAnImage
                }
                let name = captureFilename(label: label, date: started) {
                    FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
                }
                // Write first: a failed write must leave the clipboard as it was.
                try png.write(to: dir.appendingPathComponent(name), options: .withoutOverwriting)
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(png, forType: .png)
                if let tiff = rep.tiffRepresentation { pb.setData(tiff, forType: .tiff) }

                preview = NSImage(data: png)
                status = "Captured \(started.formatted(date: .omitted, time: .standard)) · saved \(name)"
            } catch {
                isError = true
                status = "Capture failed: \(error.localizedDescription)"
            }
        }
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
