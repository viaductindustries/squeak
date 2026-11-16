// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Squeek",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SqueekCore"),
        .executableTarget(name: "Squeek", dependencies: ["SqueekCore"]),
        .testTarget(name: "SqueekCoreTests", dependencies: ["SqueekCore"]),
    ]
)
