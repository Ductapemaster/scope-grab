import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The last capture, framed like the scope's own display. Before the first capture it
/// shows an empty graticule. Dragging it drags the saved PNG.
struct ScreenView: View {
    @Environment(CaptureModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(EmptyScreen.screen)

            Group {
                if let preview = model.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .interpolation(.high)
                } else {
                    EmptyScreen()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(8)

            if model.busy {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.35))
                ProgressView().controlSize(.large).tint(.white)
            }

            // A brief shutter flash confirms a new capture landed.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(flash))
                .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .aspectRatio(816.0 / 496.0, contentMode: .fit) // 800 × 480 screen plus the 8 pt bezel
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .onChange(of: model.captures) {
            guard case .captured = model.status, !reduceMotion else { return }
            flash = 0.5
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        }
        .onDrag {
            // A saved capture drags its file; an unsaved one drags the image under the name Save would give it.
            if let file = model.savedFile, let provider = NSItemProvider(contentsOf: file) {
                provider.suggestedName = file.deletingPathExtension().lastPathComponent
                return provider
            }
            guard let png = model.png else { return NSItemProvider() }
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { done in
                done(png, nil)
                return nil
            }
            // Without this, Finder names the dropped file "PNG image.png".
            provider.suggestedName = (model.pendingName() as NSString).deletingPathExtension
            return provider
        }
        .contextMenu {
            Button("Copy Image", action: model.copyImage).disabled(!model.hasCapture)
            Button("Save", action: model.save).disabled(!model.canSave)
            Button("Show in Finder", action: model.showInFinder).disabled(model.savedFile == nil)
        }
        .help(model.hasCapture ? "Drag into a folder or app, or right-click to copy or save" : "")
    }
}

/// The scope's 14 × 8 division graticule, dimmed, with the prompt for the first capture.
private struct EmptyScreen: View {
    static let screen = Color(red: 0.035, green: 0.04, blue: 0.05)
    @Environment(CaptureModel.self) private var model

    var body: some View {
        ZStack {
            Graticule()
                .stroke(.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            Graticule(centreOnly: true)
                .stroke(.white.opacity(0.16), lineWidth: 1)
            VStack(spacing: 8) {
                if model.scopeOnUSB == false {
                    Image(systemName: "cable.connector.slash").font(.system(size: 30, weight: .light))
                } else {
                    SineWave()
                        .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 64, height: 26)
                        .padding(.vertical, 4)
                }
                Text(model.scopeOnUSB == false ? "Connect the scope over USB" : "Press Return to capture the scope's screen")
                    .font(.title3)
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Self.screen, in: RoundedRectangle(cornerRadius: 8)) // keeps the centre lines off the text
        }
    }
}

/// Grid lines for 14 horizontal by 8 vertical divisions, as on the DS2000A's display.
private struct Graticule: Shape {
    var centreOnly = false

    func path(in r: CGRect) -> Path {
        var p = Path()
        let cols = 14, rows = 8
        for i in 1..<cols where !centreOnly || i == cols / 2 {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: x, y: r.minY)); p.addLine(to: CGPoint(x: x, y: r.maxY))
        }
        for j in 1..<rows where !centreOnly || j == rows / 2 {
            let y = r.minY + r.height * CGFloat(j) / CGFloat(rows)
            p.move(to: CGPoint(x: r.minX, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        return p
    }
}

/// Two cycles of a sine, the trace in the empty screen (and in the app icon).
private struct SineWave: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let steps = 96
        for k in 0...steps {
            let t = CGFloat(k) / CGFloat(steps)
            let pt = CGPoint(x: r.minX + r.width * t, y: r.midY - r.height / 2 * sin(t * 4 * .pi))
            k == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}
