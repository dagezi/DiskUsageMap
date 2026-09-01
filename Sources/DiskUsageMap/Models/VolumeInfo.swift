import Foundation

/// Summary of one mounted filesystem/volume, analogous to one row of `df`.
struct VolumeInfo: Identifiable {
    let id: String
    let name: String
    let url: URL
    let totalCapacity: Int64
    let availableCapacity: Int64
    /// APFS container reference (e.g. "disk3") this volume lives in, shared with
    /// any other volume in the same container's free-space pool. `nil` for
    /// non-APFS filesystems (exFAT, network mounts, ...).
    let containerID: String?
    /// Bytes actually written by this volume (`diskutil apfs list`'s CapacityInUse).
    /// This is the meaningful per-volume number for APFS; `totalCapacity`/
    /// `availableCapacity` above are the *container's* shared numbers, reported
    /// identically on every volume in the container unless a quota is set.
    let usedByVolume: Int64?

    var usedCapacity: Int64 {
        max(0, totalCapacity - availableCapacity)
    }

    var usedFraction: Double {
        totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0
    }
}
