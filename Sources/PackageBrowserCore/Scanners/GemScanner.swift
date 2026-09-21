import Foundation

/// Lists Ruby gems via `gem list --local`.
public struct GemScanner: PackageScanner {
    public let id: PackageSourceID = .gem
    public let displayName = "RubyGems"
    public let symbolName = "diamond"

    public func isAvailable() -> Bool {
        Shell.which("gem") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let result = try Shell.run(command: "gem", ["list"])
        guard result.succeeded else {
            throw ShellError.failed(command: "gem list", exitCode: result.exitCode, stderr: result.stderr)
        }
        return Self.parsePackages(result.stdout)
    }

    /// Parses lines like `rake (13.2.1)` and `bundler (default: 4.0.16, 2.5.23)`.
    static func parsePackages(_ text: String) -> [InstalledPackage] {
        var packages: [InstalledPackage] = []
        for line in text.split(separator: "\n") {
            guard let open = line.firstIndex(of: "("), let close = line.lastIndex(of: ")"), open < close else {
                continue
            }
            let name = line[line.startIndex..<open].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            var inner = String(line[line.index(after: open)..<close])
            let isDefault = inner.hasPrefix("default:")
            if isDefault {
                inner = String(inner.dropFirst("default:".count)).trimmingCharacters(in: .whitespaces)
            }
            let versions = inner
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            packages.append(InstalledPackage(
                source: .gem,
                name: name,
                version: versions.isEmpty ? "unknown" : versions,
                kind: isDefault ? "Default gem" : "Gem"
            ))
        }
        return packages
    }
}
