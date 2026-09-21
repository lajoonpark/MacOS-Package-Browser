import Foundation

/// Lists cargo-installed Rust binaries via `cargo install --list`.
public struct CargoScanner: PackageScanner {
    public let id: PackageSourceID = .cargo
    public let displayName = "Cargo (Rust)"
    public let symbolName = "shippingbox"

    public func isAvailable() -> Bool {
        Shell.which("cargo") != nil
    }

    public func scan() throws -> [InstalledPackage] {
        let result = try Shell.run(command: "cargo", ["install", "--list"])
        guard result.succeeded else {
            throw ShellError.failed(command: "cargo install --list", exitCode: result.exitCode, stderr: result.stderr)
        }
        return Self.parsePackages(result.stdout)
    }

    /// Parses header lines like `ripgrep v14.1.0:`; indented lines under each
    /// header name the installed binaries and are skipped.
    static func parsePackages(_ text: String) -> [InstalledPackage] {
        text.split(separator: "\n").compactMap { line in
            guard !line.hasPrefix("    "), line.hasSuffix(":") else { return nil }
            let parts = line.dropLast().split(separator: " ")
            guard parts.count >= 2, parts[1].hasPrefix("v") else { return nil }
            return InstalledPackage(
                source: .cargo,
                name: String(parts[0]),
                version: String(parts[1].dropFirst()),
                kind: "Rust crate"
            )
        }
    }
}
