import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FileTreeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ContainerStatusBar(containers: viewModel.containers)
            Divider()
            ScrollView {
                FileTreeRowView(node: viewModel.rootNode)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .environmentObject(viewModel)
    }
}
