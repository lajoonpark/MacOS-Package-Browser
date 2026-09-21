import Foundation

/// Lists Python packages via `pip3 list --format=json`.
public struct PipScanner: PackageScanner {
    public let id: PackageSourceID = .pip
    public let displayName = "pip (Python)"
    public let symbolName = "arrow.down.circle"

    public func isAvailable() -> Bool {
        Shell.which("pip3") != nil || Shell.which("pip") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        guard let path = Shell.which("pip3") ?? Shell.which("pip") else {
            throw ShellError.notFound("pip3")
        }
        let result = try Shell.run(path: path, ["list", "--format=json"])
        guard result.succeeded else {
            throw ShellError.failed(command: "pip list", exitCode: result.exitCode, stderr: result.stderr)
        }
        return try Self.parsePackages(result.stdout)
    }

    static func parsePackages(_ json: String) throws -> [InstalledPackage] {
        let entries = try JSONDecoder().decode([PipEntry].self, from: Data(json.utf8))
        return entries.map { entry in
            InstalledPackage(source: .pip, name: entry.name, version: entry.version, kind: "Python package")
        }
    }
}

private struct PipEntry: Decodable {
    let name: String
    let version: String
}
