import Foundation

struct ContainerData {
    let containers: [String: ContainerInfo]
    /// Bytes actually written by each APFS volume, keyed by "<containerID>/<volumeName>".
    /// Unlike total/free capacity, this is NOT shared — it's the one per-volume
    /// number that means something without a quota configured.
    let volumeUsage: [String: Int64]
}

enum ContainerLister {
    static func load() -> ContainerData {
        guard let plist = DiskutilRunner.plist(["apfs", "list", "-plist"]) else {
            return ContainerData(containers: [:], volumeUsage: [:])
        }
        guard let containersArray = plist["Containers"] as? [[String: Any]] else {
            return ContainerData(containers: [:], volumeUsage: [:])
        }

        var containers: [String: ContainerInfo] = [:]
        var volumeUsage: [String: Int64] = [:]

        for c in containersArray {
            guard let ref = c["ContainerReference"] as? String else { continue }
            let total = (c["CapacityCeiling"] as? NSNumber)?.int64Value ?? 0
            let free = (c["CapacityFree"] as? NSNumber)?.int64Value ?? 0
            containers[ref] = ContainerInfo(id: ref, totalCapacity: total, freeCapacity: free)

            guard let volumes = c["Volumes"] as? [[String: Any]] else { continue }
            for v in volumes {
                guard let name = v["Name"] as? String else { continue }
                let inUse = (v["CapacityInUse"] as? NSNumber)?.int64Value ?? 0
                volumeUsage["\(ref)/\(name)"] = inUse
            }
        }

        return ContainerData(containers: containers, volumeUsage: volumeUsage)
    }
}
