import Foundation

enum VolumeLister {
    /// - Parameter volumeUsage: "<containerID>/<volumeName>" -> CapacityInUse,
    ///   from `ContainerLister.load()`. Pass `[:]` if unavailable.
    static func listVolumes(volumeUsage: [String: Int64] = [:]) -> [VolumeInfo] {
        var result: [VolumeInfo] = []
        // Dedupe by (containerID, name): a volume can be reachable through more
        // than one mount point (e.g. the boot volume's sealed snapshot at `/`
        // vs its raw, internal-use mount at `/System/Volumes/Update/mnt1` —
        // both named "Macintosh HD" by diskutil). Prefer the shorter path as
        // the more canonical one.
        var bestMountPointByKey: [String: String] = [:]

        for mount in MountTable.currentMounts() where mount.fsTypeName == "apfs" {
            guard let info = APFSContainer.info(forMountPoint: mount.mountPoint) else { continue }
            guard let containerID = info.containerID else { continue }
            let key = "\(containerID)/\(info.volumeName)"
            if let existing = bestMountPointByKey[key], existing.count <= mount.mountPoint.count {
                continue
            }
            bestMountPointByKey[key] = mount.mountPoint
        }

        for (key, mountPoint) in bestMountPointByKey {
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let containerID = String(parts[0])
            let name = String(parts[1])
            let url = URL(fileURLWithPath: mountPoint)
            guard let capacity = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                  let total = capacity.volumeTotalCapacity, total > 0 else { continue }
            let available = capacity.volumeAvailableCapacity ?? 0
            result.append(
                VolumeInfo(
                    id: mountPoint,
                    name: name,
                    url: url,
                    totalCapacity: Int64(total),
                    availableCapacity: Int64(available),
                    containerID: containerID,
                    usedByVolume: volumeUsage[key]
                )
            )
        }

        // Non-APFS volumes (exFAT, network shares, ...) have no container and
        // never show up via diskutil's APFS-only info above — fall back to
        // FileManager for those, same as before.
        let seenMountPoints = Set(result.map(\.id))
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsBrowsableKey]
        if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for url in urls where !seenMountPoints.contains(url.path) {
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                guard values.volumeIsBrowsable ?? true else { continue }
                guard let total = values.volumeTotalCapacity, total > 0 else { continue }
                let available = values.volumeAvailableCapacity ?? 0
                let name = values.volumeName ?? url.lastPathComponent
                result.append(
                    VolumeInfo(
                        id: url.path,
                        name: name,
                        url: url,
                        totalCapacity: Int64(total),
                        availableCapacity: Int64(available),
                        containerID: nil,
                        usedByVolume: nil
                    )
                )
            }
        }

        return result.sorted { ($0.usedByVolume ?? $0.usedCapacity) > ($1.usedByVolume ?? $1.usedCapacity) }
    }
}
