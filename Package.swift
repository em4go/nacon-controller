// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NaconController",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NaconDiagnostics", targets: ["NaconDiagnostics"]),
        .library(name: "NaconCore", targets: ["NaconCore"]),
        .executable(name: "nacon-selftest", targets: ["NaconSelfTest"]),
        .executable(name: "nacon-padtest", targets: ["NaconPadTest"]),
        .executable(name: "nacon-touchpad", targets: ["NaconTouchWatch"]),
    ],
    targets: [
        .target(name: "NaconCore", path: "Sources/NaconCore"),
        .executableTarget(
            name: "NaconDiagnostics",
            dependencies: ["NaconCore"],
            path: "Sources/NaconDiagnostics"
        ),
        .executableTarget(
            name: "NaconSelfTest",
            dependencies: ["NaconCore"],
            path: "Sources/NaconSelfTest"
        ),
        .executableTarget(
            name: "NaconPadTest",
            dependencies: ["NaconCore"],
            path: "Sources/NaconPadTest"
        ),
        .executableTarget(
            name: "NaconTouchWatch",
            dependencies: ["NaconCore"],
            path: "Sources/NaconTouchWatch"
        ),
        .testTarget(
            name: "NaconCoreTests",
            dependencies: ["NaconCore"],
            path: "Tests/NaconCoreTests"
        ),
    ]
)
