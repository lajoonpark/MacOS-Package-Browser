import Foundation

/// Lists installed formulae and casks via `brew info --json=v2 --installed`.
///
/// Homebrew 7 removed `--json=v2` from `brew list`; `brew info` still emits the
/// rich v2 payload (descriptions, homepages, dependency flags, outdated state)
/// for everything installed.
public struct HomebrewScanner: PackageScanner {
    public let id: PackageSourceID = .homebrew
    public let displayName = "Homebrew"
    public let symbolName = "beaker"

    public func isAvailable() -> Bool {
        Shell.which("brew") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let result = try Shell.run(command: "brew", ["info", "--json=v2", "--installed"])
        guard result.succeeded, !result.stdout.isEmpty else {
            throw ShellError.failed(command: "brew info", exitCode: result.exitCode, stderr: result.stderr)
        }
        return try Self.parsePackages(result.stdout)
    }

    /// Parses `brew info --json=v2` output into normalized packages.
    static func parsePackages(_ json: String) throws -> [InstalledPackage] {
        let payload = try JSONDecoder().decode(BrewPayload.self, from: Data(json.utf8))

        var packages: [InstalledPackage] = []
        packages.reserveCapacity(payload.formulae.count + payload.casks.count)

        for formula in payload.formulae {
            let entry = formula.installed.last
            packages.append(InstalledPackage(
                source: .homebrew,
                name: formula.fullName ?? formula.name,
                version: entry?.version ?? formula.versions?.stable ?? "unknown",
                kind: "Formula",
                description: formula.desc ?? "",
                homepage: formula.homepage,
                installedAsDependency: entry.map { ($0.installedAsDependency ?? false) && !($0.installedOnRequest ?? false) },
                outdated: formula.outdated
            ))
        }

        for cask in payload.casks {
            packages.append(InstalledPackage(
                source: .homebrew,
                name: cask.token,
                version: cask.installed ?? cask.version ?? "unknown",
                kind: "Cask",
                description: cask.desc ?? cask.name?.first ?? "",
                homepage: cask.homepage,
                outdated: cask.outdated
            ))
        }

        return packages
    }
}

private struct BrewPayload: Decodable {
    let formulae: [BrewFormula]
    let casks: [BrewCask]
}

private struct BrewFormula: Decodable {
    let name: String
    let fullName: String?
    let desc: String?
    let homepage: String?
    let installed: [InstalledEntry]
    let versions: Versions?
    let outdated: Bool?

    struct InstalledEntry: Decodable {
        let version: String?
        let installedAsDependency: Bool?
        let installedOnRequest: Bool?

        enum CodingKeys: String, CodingKey {
            case version
            case installedAsDependency = "installed_as_dependency"
            case installedOnRequest = "installed_on_request"
        }
    }

    struct Versions: Decodable {
        let stable: String?
    }
}

private struct BrewCask: Decodable {
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: String?
    let outdated: Bool?
}
