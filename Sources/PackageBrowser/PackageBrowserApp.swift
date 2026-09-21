import SwiftUI
import AppKit
import PackageBrowserCore

@main
struct PackageBrowserApp: App {
    @StateObject private var store = PackageStore()

    var body: some Scene {
        WindowGroup("Package Browser") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 880, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 740)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            PackageCommands(store: store)
        }
    }
}

struct PackageCommands: Commands {
    @ObservedObject var store: PackageStore

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Package Browser") {
                let credits = NSAttributedString(
                    string: "All your Mac's package managers in one window.\n\nHomebrew · Bun · npm · Nix · pkgx · pip · Cargo · RubyGems",
                    attributes: [.font: NSFont.systemFont(ofSize: 11)]
                )
                NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
            }
        }
        CommandMenu("Packages") {
            Button("Rescan All Sources") {
                Task { await store.scanAll() }
            }
            .keyboardShortcut("r", modifiers: .command)
            Button("Rescan Selected Source") {
                if let id = store.selectedSourceID {
                    Task { await store.rescan(sourceID: id) }
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(store.selectedSourceID == nil)
        }
    }
}
