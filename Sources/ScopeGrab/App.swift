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

    var body: some View {
        VStack(spacing: 0) {
            CaptureBar(labelFocused: $labelFocused)
            Divider()
            ScreenView()
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.secondary)
            StatusBar()
        }
        .frame(minWidth: 760, minHeight: 440)
        .onAppear {
            labelFocused = true
            model.start()
        }
        // Keep the label but select it after each capture and save, so typing the next one replaces it.
        .onChange(of: model.captures) { selectLabel() }
        .onChange(of: model.saves) { selectLabel() }
    }

    private func selectLabel() {
        labelFocused = true
        DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
    }
}
