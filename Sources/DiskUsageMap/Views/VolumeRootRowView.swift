import SwiftUI

/// A volume root is just a directory row (see FileTreeRowView) with one bit of
/// extra APFS context above it: how much of the shared container this
/// particular volume itself accounts for. See VolumeInfo for why that's the
/// only per-volume capacity number worth showing.
struct VolumeRootRowView: View {
    let root: VolumeRoot
    let containerTotalCapacity: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let used = root.volume.usedByVolume, let containerTotal = containerTotalCapacity, containerTotal > 0 {
                Text("このボリュームの使用量: \(ByteFormatter.string(used)) / コンテナ全体 \(ByteFormatter.string(containerTotal))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(ByteFormatter.string(root.volume.usedCapacity)) 使用 / \(ByteFormatter.string(root.volume.totalCapacity)) 中")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            FileTreeRowView(node: root.node)
        }
        .padding(.vertical, 2)
    }
}
