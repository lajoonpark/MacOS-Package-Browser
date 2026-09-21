import Foundation

/// A strategy that lists installed packages for one package manager.
public protocol PackageScanner {
    var id: PackageSourceID { get }
    var displayName: String { get }
    /// SF Symbol name used for the sidebar icon.
    var symbolName: String { get }

    /// Whether this manager is present on the machine.
    func isAvailable() -> Bool
    /// Lists installed packages. Throws with a user-presentable message on failure.
    func scan() throws -> [InstalledPackage]
}

/// All scanners the app knows about, in sidebar order.
public enum ScannerRegistry {
    public static let all: [any PackageScanner] = [
        HomebrewScanner(),
        BunScanner(),
        NpmScanner(),
        NixScanner(),
        PkgxScanner(),
        PipScanner(),
        CargoScanner(),
        GemScanner(),
    ]
}
