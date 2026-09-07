import Foundation

/// Shallow, one-level directory listing — no recursion, no size totals for
/// subdirectories. This is what backs expanding a disclosure triangle: cheap
/// enough to run on every expand without the user asking for a size.
enum DirectoryBrowser {
    /// - Parameters:
    ///   - parentMountPoint: the mount point of `url` itself, already resolved
    ///     for its own node (see VolumeLabelResolver — each child's volume
    ///     label is only re-resolved via `diskutil` if its own mount differs).
    ///   - parentVolumeName: the display name that goes with `parentMountPoint`.
    static func list(_ url: URL, parentMountPoint: String, parentVolumeName: String) throws -> [FileTreeNode] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]
        let entries = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        return entries
            .map { entry -> FileTreeNode in
                let values = try? entry.resourceValues(forKeys: keys)
                let isSymlink = values?.isSymbolicLink ?? false
                let isDirectory = (values?.isDirectory ?? false) && !isSymlink

                let (mountPoint, volumeName) = VolumeLabelResolver.resolve(
                    path: entry.path,
                    parentMountPoint: parentMountPoint,
                    parentLabel: parentVolumeName
                )

                let node = FileTreeNode(url: entry, isDirectory: isDirectory, mountPoint: mountPoint, volumeName: volumeName)
                if !isDirectory {
                    // A file's (or symlink's) own size is one stat call, not a
                    // walk — cheap enough to show immediately on browse, unlike
                    // a directory's total which requires recursing.
                    let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                    node.scanState = .scanned(size: size)
                }
                return node
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
