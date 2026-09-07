import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FileTreeViewModel()

    var body: some View {
        ScrollView {
            FileTreeRowView(node: viewModel.rootNode)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .environmentObject(viewModel)
    }
}
