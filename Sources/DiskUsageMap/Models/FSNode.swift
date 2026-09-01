import Foundation

/// A single file or directory in the scanned tree.
/// `size` for directories is the sum of all descendant sizes (allocated bytes on disk).
final class FSNode: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let children: [FSNode]
    /// Set when this node could not be fully read (permission denied, other filesystem, etc).
    let errorDescription: String?

    init(
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64,
        children: [FSNode] = [],
        errorDescription: String? = nil
    ) {
        self.id = url.path
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.errorDescription = errorDescription
    }
}
