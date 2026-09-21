import Foundation

/// One installed package, normalized across all package managers.
public struct InstalledPackage: Identifiable, Hashable {
    /// Stable identity prefixed by source, e.g. "homebrew:wget".
    public let id: String
    public let name: String
    public let version: String
    public let source: PackageSourceID
    /// Sub-type within the source, e.g. "Formula" or "Cask" for Homebrew.
    public let kind: String?
    public let description: String
    public let homepage: URL?
    /// True when the package was pulled in only because something else depends on it.
    public let installedAsDependency: Bool?
    public let outdated: Bool?

    public init(
        source: PackageSourceID,
        name: String,
        version: String,
        kind: String? = nil,
        description: String = "",
        homepage: String? = nil,
        installedAsDependency: Bool? = nil,
        outdated: Bool? = nil
    ) {
        self.source = source
        self.name = name
        self.version = version
        self.kind = kind
        self.description = description
        self.homepage = homepage.flatMap(URL.init(string:))
        self.installedAsDependency = installedAsDependency
        self.outdated = outdated
        self.id = "\(source.rawValue):\(name)"
    }
}

/// The package managers the app knows about.
public enum PackageSourceID: String, CaseIterable, Identifiable {
    case homebrew
    case bun
    case npm
    case nix
    case pkgx
    case pip
    case cargo
    case gem

    public var id: String { rawValue }
}
