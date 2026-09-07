import SwiftUI

/// One chip per APFS container, showing the shared-capacity numbers that
/// matter at the container level (see ContainerInfo) — total, used, and the
/// usage rate — independent of which particular volume within it is browsed.
/// The sort-mode switch on the trailing edge applies to every row in the tree.
struct ContainerStatusBar: View {
    let containers: [ContainerInfo]
    @Binding var sortMode: SortMode

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(containers) { container in
                        ContainerStatusChip(container: container)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer(minLength: 8)

            Picker("並び替え", selection: $sortMode) {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .background(.bar)
    }
}

private struct ContainerStatusChip: View {
    let container: ContainerInfo

    var body: some View {
        HStack(spacing: 5) {
            Text(container.id)
                .font(.caption.weight(.semibold))
            Text("\(ByteFormatter.string(container.usedCapacity))/\(ByteFormatter.string(container.totalCapacity))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(container.usedFraction * 100))%")
                .font(.caption2)
                .foregroundStyle(container.usedFraction > 0.9 ? .red : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}
