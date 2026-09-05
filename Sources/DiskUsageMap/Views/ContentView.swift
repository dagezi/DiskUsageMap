import SwiftUI

/// Volume roots grouped by the APFS container they share free space with —
/// same grouping as before, just as section headers over the unified tree now.
private struct VolumeGroup: Identifiable {
    let id: String
    let containerID: String?
    let roots: [VolumeRoot]
}

struct ContentView: View {
    @StateObject private var viewModel = FileTreeViewModel()

    private var groups: [VolumeGroup] {
        var order: [String?] = []
        var byContainer: [String?: [VolumeRoot]] = [:]
        for root in viewModel.volumeRoots {
            let containerID = root.volume.containerID
            if byContainer[containerID] == nil {
                order.append(containerID)
            }
            byContainer[containerID, default: []].append(root)
        }
        return order.map { containerID in
            VolumeGroup(
                id: containerID ?? byContainer[containerID]?.first?.id ?? UUID().uuidString,
                containerID: containerID,
                roots: byContainer[containerID] ?? []
            )
        }
    }

    var body: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.roots) { root in
                        VolumeRootRowView(
                            root: root,
                            containerTotalCapacity: group.containerID.flatMap { viewModel.containers[$0]?.totalCapacity }
                        )
                    }
                } header: {
                    header(for: group)
                }
            }
        }
        .environmentObject(viewModel)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.refreshVolumes()
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear { viewModel.refreshVolumes() }
    }

    @ViewBuilder
    private func header(for group: VolumeGroup) -> some View {
        if let containerID = group.containerID, let container = viewModel.containers[containerID] {
            VStack(alignment: .leading, spacing: 2) {
                Text("ボリューム — コンテナ \(containerID)")
                if group.roots.count > 1 {
                    Text(
                        "空き \(ByteFormatter.string(container.freeCapacity)) を"
                            + "\(group.roots.count)個のボリュームで共有(コンテナ全体 \(ByteFormatter.string(container.totalCapacity)))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
        } else {
            Text("ボリューム")
        }
    }
}
