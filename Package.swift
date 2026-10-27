// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NaconController",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "NaconCore", targets: ["NaconCore"]),
    ],
    targets: [
        .target(name: "NaconCore", path: "Sources/NaconCore"),
        .testTarget(
            name: "NaconCoreTests",
            dependencies: ["NaconCore"],
            path: "Tests/NaconCoreTests"
        ),
    ]
)
