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
            Text("Ready").foregroundStyle(.secondary)
        case .capturing:
            Text("Capturing…").foregroundStyle(.secondary)
        case .saved(let name):
            Text(name).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
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
