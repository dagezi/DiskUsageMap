import Foundation

/// Resolves the real, per-volume display name for a path (see APFSContainer
/// for why that has to go through `diskutil` rather than FileManager).
///
/// Since every row in the browse tree needs a label, but a `diskutil`
/// subprocess is comparatively slow, this avoids paying that cost per row:
/// `statfs` (via MountPoint, cheap — no subprocess) checks whether a path's
/// real mount differs from its already-known parent; if not, the parent's
/// label is inherited directly. `diskutil` only runs the first time a given
/// mount point is actually encountered, and the result is cached for reuse.
enum VolumeLabelResolver {
    private static var cache: [String: String] = [:]

    static func resolve(path: String, parentMountPoint: String?, parentLabel: String?) -> (mountPoint: String, label: String) {
        guard let mountPoint = MountPoint.resolve(path) else {
            return (parentMountPoint ?? path, parentLabel ?? "?")
        }
        if mountPoint == parentMountPoint, let parentLabel {
            return (mountPoint, parentLabel)
        }
        if let cached = cache[mountPoint] {
            return (mountPoint, cached)
        }
        let label = APFSContainer.volumeName(forMountPoint: mountPoint) ?? mountPoint
        cache[mountPoint] = label
        return (mountPoint, label)
    }
}
