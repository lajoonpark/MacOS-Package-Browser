import Foundation

/// Lists npm global packages via `npm ls -g --json`.
public struct NpmScanner: PackageScanner {
    public let id: PackageSourceID = .npm
    public let displayName = "npm"
    public let symbolName = "chevron.left.forwardslash.chevron.right"

    public func isAvailable() -> Bool {
        Shell.which("npm") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let result = try Shell.run(command: "npm", ["ls", "-g", "--json"])
        guard result.succeeded else {
            throw ShellError.failed(command: "npm ls", exitCode: result.exitCode, stderr: result.stderr)
        }
        return try Self.parsePackages(result.stdout)
    }

    static func parsePackages(_ json: String) throws -> [InstalledPackage] {
        let payload = try JSONDecoder().decode(NpmPayload.self, from: Data(json.utf8))
        return (payload.dependencies ?? [:])
            .map { name, entry in
                InstalledPackage(source: .npm, name: name, version: entry.version ?? "unknown", kind: "Global package")
            }
            .sorted { $0.name < $1.name }
    }
}

private struct NpmPayload: Decodable {
    let dependencies: [String: NpmEntry]?
}

private struct NpmEntry: Decodable {
    let version: String?
}
