import Foundation

@MainActor
final class FileTreeViewModel: ObservableObject {
    @Published private(set) var rootNode: FileTreeNode
    @Published private(set) var containers: [ContainerInfo] = []
    @Published var sortMode: SortMode = .size

    private var scanners: [String: DirectoryScanner] = [:]

    init() {
        let rootURL = URL(fileURLWithPath: "/")
        let (mountPoint, volumeName) = VolumeLabelResolver.resolve(path: "/", parentMountPoint: nil, parentLabel: nil)
        rootNode = FileTreeNode(url: rootURL, isDirectory: true, mountPoint: mountPoint, volumeName: volumeName, name: "/")
        refreshContainers()
    }

    func refreshContainers() {
        Task {
            containers = ContainerLister.load()
        }
    }

    func scan(_ node: FileTreeNode) {
        guard scanners[node.id] == nil else { return }
        let scanner = DirectoryScanner()
        scanners[node.id] = scanner
        Task {
            do {
                try await scanner.scan(node)
            } catch is ScanError {
                node.scanState = .notScanned
            } catch {
                node.scanState = .error(error.localizedDescription)
            }
            scanners[node.id] = nil
        }
    }

    func cancelScan(_ node: FileTreeNode) {
        scanners[node.id]?.cancel()
    }

    func isScanning(_ node: FileTreeNode) -> Bool {
        scanners[node.id] != nil
    }
}
