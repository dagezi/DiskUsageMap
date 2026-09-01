import SwiftUI

struct TreemapContainerView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbView(viewModel: viewModel)
                .padding(8)
                .background(.bar)

            if let node = viewModel.currentNode {
                if let error = node.errorDescription {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                } else if node.children.isEmpty {
                    ContentUnavailableView("空のフォルダです", systemImage: "folder")
                } else {
                    TreemapView(nodes: node.children) { tapped in
                        if tapped.isDirectory && !tapped.children.isEmpty {
                            viewModel.drillDown(into: tapped)
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
}
