import Foundation

enum ScanError: Error {
    case cancelled
}

/// Recursively fills in a `FileTreeNode` subtree in place with on-disk
/// allocated sizes (mirrors `du`/`df`, not "logical" file size), mutating the
/// same nodes the UI displays — a row's result appears in that row because
/// it IS that row's state, not a separate result handed back.
///
/// Runs on the main actor deliberately: the individual syscalls (`stat`,
/// `contentsOfDirectory`) are fast, and periodic `Task.yield()` keeps the UI
/// responsive without needing to hop `@Published` mutations across actors for
/// every node — see the yield in `scanEntry`.
///
/// A node already in `.scanned` state is left untouched instead of re-walked:
/// scanning a directory whose children were already scanned individually (or
/// scanning it a second time) reuses that cached result. This is what makes
/// "scan the parent" cheap once its children are already known.
///
/// Boundary handling, unchanged from before:
/// - Symbolic links are never followed (`DirectoryBrowser` marks them as
///   non-directory leaves up front, so they never reach the recursion below).
/// - Firmlinks need no special case: a firmlinked path always resolves to a
///   different real mount (see `MountPoint`), so the plain boundary check
///   below stops at it on its own.
/// - Hard links are not deduplicated — counted as encountered, like `du`
///   without `-l`.
@MainActor
final class DirectoryScanner {
    private var rootMountPoint: String?
    private var isCancelled = false
    private var visitedCount = 0

    /// `/.vol` is a legacy BSD inode-addressable pseudo-directory. It sits on
    /// the *same* mount as its surroundings, so the boundary check below won't
    /// skip it on its own, and enumerating it is unbounded — hard-skip it.
    private static let skipPaths: Set<String> = ["/.vol"]

    func cancel() {
        isCancelled = true
    }

    func scan(_ node: FileTreeNode) async throws {
        isCancelled = false
        visitedCount = 0
        rootMountPoint = MountPoint.resolve(node.url.path)
        try await scanEntry(node)
    }

    private func scanEntry(_ node: FileTreeNode) async throws {
        if isCancelled { throw ScanError.cancelled }

        if case .scanned = node.scanState {
            return // cache hit — reuse as-is, don't re-walk
        }

        visitedCount += 1
        if visitedCount % 300 == 0 {
            await Task.yield()
            if isCancelled { throw ScanError.cancelled }
        }

        // Files/symlinks are always pre-scanned by DirectoryBrowser before they
        // can reach here (see the .scanned check above); this is just a guard
        // against a stray non-directory node with no cached size yet.
        guard node.isDirectory else {
            if case .scanned = node.scanState {} else {
                node.scanState = .scanned(size: 0)
            }
            return
        }

        let path = node.url.path

        if Self.skipPaths.contains(path) {
            node.scanState = .error("スキップ対象のパス")
            return
        }

        if let rootMountPoint, MountPoint.resolve(path) != rootMountPoint {
            node.scanState = .error("別ファイルシステム(未スキャン)")
            return
        }

        node.scanState = .scanning(count: visitedCount)

        let children: [FileTreeNode]
        if let existing = node.children {
            children = existing
        } else {
            do {
                children = try DirectoryBrowser.list(node.url, parentMountPoint: node.mountPoint, parentVolumeName: node.volumeName)
            } catch {
                node.scanState = .error("アクセス不可: \(error.localizedDescription)")
                return
            }
            node.children = children
        }

        var total: Int64 = 0
        for child in children {
            try await scanEntry(child)
            total += child.scanState.size
        }

        // Sorting is a display concern (see FileTreeRowView.sortedChildren) —
        // just reassign the same array so this row's view re-renders and picks
        // up every child's now-final size.
        node.children = children
        node.scanState = .scanned(size: total)
    }
}
