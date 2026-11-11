import AppKit
import ScopeGrabCore
import SwiftUI

/// The save folder as a short trail, `… › parent › folder`, that always shows the folder's
/// own name in full and gives up the outer parts first. The chevron menu lists the whole
/// path, one folder per line, so a long path stays readable without taking the bar's width.
struct FolderControl: View {
    @Environment(CaptureModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Button { model.pickFolder() } label: { trail }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .frame(height: 28)
                .contentShape(Rectangle())
                .help(model.folder.isEmpty ? "Choose where captures are saved"
                      : "Saving to \((model.folder as NSString).abbreviatingWithTildeInPath)\nClick to change")

            if let url = model.folderURL {
                Rectangle().fill(Color.accentColor.opacity(0.35)).frame(width: 1, height: 16)
                Menu {
                    pathMenu(url)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 28)
                .help("Show the full path")
            }
        }
        .foregroundStyle(Color.accentColor)
        .tint(.accentColor)
        .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.45)))
    }

    /// The longest trail that fits: `… › parent › folder`, then `… › folder`, then the
    /// folder's name alone, cut in the middle only when even that is too long.
    @ViewBuilder private var trail: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
            if model.folder.isEmpty {
                Text("Choose Folder…")
            } else {
                let parts = pathTrail(model.folder)
                let name = Text(parts.last!).fontWeight(.semibold)
                let parent = parts.count > 1 ? parts[parts.count - 2] : nil
                let elided = parts.count > 2
                CappedWidth(max: 240) { ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        if elided { Text("…").opacity(0.7); separator }
                        if let parent { Text(parent).opacity(0.75); separator }
                        name
                    }
                    .fixedSize()
                    HStack(spacing: 4) {
                        if parent != nil { Text("…").opacity(0.7); separator }
                        name
                    }
                    .fixedSize()
                    name.lineLimit(1).truncationMode(.middle)
                } }
            }
        }
    }

    private var separator: some View {
        Image(systemName: "chevron.compact.right").font(.caption).opacity(0.6)
    }

    /// Every folder on the path, outermost first and indented by depth; choosing one opens it in Finder.
    @ViewBuilder private func pathMenu(_ url: URL) -> some View {
        let parts = pathTrail(model.folder)
        let urls = sequence(first: url) { $0.pathComponents.count > 1 ? $0.deletingLastPathComponent() : nil }
            .prefix(parts.count).reversed()
        ForEach(Array(zip(parts, urls).enumerated()), id: \.offset) { depth, item in
            Button {
                NSWorkspace.shared.open(item.1)
            } label: {
                Label(String(repeating: "   ", count: depth) + item.0,
                      systemImage: depth == parts.count - 1 ? "folder.fill" : "folder")
            }
        }
        Divider()
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.folder, forType: .string)
        }
        Button("Change Save Folder…") { model.pickFolder() }
    }
}

/// Offers its content at most `max` points and takes only the width the content uses,
/// so a short folder trail stays short and a long one stops at `max`.
private struct CappedWidth: Layout {
    var max: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Swift.min(proposal.width ?? max, max)
        return subviews[0].sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
