import Foundation

/// Lists bun's global packages via `bun pm ls -g --json`.
public struct BunScanner: PackageScanner {
    public let id: PackageSourceID = .bun
    public let displayName = "Bun"
    public let symbolName = "hare"

    public func isAvailable() -> Bool {
        Shell.which("bun") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let result = try Shell.run(command: "bun", ["pm", "ls", "-g", "--json"])
        guard result.succeeded else {
            // Bun exits non-zero when no global package.json exists yet —
            // that means "nothing installed", not a broken source.
            if result.stderr.contains("No package.json") { return [] }
            throw ShellError.failed(command: "bun pm ls", exitCode: result.exitCode, stderr: result.stderr)
        }
        return try Self.parsePackages(result.stdout)
    }

    /// Accepts both output shapes bun has used: a flat array of entries, or a
    /// project-style `{"dependencies": {...}}` object.
    static func parsePackages(_ json: String) throws -> [InstalledPackage] {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        if let array = try? decoder.decode([BunEntry].self, from: data) {
            return array.compactMap { entry in
                guard let name = entry.name else { return nil }
                return InstalledPackage(source: .bun, name: name, version: entry.version ?? "unknown", kind: "Global package")
            }
        }

        if let project = try? decoder.decode(BunProject.self, from: data) {
            return project.dependencies
                .map { name, entry in
                    InstalledPackage(source: .bun, name: name, version: entry.version ?? "unknown", kind: "Global package")
                }
                .sorted { $0.name < $1.name }
        }

        return []
    }
}

private struct BunEntry: Decodable {
    let name: String?
    let version: String?
}

private struct BunProject: Decodable {
    let dependencies: [String: BunEntry]
}
