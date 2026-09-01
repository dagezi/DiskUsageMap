import Foundation

enum ScanError: Error {
    case cancelled
}

/// Recursively walks a directory tree and builds an `FSNode` tree with
/// on-disk allocated sizes. Mirrors what `du`/`df` report, not "logical" file size.
final class DirectoryScanner {
    private let fileManager = FileManager.default
    private var rootDeviceNumber: Int32?
    private var isCancelled = false

    /// Paths that either lead to device nodes, other remounted volumes, or
    /// virtual memory internals — not useful to walk and can be huge/slow.
    private static let skipPaths: Set<String> = [
        "/dev",
        "/Volumes",
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
        rootDeviceNumber = deviceNumber(for: rootURL)
        var count = 0
        return try scanEntry(url: rootURL, progress: progress, count: &count)
    }

    private func deviceNumber(for url: URL) -> Int32? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return (attrs[.systemNumber] as? NSNumber)?.int32Value
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

        if let rootDev = rootDeviceNumber, let dev = deviceNumber(for: url), dev != rootDev {
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
