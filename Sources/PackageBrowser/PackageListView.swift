import SwiftUI
import PackageBrowserCore

struct PackageListView: View {
    @ObservedObject var store: PackageStore
    @Binding var selection: String?
    @State private var sortOrder: [KeyPathComparator<InstalledPackage>] = [
        KeyPathComparator(\InstalledPackage.name)
    ]

    var body: some View {
        Group {
            if store.filteredPackages.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await store.scanAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Rescan all package managers (⌘R)")
                }
            }
        }
    }

    private var table: some View {
        Table(sortedPackages, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { package in
                HStack(spacing: 6) {
                    Text(package.name)
                        .fontWeight(.medium)
                    if package.outdated == true {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.orange)
                            .help("Update available")
                    }
                }
            }
            TableColumn("Version", value: \.version) { package in
                Text(package.version)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 90)
            TableColumn("Kind") { package in
                Text(package.kind ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 100)
            TableColumn("Source") { package in
                if store.selectedSourceID == nil {
                    SourceBadge(sourceID: package.source)
                } else {
                    Text(package.kind ?? "")
                        .foregroundStyle(.clear)
                }
            }
            .width(min: 60, ideal: 90)
            TableColumn("Description") { package in
                Text(package.description)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var sortedPackages: [InstalledPackage] {
        store.filteredPackages.sorted(using: sortOrder)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let selected = selectedSourceState {
            switch selected.status {
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't scan \(selected.displayName)", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await store.rescan(sourceID: selected.id) }
                    }
                }
            case .unavailable:
                ContentUnavailableView {
                    Label("\(selected.displayName) is not installed", systemImage: "slash.circle")
                } description: {
                    Text("This package manager wasn't found on this Mac.")
                }
            case .loaded:
                ContentUnavailableView {
                    Label("Nothing installed here", systemImage: "shippingbox")
                } description: {
                    Text("No packages are currently installed via \(selected.displayName).")
                } actions: {
                    Button("Rescan") {
                        Task { await store.rescan(sourceID: selected.id) }
                    }
                }
            case .pending, .scanning:
                ProgressView("Scanning \(selected.displayName)…")
            }
        } else if store.isScanning {
            ProgressView("Scanning package managers…")
        } else if store.sources.allSatisfy({ $0.status == .unavailable }) {
            ContentUnavailableView {
                Label("No package managers found", systemImage: "shippingbox")
            } description: {
                Text("Install Homebrew, Bun, npm, Nix, pkgx, pip, Cargo or RubyGems to see your packages here.")
            }
        } else if !store.searchText.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else {
            ContentUnavailableView("No packages found", systemImage: "shippingbox")
        }
    }

    private var selectedSourceState: PackageStore.SourceState? {
        store.selectedSourceID.flatMap { id in store.sources.first { $0.id == id } }
    }

    private var subtitle: String {
        let total = store.filteredPackages.count
        if store.searchText.isEmpty {
            return "\(total) package\(total == 1 ? "" : "s")"
        }
        return "\(total) match\(total == 1 ? "" : "es")"
    }
}

/// Shared per-manager color mapping used by badges, charts, and the icon.
enum SourcePalette {
    static func color(for sourceID: PackageSourceID) -> Color {
        switch sourceID {
        case .homebrew: .orange
        case .bun: .yellow
        case .npm: .red
        case .nix: .blue
        case .pkgx: .purple
        case .pip: .cyan
        case .cargo: .brown
        case .gem: .pink
        }
    }

    static func label(for sourceID: PackageSourceID) -> String {
        switch sourceID {
        case .homebrew: "Homebrew"
        case .bun: "Bun"
        case .npm: "npm"
        case .nix: "Nix"
        case .pkgx: "pkgx"
        case .pip: "pip"
        case .cargo: "Cargo"
        case .gem: "RubyGems"
        }
    }
}

/// Small colored chip naming the package manager a row came from.
struct SourceBadge: View {
    let sourceID: PackageSourceID

    var body: some View {
        Text(SourcePalette.label(for: sourceID))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SourcePalette.color(for: sourceID).opacity(0.18), in: Capsule())
            .foregroundStyle(SourcePalette.color(for: sourceID))
    }
}
