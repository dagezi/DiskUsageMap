import SwiftUI

/// One row, recursively containing its own children. Expanding does a cheap
/// one-level browse (see DirectoryBrowser); the "サイズを調べる" button is the
/// only thing that triggers a real recursive scan.
///
/// Deliberately not `DisclosureGroup`: its label area doesn't reliably receive
/// taps inside a macOS `List` (the List's own row-click handling wins the
/// gesture), so expansion silently did nothing. A plain `Button` integrates
/// with AppKit's click handling properly, so we roll the chevron by hand.
struct FileTreeRowView: View {
    @ObservedObject var node: FileTreeNode
    @EnvironmentObject var viewModel: FileTreeViewModel

    @State private var isExpanded = false
    @State private var isLoadingChildren = false
    @State private var browseError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowLabel

            if isExpanded {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeRowView(node: child)
                            .padding(.leading, 16)
                    }
                } else if isLoadingChildren {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 20)
                } else if let browseError {
                    Text(browseError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 20)
                }
            }
        }
    }

    private func toggleExpansion() {
        guard node.isDirectory else { return }
        isExpanded.toggle()
        if isExpanded, node.children == nil, !isLoadingChildren {
            loadChildren()
        }
    }

    private func loadChildren() {
        isLoadingChildren = true
        browseError = nil
        Task {
            do {
                node.children = try DirectoryBrowser.list(node.url, parentMountPoint: node.mountPoint, parentVolumeName: node.volumeName)
            } catch {
                browseError = "アクセス不可: \(error.localizedDescription)"
            }
            isLoadingChildren = false
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            Button(action: toggleExpansion) {
                HStack(spacing: 8) {
                    Group {
                        if node.isDirectory {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                        } else {
                            Color.clear
                        }
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                    Image(systemName: node.isDirectory ? "folder" : "doc")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(node.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!node.isDirectory)

            Text(node.volumeName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())

            Spacer(minLength: 8)
            statusView
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusView: some View {
        switch node.scanState {
        case .notScanned:
            if node.isDirectory {
                Button("サイズを調べる") {
                    viewModel.scan(node)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        case .scanning(let count):
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("\(count)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("キャンセル") {
                    viewModel.cancelScan(node)
                }
                .buttonStyle(.borderless)
                .font(.caption2)
            }
        case .scanned(let size):
            Text(ByteFormatter.string(size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .error(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
