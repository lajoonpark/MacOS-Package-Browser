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
                selection = .source(id)
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

    /// Switching sidebar items drops any package selection from the previous list.
    private var sidebarSelection: Binding<SidebarItem?> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                selectedPackageID = nil
            }
        )
    }
}
