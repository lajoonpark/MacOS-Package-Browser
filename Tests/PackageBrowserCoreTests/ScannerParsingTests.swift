import XCTest
@testable import PackageBrowserCore

final class ScannerParsingTests: XCTestCase {
    // MARK: - npm

    func testNpmParsing() throws {
        let json = """
        {
          "name": "lib",
          "dependencies": {
            "@earendil-works/pi-coding-agent": { "version": "0.85.1", "overridden": false },
            "cline": { "version": "3.0.52", "overridden": false },
            "corepack": { "version": "0.35.0", "overridden": false }
          }
        }
        """
        let packages = try NpmScanner.parsePackages(json)
        XCTAssertEqual(packages.count, 3)
        XCTAssertEqual(Set(packages.map(\.source)), [.npm])
        let scoped = packages.first { $0.name == "@earendil-works/pi-coding-agent" }
        XCTAssertEqual(scoped?.version, "0.85.1")
        XCTAssertEqual(scoped?.kind, "Global package")
        // Dictionary output must be sorted for a stable list.
        XCTAssertEqual(packages.map(\.name), packages.map(\.name).sorted())
    }

    // MARK: - pip

    func testPipParsing() throws {
        let json = """
        [{"name": "altgraph", "version": "0.17.2"}, {"name": "pip", "version": "21.2.4"}, {"name": "six", "version": "1.15.0"}]
        """
        let packages = try PipScanner.parsePackages(json)
        XCTAssertEqual(packages.count, 3)
        XCTAssertEqual(packages.first { $0.name == "pip" }?.version, "21.2.4")
        XCTAssertEqual(packages.first { $0.name == "six" }?.kind, "Python package")
    }

    // MARK: - bun

    func testBunParsingArrayShape() throws {
        let json = """
        [{"name": "typescript", "version": "5.6.2"}, {"name": "bun-types", "version": "1.1.30"}]
        """
        let packages = try BunScanner.parsePackages(json)
        XCTAssertEqual(packages.map(\.name), ["typescript", "bun-types"])
        XCTAssertEqual(packages.first?.version, "5.6.2")
    }

    func testBunParsingProjectShape() throws {
        let json = """
        {"dependencies": {"typescript": {"version": "5.6.2"}}}
        """
        let packages = try BunScanner.parsePackages(json)
        XCTAssertEqual(packages.map(\.name), ["typescript"])
    }

    // MARK: - gem

    func testGemParsing() {
        let text = """
        bundler (default: 4.0.16, 2.5.23)
        rake (13.2.1)
        *** REMOTE GEMS ***

        """
        let packages = GemScanner.parsePackages(text)
        XCTAssertEqual(packages.count, 2)
        let bundler = packages.first { $0.name == "bundler" }
        XCTAssertEqual(bundler?.version, "4.0.16, 2.5.23")
        XCTAssertEqual(bundler?.kind, "Default gem")
        let rake = packages.first { $0.name == "rake" }
        XCTAssertEqual(rake?.version, "13.2.1")
        XCTAssertEqual(rake?.kind, "Gem")
    }

    // MARK: - cargo

    func testCargoParsing() {
        let text = """
        ripgrep v14.1.0:
            rg
        cargo-audit v0.20.0:
            cargo-audit
        cargo-watch v8.5.2:
            cargo-watch
        """
        let packages = CargoScanner.parsePackages(text)
        XCTAssertEqual(packages.count, 3)
        XCTAssertEqual(packages.first?.name, "ripgrep")
        XCTAssertEqual(packages.first?.version, "14.1.0")
        XCTAssertEqual(packages.first?.kind, "Rust crate")
    }

    // MARK: - nix

    func testNixKeyedJSONParsing() throws {
        let json = """
        {
          "elements": {
            "0": {
              "originalUri": "flake:nixpkgs",
              "attrPath": "legacyPackages.aarch64-darwin.devenv",
              "storePaths": ["/nix/store/abcdefghijklmnopqrstuvwxyz123456-devenv-1.0.6"],
              "active": true
            }
          }
        }
        """
        let packages = try NixScanner.parseJSON(json)
        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages.first?.name, "devenv")
        XCTAssertEqual(packages.first?.version, "1.0.6")
    }

    func testNixTextParsing() {
        let text = """
        9 flake:nixpkgs#legacyPackages.x86_64-darwin.devenv github:NixOS/nixpkgs/880d123 /nix/store/abcdefghijklmnopqrstuvwxyz123456-devenv-1.0.6
        10 flake:nixpkgs#legacyPackages.x86_64-darwin.nodejs /nix/store/abcdefghijklmnopqrstuvwxyz123457-nodejs-20.5.1
        """
        let packages = NixScanner.parseText(text)
        XCTAssertEqual(packages.count, 2)
        XCTAssertEqual(packages.first?.name, "devenv")
        XCTAssertEqual(packages.first?.version, "1.0.6")
        XCTAssertEqual(packages.last?.name, "nodejs")
        XCTAssertEqual(packages.last?.version, "20.5.1")
    }

    func testNixStorePathWithoutVersion() {
        let package = NixScanner.package(fromStorePath: "/nix/store/abcdefghijklmnopqrstuvwxyz123456-hello")
        XCTAssertEqual(package?.name, "hello")
        XCTAssertEqual(package?.version, "unknown")
    }

    // MARK: - pkgx

    func testPkgxDirectoryParsing() throws {
        let dir = NSTemporaryDirectory() + "pkgx-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let fm = FileManager.default
        for sub in ["gnu.org/wget#1.24.5", "gnu.org/coreutils#9.5", "github.com/BurntSushi/ripgrep#14.1.1", "bin/rg", ".hidden/junk#1.0"] {
            try fm.createDirectory(atPath: dir + "/" + sub, withIntermediateDirectories: true)
        }

        let packages = try PkgxScanner.parsePackages(directory: dir)
        XCTAssertEqual(packages.count, 3)
        XCTAssertEqual(packages.first?.name, "github.com/BurntSushi/ripgrep")
        XCTAssertEqual(packages.first?.version, "14.1.1")
        let wget = packages.first { $0.name == "gnu.org/wget" }
        XCTAssertEqual(wget?.version, "1.24.5")
        XCTAssertEqual(wget?.source, .pkgx)
    }
}
