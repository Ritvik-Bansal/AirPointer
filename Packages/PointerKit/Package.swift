// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PointerKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PointerKit", targets: ["PointerKit"]),
        .executable(name: "pointer-replay", targets: ["PointerReplay"]),
    ],
    targets: [
        .target(name: "PointerKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "PointerReplay", dependencies: ["PointerKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "PointerKitTests",
            dependencies: ["PointerKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
