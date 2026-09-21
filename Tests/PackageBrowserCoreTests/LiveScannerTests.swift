import XCTest
@testable import PackageBrowserCore

/// Live integration tests — each skips itself when its manager isn't installed.
final class LiveScannerTests: XCTestCase {
    func testLiveNpm() throws {
        try XCTSkipUnless(Shell.which("npm") != nil, "npm is not installed")
        let packages = try NpmScanner().scan()
        XCTAssertFalse(packages.isEmpty)
        XCTAssertTrue(packages.allSatisfy { !$0.version.isEmpty })
    }

    func testLivePip() throws {
        try XCTSkipUnless(PipScanner().isAvailable(), "pip is not installed")
        let packages = try PipScanner().scan()
        XCTAssertFalse(packages.isEmpty)
        XCTAssertTrue(packages.contains { $0.name.lowercased() == "pip" })
    }

    func testLiveGem() throws {
        try XCTSkipUnless(Shell.which("gem") != nil, "gem is not installed")
        let packages = try GemScanner().scan()
        XCTAssertFalse(packages.isEmpty)
    }

    func testLiveBun() throws {
        // Bun with no globals returns [] rather than throwing.
        try XCTSkipUnless(Shell.which("bun") != nil, "bun is not installed")
        let packages = try BunScanner().scan()
        XCTAssertTrue(packages.allSatisfy { $0.source == .bun })
    }

    func testRegistryAvailability() {
        // On this machine brew, npm, pip and gem exist; the registry should see them.
        let available = ScannerRegistry.all.filter { $0.isAvailable() }.map(\.displayName)
        XCTAssertTrue(available.contains("Homebrew"))
    }
}
