// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PointerKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PointerKit", targets: ["PointerKit"]),
    ],
    targets: [
        .target(name: "PointerKit", swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
