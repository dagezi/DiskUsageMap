import Foundation

enum APFSContainer {
    /// The volume's real, own name (e.g. "Data"), from `diskutil` directly —
    /// NOT `FileManager`'s `.volumeNameKey`, which reports every volume in a
    /// System/Data group under the paired System volume's name.
    /// - Parameter mountPoint: must be an actual mount point (e.g. from `MountPoint`),
    ///   not an arbitrary path within a volume — `diskutil info` only accepts mount points.
    static func volumeName(forMountPoint mountPoint: String) -> String? {
        guard let plist = DiskutilRunner.plist(["info", "-plist", mountPoint]) else { return nil }
        return plist["VolumeName"] as? String
    }
}
