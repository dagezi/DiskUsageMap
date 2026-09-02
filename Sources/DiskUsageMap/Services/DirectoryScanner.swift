import Foundation

enum ScanError: Error {
    case cancelled
}

/// Recursively walks a directory tree and builds an `FSNode` tree with
/// on-disk allocated sizes. Mirrors what `du`/`df` report, not "logical" file size.
///
/// Boundary detection is deliberately NOT based on `stat(2)`'s `st_dev`: Apple
/// flattens that value across firmlinks so the System+Data union looks like one
/// device, which is right for tools like `find -xdev` but wrong here — it means
/// two volumes in the *same* APFS container (e.g. the boot volume and a sibling
/// user-created volume) can report different `st_dev` even though both draw down
/// the same shared free-space pool we're trying to visualize. Instead we check,
/// in two tiers: `statfs(2)` (via `MountPoint`, same non-virtualized source `df`
/// uses) for "did we cross a real mount" (cheap, checked on every directory), and
/// only when that fires, `diskutil` for "is it still the same APFS container"
/// (expensive, so only paid at actual mount boundaries — rare during a walk).
final class DirectoryScanner {
    private let fileManager = FileManager.default
    private var rootMountPoint: String?
    private var rootContainerID: String?
    private var containerCache: [String: String?] = [:]
    private var isCancelled = false

    /// Paths that lead to device nodes, virtual memory internals, or raw
    /// re-mount points that duplicate content already reachable via firmlinks
    /// (e.g. `/System/Volumes/Data` mirrors `/Users`) — walking them would
    /// double-count. Not useful to walk regardless of container membership.
    private static let skipPaths: Set<String> = [
        "/dev",
        "/System/Volumes",
        "/private/var/vm",
        "/cores",
        "/.vol"
    ]

    func cancel() {
        isCancelled = true
    }

    func scan(rootURL: URL, progress: ((Int, String) -> Void)? = nil) throws -> FSNode {
        isCancelled = false
        containerCache = [:]
        rootMountPoint = MountPoint.resolve(rootURL.path)
        rootContainerID = rootMountPoint.flatMap { containerReference(forMountPoint: $0) }
        var count = 0
        return try scanEntry(url: rootURL, progress: progress, count: &count)
    }

    private func containerReference(forMountPoint mountPoint: String) -> String? {
        if let cached = containerCache[mountPoint] {
            return cached
        }
        let ref = APFSContainer.reference(forMountPoint: mountPoint)
        containerCache[mountPoint] = ref
        return ref
    }

    private func scanEntry(url: URL, progress: ((Int, String) -> Void)?, count: inout Int) throws -> FSNode {
        if isCancelled { throw ScanError.cancelled }

        let path = url.path
        let name = url.lastPathComponent

        if Self.skipPaths.contains(path) {
            return FSNode(url: url, name: name, isDirectory: true, size: 0, errorDescription: "スキップ対象のパス")
        }

        count += 1
        if count % 500 == 0 {
            progress?(count, path)
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        let values = try? url.resourceValues(forKeys: resourceKeys)
        let isSymlink = values?.isSymbolicLink ?? false
        let isDirectory = (values?.isDirectory ?? false) && !isSymlink

        if isSymlink {
            let size = Int64(values?.fileAllocatedSize ?? 0)
            return FSNode(url: url, name: name, isDirectory: false, size: size)
        }

        if !isDirectory {
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            return FSNode(url: url, name: name, isDirectory: false, size: size)
        }

        if let rootMountPoint, let currentMountPoint = MountPoint.resolve(path), currentMountPoint != rootMountPoint {
            let currentContainerID = containerReference(forMountPoint: currentMountPoint)
            if currentContainerID == nil || currentContainerID != rootContainerID {
                return FSNode(url: url, name: name, isDirectory: true, size: 0, errorDescription: "別コンテナ(未スキャン): \(currentMountPoint)")
            }
            // Different volume, but same APFS container: still pressures the
            // same free-space pool as the scan root, so keep descending.
        }

        var children: [FSNode] = []
        do {
            let entries = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            )
            children.reserveCapacity(entries.count)
            for entry in entries {
                let child = try scanEntry(url: entry, progress: progress, count: &count)
                children.append(child)
            }
        } catch let error as ScanError {
            throw error
        } catch {
            return FSNode(url: url, name: name, isDirectory: true, size: 0, errorDescription: "アクセス不可: \(error.localizedDescription)")
        }

        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        let sortedChildren = children.sorted { $0.size > $1.size }
        return FSNode(url: url, name: name, isDirectory: true, size: totalSize, children: sortedChildren)
    }
}
