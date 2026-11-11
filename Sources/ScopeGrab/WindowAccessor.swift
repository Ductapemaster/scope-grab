import AppKit
import SwiftUI

/// Hands back the NSWindow a SwiftUI view sits in, once it's in one.
struct WindowAccessor: NSViewRepresentable {
    let found: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let w = view.window { found(w) } }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
