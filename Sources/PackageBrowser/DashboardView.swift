import SwiftUI
import PackageBrowserCore

/// Home view: stat cards plus a donut of how the library is composed
/// across package managers, styled after a metrics-dashboard layout.
struct DashboardView: View {
    @ObservedObject var store: PackageStore
    var onSelectSource: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.allPackages.isEmpty && store.sources.allSatisfy({ $0.status == .unavailable }) {
                    emptyCard(
                        title: "No package managers found",
                        message: "Install Homebrew, Bun, npm, Nix, pkgx, pip, Cargo or RubyGems to see your library here.",
                        systemImage: "shippingbox"
                    )
                } else if store.isScanning && store.allPackages.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Scanning package managers…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    HStack(spacing: 16) {
                        statCard
                        updatesCard
                        managersCard
                    }
                    compositionCard
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Stats

    private var total: Int { store.allPackages.count }
    private var updates: Int { store.allPackages.filter { $0.outdated == true }.count }

    private var activeManagers: Int {
        store.sources.filter {
            if case .loaded = $0.status { return true }
            return false
        }.count
    }

    private var statCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(total)").font(.title2.bold()).monospacedDigit()
                Text("installed").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var updatesCard: some View {
        let current = updates == 0
        return HStack(spacing: 14) {
            Image(systemName: current ? "checkmark.circle" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(current ? Color.green : Color.orange)
                .frame(width: 42, height: 42)
                .background((current ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(current ? "All current" : "\(updates) to update")
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(current ? "nothing outdated" : "updates available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var managersCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 42, height: 42)
                .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeManagers)").font(.title2.bold()).monospacedDigit()
                Text("of \(store.sources.count) managers active").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Composition

    private var segments: [(id: String, name: String, color: Color, count: Int)] {
        store.sources.compactMap { state in
            guard case .loaded(let count) = state.status, count > 0 else { return nil }
            return (state.id, state.displayName, SourcePalette.color(for: state.scanner.id), count)
        }
    }

    private var compositionCard: some View {
        let donutSegments = segments.map { segment in
            DonutChartView.Segment(
                id: segment.id,
                color: segment.color,
                fraction: total > 0 ? Double(segment.count) / Double(total) : 0
            )
        }

        return VStack(alignment: .leading, spacing: 18) {
            Text("Library composition")
                .font(.headline)
            HStack(alignment: .center, spacing: 36) {
                DonutChartView(
                    segments: donutSegments,
                    centerLabel: "\(total)",
                    centerCaption: "packages"
                )
                .frame(width: 180, height: 180)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments, id: \.id) { segment in
                        Button {
                            onSelectSource(segment.id)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.color)
                                    .frame(width: 10, height: 10)
                                Text(segment.name)
                                Spacer(minLength: 16)
                                Text("\(segment.count)")
                                    .monospacedDigit()
                                Text(percent(for: segment.count))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(minWidth: 52, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 340)

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func percent(for count: Int) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(count) / Double(total) * 100)
    }

    private func emptyCard(title: String, message: String, systemImage: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Donut chart drawn with Canvas (SectorMark requires macOS 15; we target 14).
struct DonutChartView: View {
    struct Segment: Identifiable {
        let id: String
        let color: Color
        let fraction: Double
    }

    let segments: [Segment]
    var centerLabel: String
    var centerCaption: String

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 4
            let ringWidth = outer * 0.42
            let radius = outer - ringWidth / 2

            if segments.isEmpty {
                var ring = Path()
                ring.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
                context.stroke(ring, with: .color(.gray.opacity(0.2)), lineWidth: ringWidth)
                return
            }

            let gap: Double = segments.count > 1 ? 2 : 0
            var start = Angle.degrees(-90)
            for segment in segments {
                let sweep = max(segment.fraction * 360 - gap, 0.5)
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: start + .degrees(sweep),
                    clockwise: false
                )
                context.stroke(arc, with: .color(segment.color), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                start += .degrees(segment.fraction * 360)
            }
        }
        .overlay {
            VStack(spacing: 0) {
                Text(centerLabel)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(centerCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
