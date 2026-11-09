// swift-tools-version: 6.0
import PackageDescription

// Renders the AirPointer film, frame by frame, from the app's own 3D case and from
// recordings replayed through the real engine.
let package = Package(
    name: "Film",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../Packages/PointerKit")],
    targets: [
        .executableTarget(
            name: "film",
            dependencies: [.product(name: "PointerKit", package: "PointerKit")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
