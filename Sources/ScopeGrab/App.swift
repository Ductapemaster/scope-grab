import AppKit
import SwiftUI

@main
struct ScopeGrabApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = CaptureModel()

    var body: some Scene {
        Window("Scope Grab", id: "main") {
            ContentView()
                .environment(model)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Capture Screen") { model.capture() }
                    .keyboardShortcut("r")
                    .disabled(model.busy)
                Button("Save Capture") { model.save() }
                    .keyboardShortcut("s")
                    .disabled(!model.canSave)
                Divider()
                Button("Change Save Folder…") { model.pickFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Open Save Folder") { model.openFolder() }
                    .disabled(model.folderURL == nil)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                // ⇧⌘C, not ⌘C: the label field keeps ⌘C for copying text.
                Button("Copy Capture") { model.copyImage() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!model.hasCapture)
                Button("Show Capture in Finder") { model.showInFinder() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.savedFile == nil)
            }
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @Environment(CaptureModel.self) private var model
    @FocusState private var labelFocused: Bool
    @State private var window: NSWindow?
    @State private var area = CGSize.zero

    static let margin = 20.0

    var body: some View {
        VStack(spacing: 0) {
            CaptureBar(labelFocused: $labelFocused)
            Divider()
            ScreenView()
                .padding(ContentView.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.secondary)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { area = $0; fitWindow() }
            StatusBar()
        }
        .frame(minWidth: 760, minHeight: 440)
        .background(WindowAccessor { window = $0; fitWindow() })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndLiveResizeNotification)) { note in
            if note.object as? NSWindow === window { fitWindow() }
        }
        .onAppear {
            labelFocused = true
            model.start()
        }
        // Keep the label but select it after each capture and save, so typing the next one replaces it.
        .onChange(of: model.captures) { selectLabel() }
        .onChange(of: model.saves) { selectLabel() }
    }

    /// Sets the window's height from its width so the scope screen has the same margin on
    /// all four sides. Waits for a live resize to end rather than fighting the drag.
    private func fitWindow() {
        guard let window, !window.inLiveResize, area.width > 0 else { return }
        let m = Self.margin
        let wanted = ((area.width - 2 * m) * ScreenView.aspect + 2 * m).rounded()
        var delta = wanted - area.height
        guard abs(delta) > 1 else { return }
        var frame = window.frame
        if let screen = window.screen?.visibleFrame { delta = min(delta, screen.height - frame.height) }
        frame.origin.y -= delta // keep the top edge where it is
        frame.size.height += delta
        window.setFrame(frame, display: true)
    }

    private func selectLabel() {
        labelFocused = true
        DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
    }
}
