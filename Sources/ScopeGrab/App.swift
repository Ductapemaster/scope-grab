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
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 760, height: 540)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Capture Screen") { model.capture() }
                    .keyboardShortcut("r")
                    .disabled(model.busy)
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
                    .disabled(model.lastFile == nil)
                Button("Show Capture in Finder") { model.showInFinder() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.lastFile == nil)
            }
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
        @Bindable var model = model
        VStack(spacing: 0) {
            ScreenView()
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.secondary)
            StatusBar()
        }
        .frame(minWidth: 560, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Label", text: $model.label, prompt: Text("Label (optional)"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .focused($labelFocused)
                    .onSubmit(model.capture)
                    .help("Added to the filename, e.g. “TP4 IF out”")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: model.copyImage) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(model.lastFile == nil)
                .help("Copy the last capture to the clipboard (⇧⌘C)")

                Button(action: model.capture) {
                    Label("Capture", systemImage: "camera.aperture")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.busy)
                .help("Capture the scope's screen (Return)")
            }
        }
        .onAppear {
            labelFocused = true
            model.start()
        }
        // Keep the label but select it after each capture, so typing the next one replaces it.
        .onChange(of: model.captures) {
            labelFocused = true
            DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        }
    }
}
