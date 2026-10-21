// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "WiFiStabilizer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "WiFiStabilizer", targets: ["WiFiStabilizer"])
    ],
    targets: [
        .target(name: "StabilizerCore"),
        .executableTarget(name: "WiFiStabilizer", dependencies: ["StabilizerCore"]),
        .testTarget(name: "StabilizerCoreTests", dependencies: ["StabilizerCore"])
    ]
)
