import SwiftUI

struct BreadcrumbView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let root = viewModel.rootNode {
                    crumb(title: root.name, size: root.size) {
                        viewModel.goToRoot()
                    }
                }
                ForEach(Array(viewModel.navigationStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    crumb(title: node.name, size: node.size) {
                        viewModel.goTo(index: index)
                    }
                }
            }
        }
    }

    private func crumb(title: String, size: Int64, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text(ByteFormatter.string(size))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
