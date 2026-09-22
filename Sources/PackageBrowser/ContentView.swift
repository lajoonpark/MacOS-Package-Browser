import SwiftUI
import PackageBrowserCore

struct ContentView: View {
    @EnvironmentObject var store: PackageStore
    @State private var selection: SidebarItem? = .dashboard
    @State private var selectedPackageID: String?

    var body: some View {
        Group {
            if selection == .dashboard {
                dashboardSplit
            } else {
                librarySplit
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search packages")
        .task {
            if store.lastScanDate == nil {
                await store.scanAll()
            }
        }
    }

    /// Dashboard gets the full width right of the sidebar (two-column layout).
    private var dashboardSplit: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: sidebarSelection)
        } detail: {
            DashboardView(store: store) { id in
                select(.source(id))
            }
        }
    }

    /// Package lists use the classic three-column browser layout.
    private var librarySplit: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: sidebarSelection)
        } content: {
            PackageListView(store: store, selection: $selectedPackageID)
        } detail: {
            PackageDetailView(package: selectedPackage)
        }
    }

    var selectedPackage: InstalledPackage? {
        selectedPackageID.flatMap { store.package(withID: $0) }
    }

    /// Central place for sidebar selection: updates the selected source in the
    /// store (which drives filtering) and clears any old package selection.
    private func select(_ item: SidebarItem) {
        sidebarSelection.wrappedValue = item
    }

    /// Switching sidebar items drops any package selection from the previous list
    /// and tells the store which source the list should filter by.
    private var sidebarSelection: Binding<SidebarItem?> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                selectedPackageID = nil
                switch newValue {
                case .source(let id):
                    store.selectedSourceID = id
                case .dashboard, .allPackages, nil:
                    store.selectedSourceID = nil
                }
            }
        )
    }
}
