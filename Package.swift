// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PackageBrowser",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PackageBrowserCore",
            path: "Sources/PackageBrowserCore"
        ),
        .executableTarget(
            name: "PackageBrowser",
            dependencies: ["PackageBrowserCore"],
            path: "Sources/PackageBrowser"
        ),
        .testTarget(
            name: "PackageBrowserCoreTests",
            dependencies: ["PackageBrowserCore"],
            path: "Tests/PackageBrowserCoreTests"
        )
    ]
)
