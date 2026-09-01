import SwiftUI
import AppKit

/// Volumes grouped by the APFS container they share free space with.
private struct VolumeGroup: Identifiable {
    let id: String
    let containerID: String?
    let volumes: [VolumeInfo]
}

struct VolumeListView: View {
    @ObservedObject var viewModel: ScanViewModel

    private var groups: [VolumeGroup] {
        var order: [String?] = []
        var byContainer: [String?: [VolumeInfo]] = [:]
        for volume in viewModel.volumes {
            if byContainer[volume.containerID] == nil {
                order.append(volume.containerID)
            }
            byContainer[volume.containerID, default: []].append(volume)
        }
        return order.map { containerID in
            VolumeGroup(
                id: containerID ?? byContainer[containerID]?.first?.id ?? UUID().uuidString,
                containerID: containerID,
                volumes: byContainer[containerID] ?? []
            )
        }
    }

    var body: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.volumes) { volume in
                        VolumeRow(
                            volume: volume,
                            containerTotalCapacity: group.containerID.flatMap { viewModel.containers[$0]?.totalCapacity }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.startScan(url: volume.url)
                        }
                    }
                } header: {
                    header(for: group)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    pickFolder()
                } label: {
                    Label("フォルダを選択…", systemImage: "folder.badge.plus")
                }
            }
            ToolbarItem {
                Button {
                    viewModel.refreshVolumes()
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    @ViewBuilder
    private func header(for group: VolumeGroup) -> some View {
        if let containerID = group.containerID, let container = viewModel.containers[containerID] {
            VStack(alignment: .leading, spacing: 2) {
                Text("ボリューム — コンテナ \(containerID)")
                if group.volumes.count > 1 {
                    Text(
                        "空き \(ByteFormatter.string(container.freeCapacity)) を"
                            + "\(group.volumes.count)個のボリュームで共有(コンテナ全体 \(ByteFormatter.string(container.totalCapacity)))"
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

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.startScan(url: url)
        }
    }
}

private struct VolumeRow: View {
    let volume: VolumeInfo
    /// Container's total capacity, used as the denominator for this volume's
    /// own bar when it belongs to an APFS container (see comment below).
    let containerTotalCapacity: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(volume.name)
                .font(.headline)

            if let used = volume.usedByVolume, let containerTotal = containerTotalCapacity, containerTotal > 0 {
                // APFS: total/available capacity is the *container's*, shared by
                // every volume in it — showing it per volume would misleadingly
                // imply each volume has its own separate capacity (UFS/HFS+-style).
                // CapacityInUse is the one number that's actually specific to
                // this volume, so show it relative to the container it shares.
                ProgressView(value: Double(used) / Double(containerTotal))
                Text("このボリュームの使用量: \(ByteFormatter.string(used))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: volume.usedFraction)
                    .tint(volume.usedFraction > 0.9 ? .red : .accentColor)
                HStack {
                    Text("\(ByteFormatter.string(volume.usedCapacity)) 使用")
                    Spacer()
                    Text("\(ByteFormatter.string(volume.totalCapacity)) 中")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
