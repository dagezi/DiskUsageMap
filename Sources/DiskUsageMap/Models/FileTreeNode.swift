import Foundation

enum ScanState {
    case notScanned
    case scanning(count: Int)
    case scanned(size: Int64)
    case error(String)

    var size: Int64 {
        if case .scanned(let size) = self { return size }
        return 0
    }
}

/// One row of the unified browse/scan tree. The same node is used both while
/// merely browsing (before any scan — `children` populated lazily, `scanState`
/// stays `.notScanned`) and after scanning (`scanState` becomes `.scanned`,
/// `children` holds every descendant with its own result). There's no separate
/// "scan result" type: a row's displayed state IS this object's current state.
final class FileTreeNode: ObservableObject, Identifiable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    /// `nil` until the directory has been browsed (disclosure expanded) or scanned.
    @Published var children: [FileTreeNode]?
    @Published var scanState: ScanState = .notScanned

    init(url: URL, isDirectory: Bool, name: String? = nil) {
        self.id = url.path
        self.url = url
        self.isDirectory = isDirectory
        let lastComponent = url.lastPathComponent
        self.name = name ?? (lastComponent.isEmpty ? url.path : lastComponent)
    }
}
