// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NaconController",
    defaultLocalization: "en",  // Inglés es el idioma base; el español es una traducción.
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NaconDiagnostics", targets: ["NaconDiagnostics"]),
        .library(name: "NaconCore", targets: ["NaconCore"]),
        .executable(name: "nacon-selftest", targets: ["NaconSelfTest"]),
        .executable(name: "nacon-padtest", targets: ["NaconPadTest"]),
        .executable(name: "nacon-touchpad", targets: ["NaconTouchWatch"]),
        .executable(name: "nacon-ps4probe", targets: ["NaconPS4Probe"]),
        .executable(name: "nacon-motion", targets: ["NaconMotion"]),
    ],
    targets: [
        // `defaultLocalization` is what makes a localized resource bundle exist at all: without it
        // SwiftPM refuses to process a string catalog, and every lookup silently falls back to the key.
        .target(
            name: "NaconCore",
            path: "Sources/NaconCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "NaconDiagnostics",
            dependencies: ["NaconCore"],
            path: "Sources/NaconDiagnostics",
            // The DualShock 4 drawing the graphical pad view is built on. SwiftPM turns it into a
            // resource bundle next to the executable; `scripts/build-app.sh` copies it into the
            // .app so `Bundle.module` finds it there too.
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "NaconMotion",
            dependencies: ["NaconCore"],
            path: "Sources/NaconMotion"
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
        .executableTarget(
            name: "NaconPS4Probe",
            dependencies: ["NaconCore"],
            path: "Sources/NaconPS4Probe"
        ),
        .testTarget(
            name: "NaconCoreTests",
            dependencies: ["NaconCore"],
            path: "Tests/NaconCoreTests"
        ),
    ]
)
