import Foundation

/// One top-level row: a mounted volume, plus the APFS container metadata
/// needed for the section header/usage bar (see FileTreeRootRowView).
struct VolumeRoot: Identifiable {
    let id: String
    let node: FileTreeNode
    let volume: VolumeInfo
}

@MainActor
final class FileTreeViewModel: ObservableObject {
    @Published var volumeRoots: [VolumeRoot] = []
    @Published var containers: [String: ContainerInfo] = [:]

    private var scanners: [String: DirectoryScanner] = [:]

    func refreshVolumes() {
        Task {
            let containerData = ContainerLister.load()
            let volumes = VolumeLister.listVolumes(volumeUsage: containerData.volumeUsage)
            containers = containerData.containers
            volumeRoots = volumes.map { volume in
                VolumeRoot(
                    id: volume.id,
                    node: FileTreeNode(url: volume.url, isDirectory: true, name: volume.name),
                    volume: volume
                )
            }
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
