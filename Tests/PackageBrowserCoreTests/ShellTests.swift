import XCTest
@testable import PackageBrowserCore

final class ShellTests: XCTestCase {
    func testWhichFindsSystemCommand() {
        XCTAssertEqual(Shell.which("ls"), "/bin/ls")
    }

    func testWhichReturnsNilForUnknownCommand() {
        XCTAssertNil(Shell.which("definitely-not-a-real-command-xyz"))
    }

    func testSearchPathIncludesSystemBinaries() {
        XCTAssertTrue(Shell.searchPath.contains("/usr/bin"))
    }

    func testRunAbsoluteExecutable() throws {
        let result = try Shell.run(path: "/bin/echo", ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testRunResolvesUserPath() throws {
        // Resolving a brew-managed tool proves the login-shell PATH injection
        // works for GUI launches (skip on machines without brew).
        try XCTSkipUnless(Shell.which("brew") != nil, "brew is not installed")
        let result = try Shell.run(command: "brew", ["--version"])
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.stdout.contains("Homebrew"))
    }
}
