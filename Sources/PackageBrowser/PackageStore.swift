import SwiftUI
import PackageBrowserCore

/// Drives all scanners and publishes per-source progress to the views.
@MainActor
final class PackageStore: ObservableObject {
    enum SourceStatus: Equatable {
        case pending
        case scanning
        case loaded(Int)
        case unavailable
        case failed(String)
    }

    struct SourceState: Identifiable {
        let scanner: any PackageScanner
        var status: SourceStatus = .pending
        var packages: [InstalledPackage] = []

        var id: String { scanner.id.rawValue }
        var displayName: String { scanner.displayName }
        var symbolName: String { scanner.symbolName }
    }

    @Published var sources: [SourceState]
    /// nil selects "All Packages".
    @Published var selectedSourceID: String?
    @Published var searchText = ""
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    init(scanners: [any PackageScanner] = ScannerRegistry.all) {
        sources = scanners.map { SourceState(scanner: $0) }
    }

    var allPackages: [InstalledPackage] {
        sources.flatMap(\.packages)
    }

    /// Sidebar footer text describing scan freshness.
    var lastScanDescription: String? {
        guard let lastScanDate else { return nil }
        return "Last scanned \(lastScanDate.formatted(date: .omitted, time: .shortened))"
    }

    var filteredPackages: [InstalledPackage] {
        let base: [InstalledPackage]
        if let selectedSourceID {
            base = sources.first { $0.id == selectedSourceID }?.packages ?? []
        } else {
            base = allPackages
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    func package(withID id: String) -> InstalledPackage? {
        allPackages.first { $0.id == id }
    }

    /// Rescans one source, showing its spinner while it runs. The scan itself
    /// runs off the main actor so the UI stays responsive.
    func rescan(sourceID: String) async {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else { return }
        guard sources[index].scanner.isAvailable() else {
            sources[index].status = .unavailable
            return
        }
        sources[index].status = .scanning
        let scanner = sources[index].scanner
        let result = await Task.detached { Self.performScan(scanner) }.value
        apply(index: index, result: result)
        lastScanDate = Date()
    }

    /// Scans every installed manager concurrently; unavailable ones are marked so.
    /// Already-loaded sources keep their lists visible until fresh results land.
    func scanAll() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        for index in sources.indices {
            if sources[index].scanner.isAvailable() {
                if case .pending = sources[index].status {
                    sources[index].status = .scanning
                }
            } else {
                sources[index].status = .unavailable
                sources[index].packages = []
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for index in sources.indices where sources[index].scanner.isAvailable() {
                let scanner = sources[index].scanner
                group.addTask {
                    let result = Self.performScan(scanner)
                    await self.apply(index: index, result: result)
                }
            }
        }

        lastScanDate = Date()
    }

    private nonisolated static func performScan(_ scanner: any PackageScanner) -> Result<[InstalledPackage], Error> {
        do {
            return .success(try scanner.scan())
        } catch {
            return .failure(error)
        }
    }

    private func apply(index: Int, result: Result<[InstalledPackage], Error>) {
        switch result {
        case .success(let packages):
            sources[index].packages = packages.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            sources[index].status = .loaded(packages.count)
        case .failure(let error):
            sources[index].status = .failed(error.localizedDescription)
            sources[index].packages = []
        }
    }
}
