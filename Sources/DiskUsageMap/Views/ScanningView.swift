import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("スキャン中… \(viewModel.scanProgressCount)件")
                .font(.headline)
            Text(viewModel.scanProgressPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 500)
            Button("キャンセル") {
                viewModel.cancelScan()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
