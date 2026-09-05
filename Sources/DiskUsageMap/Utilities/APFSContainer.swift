import Foundation

enum APFSContainer {
    struct MountInfo {
        /// The volume's real, own name (e.g. "Data"), from `diskutil` directly —
        /// NOT `FileManager`'s `.volumeNameKey`, which reports every volume in a
        /// System/Data group under the paired System volume's name.
        let volumeName: String
        /// `nil` for non-APFS filesystems (exFAT, network mounts, ...), which have no container.
        let containerID: String?
    }

    /// - Parameter mountPoint: must be an actual mount point (e.g. from `MountTable`),
    ///   not an arbitrary path within a volume — `diskutil info` only accepts mount points.
    static func info(forMountPoint mountPoint: String) -> MountInfo? {
        guard let plist = DiskutilRunner.plist(["info", "-plist", mountPoint]) else { return nil }
        guard let volumeName = plist["VolumeName"] as? String else { return nil }
        return MountInfo(volumeName: volumeName, containerID: plist["APFSContainerReference"] as? String)
    }
}
