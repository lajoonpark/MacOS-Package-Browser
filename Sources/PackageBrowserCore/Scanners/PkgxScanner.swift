import Foundation

/// Lists pkgx-installed packages by scanning `~/.pkgx`.
///
/// pkgx is ephemeral by design — there is no stable `list` command — but every
/// package it fetches is cached as `<domain>/<name>#<version>` under ~/.pkgx.
public struct PkgxScanner: PackageScanner {
    public let id: PackageSourceID = .pkgx
    public let displayName = "pkgx"
    public let symbolName = "square.stack.3d.up"

    static var cacheDirectory: String { NSHomeDirectory() + "/.pkgx" }

    public func isAvailable() -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: Self.cacheDirectory, isDirectory: &isDir) && isDir.boolValue
    }

    public func scan() throws -> [InstalledPackage] {
        try Self.parsePackages(directory: Self.cacheDirectory)
    }

    static func parsePackages(directory: String) throws -> [InstalledPackage] {
        var packages: [InstalledPackage] = []
        Self.walk(directory: directory, prefix: "", into: &packages)
        return packages.sorted { $0.name < $1.name }
    }

    /// Walks the cache tree. Any directory named `name#version` is a package;
    /// the directories above it (e.g. github.com/BurntSushi) form its full name.
    private static func walk(directory: String, prefix: String, into packages: inout [InstalledPackage]) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return }

        for entry in entries.sorted() where !entry.hasPrefix(".") {
            let path = (directory as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }

            if let hashIndex = entry.firstIndex(of: "#") {
                let name = String(entry[entry.startIndex..<hashIndex])
                let version = String(entry[entry.index(after: hashIndex)...])
                guard !name.isEmpty, !version.isEmpty else { continue }
                packages.append(InstalledPackage(source: .pkgx, name: prefix + name, version: version))
            } else {
                walk(directory: path, prefix: prefix + entry + "/", into: &packages)
            }
        }
    }
}
