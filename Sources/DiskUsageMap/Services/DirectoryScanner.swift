import Foundation

enum ScanError: Error {
    case cancelled
}

/// Recursively walks a directory tree and builds an `FSNode` tree with
/// on-disk allocated sizes. Mirrors what `du`/`df` report, not "logical" file size.
///
/// Scoped deliberately narrow, to fit "pick one folder, show its size fast"
/// rather than "scan a whole volume":
/// - Symbolic links are recorded as leaves and never followed.
/// - Firmlinks are never explicitly "followed" either, and need no special
///   case: a firmlinked path always resolves to a different real mount (see
///   `MountPoint`), so the plain filesystem-boundary rule below stops at it
///   on its own.
/// - Any real filesystem boundary — `statfs(2)`'s mount point, NOT `stat(2)`'s
///   `st_dev`, which Apple flattens across firmlinks (see `MountPoint.swift`)
///   — stops the walk outright. No "same APFS container, keep going"
///   exception: that mattered for scanning an entire volume, but here,
///   crossing out of the folder the user picked was never wanted anyway.
/// - Hard links are not deduplicated: each directory entry is counted as
///   encountered, same as `du` without `-l`. There's no "should I follow
///   this" decision to make for a hard link — it's a normal directory entry.
final class DirectoryScanner {
    private let fileManager = FileManager.default
    private var rootMountPoint: String?
    private var isCancelled = false

    /// `/.vol` is a legacy BSD inode-addressable pseudo-directory. Unlike every
    /// other special path, it sits on the *same* mount as its surroundings, so
    /// the filesystem-boundary rule below won't skip it on its own, and
    /// enumerating it is unbounded and best avoided. Hard-skip it defensively.
    private static let skipPaths: Set<String> = ["/.vol"]

    func cancel() {
        isCancelled = true
    }

    func scan(rootURL: URL, progress: ((Int, String) -> Void)? = nil) throws -> FSNode {
        isCancelled = false
        rootMountPoint = MountPoint.resolve(rootURL.path)
        var count = 0
        return try scanEntry(url: rootURL, progress: progress, count: &count)
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

        if let rootMountPoint, MountPoint.resolve(path) != rootMountPoint {
            return FSNode(url: url, name: name, isDirectory: true, size: 0, errorDescription: "別ファイルシステム(未スキャン)")
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
