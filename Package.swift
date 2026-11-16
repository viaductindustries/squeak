// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Squeak",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SqueakCore"),
        .executableTarget(name: "Squeak", dependencies: ["SqueakCore"]),
        .testTarget(name: "SqueakCoreTests", dependencies: ["SqueakCore"]),
    ]
)
