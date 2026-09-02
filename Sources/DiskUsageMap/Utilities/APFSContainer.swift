import Foundation

enum APFSContainer {
    /// Looks up the APFS container a mount point belongs to. `nil` for
    /// non-APFS filesystems (exFAT, network mounts, ...), which have no container.
    /// - Parameter mountPoint: must be an actual mount point (e.g. from `MountPoint.resolve`),
    ///   not an arbitrary path within a volume — `diskutil info` only accepts mount points.
    static func reference(forMountPoint mountPoint: String) -> String? {
        guard let plist = DiskutilRunner.plist(["info", "-plist", mountPoint]) else { return nil }
        return plist["APFSContainerReference"] as? String
    }
}
