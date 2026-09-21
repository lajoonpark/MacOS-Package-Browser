import Foundation

/// Lists Nix profile packages via `nix profile list`.
///
/// Nix's output has changed across versions, so this tries the JSON form
/// first (elements keyed by priority or a plain array — both have existed)
/// and falls back to parsing the human-readable listing.
public struct NixScanner: PackageScanner {
    public let id: PackageSourceID = .nix
    public let displayName = "Nix"
    public let symbolName = "snowflake"

    public func isAvailable() -> Bool {
        Shell.which("nix") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let json = try Shell.run(command: "nix", ["profile", "list", "--json"])
        if json.succeeded, !json.stdout.isEmpty, let packages = try? Self.parseJSON(json.stdout), !packages.isEmpty {
            return packages
        }

        let text = try Shell.run(command: "nix", ["profile", "list"])
        guard text.succeeded, !text.stdout.isEmpty else {
            let stderr = text.stderr.isEmpty ? json.stderr : text.stderr
            let exitCode = text.stdout.isEmpty ? json.exitCode : text.exitCode
            throw ShellError.failed(command: "nix profile list", exitCode: exitCode, stderr: stderr)
        }
        return Self.parseText(text.stdout)
    }

    static func parseJSON(_ json: String) throws -> [InstalledPackage] {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        // Modern shape: {"elements": {"0": {...}, "1": {...}}}
        if let keyed = try? decoder.decode(NixKeyedPayload.self, from: data) {
            return keyed.elements.values.compactMap(Self.package(from:))
        }
        // Older nix-env manifest shape: {"elements": [{...}, {...}]}
        if let array = try? decoder.decode(NixArrayPayload.self, from: data) {
            return array.elements.compactMap(Self.package(from:))
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [],
            debugDescription: "Unrecognized nix profile JSON"
        ))
    }

    /// Parses the human-readable listing by extracting the /nix/store path,
    /// whose basename is `<hash>-<name>-<version>` (or `<hash>-<name>`).
    static func parseText(_ text: String) -> [InstalledPackage] {
        text.split(separator: "\n").compactMap { line in
            guard let range = line.range(of: "/nix/store/") else { return nil }
            return package(fromStorePath: String(line[range.lowerBound...]).split(separator: " ").first.map(String.init) ?? "")
        }
    }

    private static func package(from element: NixElement) -> InstalledPackage? {
        var name = element.attrPath.map { $0.split(separator: ".").last.map(String.init) ?? $0 }
        if name == nil || name?.isEmpty == true {
            name = element.originalUri.map { $0.split(separator: "#").last.map(String.init) ?? $0 }
        }

        if let storePath = element.storePaths?.last, let fromStore = package(fromStorePath: storePath) {
            return InstalledPackage(
                source: .nix,
                name: (name?.isEmpty == false ? name! : fromStore.name),
                version: fromStore.version,
                kind: "Profile package"
            )
        }
        guard let name, !name.isEmpty else { return nil }
        return InstalledPackage(source: .nix, name: name, version: "unknown", kind: "Profile package")
    }

    /// `/nix/store/<hash>-<name>-<version>` → name + version.
    static func package(fromStorePath path: String) -> InstalledPackage? {
        let basename = URL(fileURLWithPath: path).lastPathComponent
        let parts = basename.split(separator: "-")
        guard parts.count >= 2, parts[0].count == 32 else { return nil }
        if parts.count == 2 {
            return InstalledPackage(source: .nix, name: String(parts[1]), version: "unknown", kind: "Profile package")
        }
        let name = parts.dropFirst().dropLast().joined(separator: "-")
        return InstalledPackage(source: .nix, name: name, version: String(parts.last!), kind: "Profile package")
    }
}

private struct NixKeyedPayload: Decodable {
    let elements: [String: NixElement]
}

private struct NixArrayPayload: Decodable {
    let elements: [NixElement]
}

private struct NixElement: Decodable {
    let attrPath: String?
    let originalUri: String?
    let storePaths: [String]?
}
