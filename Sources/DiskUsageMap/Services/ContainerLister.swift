import Foundation

enum ContainerLister {
    static func load() -> [ContainerInfo] {
        guard let plist = DiskutilRunner.plist(["apfs", "list", "-plist"]) else { return [] }
        guard let containersArray = plist["Containers"] as? [[String: Any]] else { return [] }

        return containersArray
            .compactMap { c -> ContainerInfo? in
                guard let ref = c["ContainerReference"] as? String else { return nil }
                let total = (c["CapacityCeiling"] as? NSNumber)?.int64Value ?? 0
                let free = (c["CapacityFree"] as? NSNumber)?.int64Value ?? 0
                return ContainerInfo(id: ref, totalCapacity: total, freeCapacity: free)
            }
            .sorted { $0.totalCapacity > $1.totalCapacity }
    }
}
