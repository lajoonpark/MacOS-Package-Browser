import SwiftUI
import PackageBrowserCore

struct ContentView: View {
    @EnvironmentObject var store: PackageStore
    @State private var selectedPackageID: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: sourceSelection)
        } content: {
            PackageListView(store: store, selection: $selectedPackageID)
        } detail: {
            PackageDetailView(package: selectedPackage)
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search packages")
        .task {
            if store.lastScanDate == nil {
                await store.scanAll()
            }
        }
    }

    var selectedPackage: InstalledPackage? {
        selectedPackageID.flatMap { store.package(withID: $0) }
    }

    /// Switching sources drops any package selection from the previous list.
    private var sourceSelection: Binding<String?> {
        Binding(
            get: { store.selectedSourceID },
            set: { newValue in
                store.selectedSourceID = newValue
                selectedPackageID = nil
            }
        )
    }
}
