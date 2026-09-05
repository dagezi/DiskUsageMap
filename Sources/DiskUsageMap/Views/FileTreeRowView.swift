import SwiftUI

/// One row, recursively containing its own children. Expanding the disclosure
/// triangle does a cheap one-level browse (see DirectoryBrowser); the
/// "サイズを調べる" button is the only thing that triggers a real recursive scan.
struct FileTreeRowView: View {
    @ObservedObject var node: FileTreeNode
    @EnvironmentObject var viewModel: FileTreeViewModel

    @State private var isExpanded = false
    @State private var isLoadingChildren = false
    @State private var browseError: String?

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeRowView(node: child)
                    }
                } else if isLoadingChildren {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                } else if let browseError {
                    Text(browseError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } label: {
                rowLabel
            }
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, node.children == nil, !isLoadingChildren else { return }
                loadChildren()
            }
        } else {
            rowLabel
        }
    }

    private func loadChildren() {
        isLoadingChildren = true
        browseError = nil
        Task {
            do {
                node.children = try DirectoryBrowser.list(node.url)
            } catch {
                browseError = "アクセス不可: \(error.localizedDescription)"
            }
            isLoadingChildren = false
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            statusView
        }
        .contentShape(Rectangle())
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
