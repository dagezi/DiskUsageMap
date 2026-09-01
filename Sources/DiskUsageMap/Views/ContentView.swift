import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        NavigationSplitView {
            VolumeListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if viewModel.isScanning {
                ScanningView(viewModel: viewModel)
            } else if viewModel.rootNode != nil {
                TreemapContainerView(viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "ボリュームまたはフォルダを選択してください",
                    systemImage: "internaldrive",
                    description: Text("左のリストからボリュームを選ぶか、フォルダを指定してスキャンします。")
                )
            }
        }
        .onAppear { viewModel.refreshVolumes() }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
