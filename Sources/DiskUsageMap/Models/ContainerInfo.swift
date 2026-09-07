import Foundation

/// An APFS container: the space-sharing pool that one or more volumes live in.
/// `freeCapacity` is shared across every volume in the container, unlike a
/// classic per-partition filesystem where each volume has its own fixed free space.
struct ContainerInfo: Identifiable {
    let id: String
    let totalCapacity: Int64
    let freeCapacity: Int64

    var usedCapacity: Int64 {
        max(0, totalCapacity - freeCapacity)
    }

    var usedFraction: Double {
        totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0
    }
}
