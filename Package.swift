// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pauri",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Pauri"),
        .testTarget(name: "PauriTests", dependencies: ["Pauri"]),
    ]
)
