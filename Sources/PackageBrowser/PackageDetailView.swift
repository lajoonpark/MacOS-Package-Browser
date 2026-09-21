import SwiftUI
import PackageBrowserCore

struct PackageDetailView: View {
    let package: InstalledPackage?

    var body: some View {
        if let package {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(package)
                    Divider()
                    facts(package)
                    if !package.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            sectionLabel("Description")
                            Text(package.description)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView {
                Label("No Package Selected", systemImage: "cursorarrow.and.square.on.square.dashed")
            } description: {
                Text("Select a package to see its details.")
            }
        }
    }

    private func header(_ package: InstalledPackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(package.name)
                    .font(.title2.bold())
                    .textSelection(.enabled)
                Text(package.version)
                    .font(.title3.monospaced())
                    .foregroundStyle(.secondary)
                if package.outdated == true {
                    Label("Update available", systemImage: "arrow.up.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
            SourceBadge(sourceID: package.source)
            if let homepage = package.homepage {
                Link(destination: homepage) {
                    Label("Homepage", systemImage: "safari")
                        .font(.callout)
                }
            }
        }
    }

    private func facts(_ package: InstalledPackage) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            if let kind = package.kind {
                GridRow {
                    sectionLabel("Kind")
                    Text(kind).textSelection(.enabled)
                }
            }
            if package.installedAsDependency == true {
                GridRow {
                    sectionLabel("Installed as")
                    Label("Dependency", systemImage: "arrow.triangle.branch")
                        .help("Pulled in because another package depends on it")
                }
            } else if package.installedAsDependency == false {
                GridRow {
                    sectionLabel("Installed as")
                    Label("Requested", systemImage: "hand.tap")
                        .help("You (or a tool acting for you) installed this directly")
                }
            }
            GridRow {
                sectionLabel("Identifier")
                Text(package.id)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.leading)
    }
}
