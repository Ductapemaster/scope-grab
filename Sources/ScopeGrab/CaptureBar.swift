import ScopeGrabCore
import SwiftUI

/// The row above the preview that reads as one sentence: save to this folder, under this
/// name, then capture. The two colored controls are the two things a capture depends on.
struct CaptureBar: View {
    @Environment(CaptureModel.self) private var model
    var labelFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            field("Save to") {
                FolderControl()
            }

            field("File name") {
                HStack(spacing: 6) {
                    NameField(labelFocused: labelFocused)
                    SettingsLink {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                    .help("Change the file name pattern (⌘,)")
                }
            }

            Button(action: model.copyImage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .controlSize(.large)
            .fixedSize()
            .disabled(model.lastFile == nil)
            .help("Copy the last capture to the clipboard (⇧⌘C)")

            Button(action: model.capture) {
                Label("Capture", systemImage: "camera.aperture")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fixedSize()
            .keyboardShortcut(.defaultAction)
            .disabled(model.busy)
            .help("Capture the scope's screen (Return)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func field(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}

/// The next capture's file name, live, with the label editable in place, so it's plain
/// where the label lands relative to the date and time.
private struct NameField: View {
    @Environment(CaptureModel.self) private var model
    var labelFocused: FocusState<Bool>.Binding

    var body: some View {
        @Bindable var model = model
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let parts = FilenameTemplate(model.template).parts(date: context.date)
            HStack(spacing: 0) {
                Text(parts.before).foregroundStyle(.secondary).fixedSize()
                TextField("Label", text: $model.label, prompt: Text("label (optional)"))
                    .textFieldStyle(.plain)
                    .focused(labelFocused)
                    .onSubmit(model.capture)
                    .frame(minWidth: 80)
                Text(parts.after).foregroundStyle(.secondary).fixedSize()
            }
            .monospacedDigit()
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(labelFocused.wrappedValue ? Color.accentColor : Color(nsColor: .separatorColor),
                                  lineWidth: labelFocused.wrappedValue ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { labelFocused.wrappedValue = true }
            .help("The next capture's file name. Type a label; the date and time are filled in when you capture.")
        }
    }
}

/// Settings (⌘,): the file name pattern.
struct SettingsView: View {
    @Environment(CaptureModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                TextField("File name pattern", text: $model.template)
                    .monospaced()
                LabeledContent("Example") {
                    Text(FilenameTemplate(model.template).filename(label: "TP4 IF out", date: .now) { _ in false })
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("{date} is the capture date (2026-11-10), {time} the time (14-32-05), {label} what you type before capturing. With no label, the separators around it are dropped. A pattern without {label} gets it added at the end.")
                    Button("Restore Default") { model.template = FilenameTemplate.standard }
                        .disabled(model.template == FilenameTemplate.standard)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
