import SwiftUI

/// One chip per APFS container, showing the shared-capacity numbers that
/// matter at the container level (see ContainerInfo) — total, used, and the
/// usage rate — independent of which particular volume within it is browsed.
struct ContainerStatusBar: View {
    let containers: [ContainerInfo]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(containers) { container in
                    ContainerStatusChip(container: container)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct ContainerStatusChip: View {
    let container: ContainerInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(container.id)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(Int(container.usedFraction * 100))%")
                    .font(.caption2)
                    .foregroundStyle(container.usedFraction > 0.9 ? .red : .secondary)
            }
            Text("\(ByteFormatter.string(container.usedCapacity)) / \(ByteFormatter.string(container.totalCapacity))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 180, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
