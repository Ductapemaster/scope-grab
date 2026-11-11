import SwiftUI

/// The strip along the window's bottom edge: the last result and the USB link.
struct StatusBar: View {
    @Environment(CaptureModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                message.frame(maxWidth: .infinity, alignment: .leading)
                usbIndicator
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .frame(height: 30)
        }
        .background(.bar)
    }

    @ViewBuilder private var message: some View {
        switch model.status {
        case .ready:
            if model.folder.isEmpty {
                Text("Ready").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Text("Saving to").foregroundStyle(.secondary).fixedSize()
                    FilePath(folder: model.folder, name: nil)
                }
            }
        case .capturing:
            Text("Capturing…").foregroundStyle(.secondary)
        case .saved(let name):
            if let file = model.lastFile {
                Button(action: model.showInFinder) {
                    FilePath(folder: file.deletingLastPathComponent().path, name: file.lastPathComponent)
                }
                .buttonStyle(.plain)
                .help("\(file.path)\nClick to show in Finder")
            } else {
                Text(name).lineLimit(1).truncationMode(.middle)
            }
        case .copied(let name):
            Text("Copied \(name)").foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        case .failed(let error):
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
                .textSelection(.enabled)
                .help(error)
        }
    }

    @ViewBuilder private var usbIndicator: some View {
        if let onUSB = model.scopeOnUSB {
            Label {
                Text(onUSB ? "DS2072A on USB" : "No scope on USB")
            } icon: {
                Circle().fill(onUSB ? Color.green : Color.secondary.opacity(0.6)).frame(width: 7, height: 7)
            }
            .foregroundStyle(.secondary)
            .fixedSize()
        }
    }
}

/// A path as the status bar shows it: the folder dimmed and cut in the middle when space
/// runs short, the file name in full. `~/Bench/Captures/` + `2026-11-10 14-32-05 TP4.png`.
private struct FilePath: View {
    let folder: String
    let name: String?

    var body: some View {
        HStack(spacing: 0) {
            Text((folder as NSString).abbreviatingWithTildeInPath + "/")
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            if let name {
                Text(name)
                    .lineLimit(1).truncationMode(.middle)
                    .layoutPriority(1) // the file name gives way last
            }
        }
    }
}
