import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: PackageStore
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            allRow
                .tag(String?.none)

            Section {
                ForEach(store.sources) { source in
                    sourceRow(source)
                        .tag(Optional(source.id))
                        .contextMenu {
                            Button("Rescan") {
                                Task { await store.rescan(sourceID: source.id) }
                            }
                            .disabled(source.status == .unavailable)
                        }
                }
            } header: {
                Text("Package Managers")
            } footer: {
                Text(store.isScanning ? "Scanning…" : (store.lastScanDescription ?? ""))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Package Browser")
    }

    private var allRow: some View {
        Label {
            Text("All Packages")
        } icon: {
            Image(systemName: "shippingbox")
        }
        .badge(store.allPackages.count)
    }

    @ViewBuilder
    private func sourceRow(_ source: PackageStore.SourceState) -> some View {
        HStack {
            Label {
                Text(source.displayName)
            } icon: {
                Image(systemName: source.symbolName)
                    .foregroundStyle(.tint)
            }
            Spacer()
            statusBadge(source)
        }
        .foregroundStyle(source.status == .unavailable ? Color.secondary : Color.primary)
    }

    @ViewBuilder
    private func statusBadge(_ source: PackageStore.SourceState) -> some View {
        switch source.status {
        case .pending, .scanning:
            ProgressView()
                .controlSize(.mini)
        case .loaded(let count):
            Text("\(count)")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .unavailable:
            Image(systemName: "slash.circle")
                .foregroundStyle(.tertiary)
                .help("Not installed on this Mac")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help("Scanning this source failed")
        }
    }
}
