import Foundation
import SwiftUI

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var containers: [String: ContainerInfo] = [:]
    @Published var rootNode: FSNode?
    @Published var navigationStack: [FSNode] = []
    @Published var isScanning = false
    @Published var scanProgressCount = 0
    @Published var scanProgressPath = ""
    @Published var errorMessage: String?

    private var scanner: DirectoryScanner?

    var currentNode: FSNode? {
        navigationStack.last ?? rootNode
    }

    func refreshVolumes() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let containerData = ContainerLister.load()
            let volumes = VolumeLister.listVolumes(volumeUsage: containerData.volumeUsage)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.volumes = volumes
                self.containers = containerData.containers
            }
        }
    }

    func drillDown(into node: FSNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        navigationStack.append(node)
    }

    func goToRoot() {
        navigationStack.removeAll()
    }

    /// index == -1 means "go to root"; otherwise go to that position in the breadcrumb.
    func goTo(index: Int) {
        if index < 0 {
            navigationStack.removeAll()
        } else if index + 1 < navigationStack.count {
            navigationStack.removeSubrange((index + 1)...)
        }
    }

    func startScan(url: URL) {
        isScanning = true
        rootNode = nil
        navigationStack = []
        errorMessage = nil
        scanProgressCount = 0
        scanProgressPath = ""

        let scanner = DirectoryScanner()
        self.scanner = scanner

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let node = try scanner.scan(rootURL: url) { count, path in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.scanProgressCount = count
                        self.scanProgressPath = path
                    }
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.rootNode = node
                    self.isScanning = false
                }
            } catch is ScanError {
                await MainActor.run { [weak self] in
                    self?.isScanning = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isScanning = false
                    self.errorMessage = "スキャンに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    func cancelScan() {
        scanner?.cancel()
        isScanning = false
    }
}
