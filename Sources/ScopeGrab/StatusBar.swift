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

    /// The last action taken; nothing before the first one.
    @ViewBuilder private var message: some View {
        switch model.status {
        case .none:
            EmptyView()
        case .capturing:
            Text("Capturing…").foregroundStyle(.secondary)
        case .captured(let date):
            Text("Captured the screen at \(date.formatted(date: .omitted, time: .standard))")
                .foregroundStyle(.secondary)
        case .saved(let file):
            Button(action: model.showInFinder) {
                HStack(spacing: 0) {
                    Text("Saved ").foregroundStyle(.secondary).fixedSize()
                    Text(file.lastPathComponent).lineLimit(1).truncationMode(.middle).layoutPriority(1)
                    Text(" to ").foregroundStyle(.secondary).fixedSize()
                    Text((file.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .help("\(file.path)\nClick to show in Finder")
        case .copied(let name):
            Text("Copied \(name) to the clipboard").foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
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
