import Foundation

enum VolumeLister {
    /// - Parameter volumeUsage: "<containerID>/<volumeName>" -> CapacityInUse,
    ///   from `ContainerLister.load()`. Pass `[:]` if unavailable.
    static func listVolumes(volumeUsage: [String: Int64] = [:]) -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsBrowsableKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        var result: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.volumeIsBrowsable ?? true else { continue }
            guard let total = values.volumeTotalCapacity, total > 0 else { continue }
            let available = values.volumeAvailableCapacity ?? 0
            let name = values.volumeName ?? url.lastPathComponent
            let containerID = containerReference(for: url)
            let usedByVolume = containerID.flatMap { volumeUsage["\($0)/\(name)"] }
            result.append(
                VolumeInfo(
                    id: url.path,
                    name: name,
                    url: url,
                    totalCapacity: Int64(total),
                    availableCapacity: Int64(available),
                    containerID: containerID,
                    usedByVolume: usedByVolume
                )
            )
        }
        return result.sorted { $0.totalCapacity > $1.totalCapacity }
    }

    private static func containerReference(for url: URL) -> String? {
        APFSContainer.reference(forMountPoint: url.path)
    }
}
