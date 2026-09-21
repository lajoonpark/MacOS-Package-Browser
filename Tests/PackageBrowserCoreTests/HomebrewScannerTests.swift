import XCTest
@testable import PackageBrowserCore

final class HomebrewScannerTests: XCTestCase {
    static let fixture = """
    {
      "formulae": [
        {
          "name": "wget",
          "full_name": "wget",
          "desc": "Internet file retriever",
          "homepage": "https://www.gnu.org/software/wget/",
          "versions": { "stable": "1.24.5" },
          "installed": [
            { "version": "1.24.5", "installed_as_dependency": false, "installed_on_request": true }
          ],
          "outdated": false,
          "pinned": false
        },
        {
          "name": "bdw-gc",
          "full_name": "bdw-gc",
          "desc": "Garbage collector for C and C++",
          "homepage": "https://www.hboehm.info/gc/",
          "versions": { "stable": "8.2.12" },
          "installed": [
            { "version": "8.2.12", "installed_as_dependency": true, "installed_on_request": false }
          ],
          "outdated": true,
          "pinned": false
        }
      ],
      "casks": [
        {
          "token": "visual-studio-code",
          "name": ["Visual Studio Code"],
          "desc": "Open-source code editor",
          "homepage": "https://code.visualstudio.com/",
          "version": "1.90.0",
          "installed": "1.89.0",
          "outdated": true
        }
      ]
    }
    """

    func testParsePackages() throws {
        let packages = try HomebrewScanner.parsePackages(Self.fixture)

        XCTAssertEqual(packages.count, 3)
        XCTAssertEqual(Set(packages.map(\.source)), [.homebrew])

        let wget = packages.first { $0.name == "wget" }
        XCTAssertEqual(wget?.id, "homebrew:wget")
        XCTAssertEqual(wget?.version, "1.24.5")
        XCTAssertEqual(wget?.kind, "Formula")
        XCTAssertEqual(wget?.installedAsDependency, false)
        XCTAssertEqual(wget?.outdated, false)
        XCTAssertEqual(wget?.homepage?.absoluteString, "https://www.gnu.org/software/wget/")

        // A formula installed only because something else depends on it.
        let dependency = packages.first { $0.name == "bdw-gc" }
        XCTAssertEqual(dependency?.installedAsDependency, true)
        XCTAssertEqual(dependency?.outdated, true)

        // Casks report the installed version, not the latest known one.
        let cask = packages.first { $0.name == "visual-studio-code" }
        XCTAssertEqual(cask?.version, "1.89.0")
        XCTAssertEqual(cask?.kind, "Cask")
        XCTAssertEqual(cask?.outdated, true)
    }

    func testLiveScan() throws {
        try XCTSkipUnless(Shell.which("brew") != nil, "brew is not installed")
        let packages = try HomebrewScanner().scan()
        XCTAssertFalse(packages.isEmpty)
        XCTAssertTrue(packages.allSatisfy { $0.source == .homebrew })
        XCTAssertTrue(packages.allSatisfy { !$0.version.isEmpty })
    }
}
