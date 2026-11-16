// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pauri",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")],
    targets: [
        .executableTarget(name: "Pauri", dependencies: [.product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "PauriTests", dependencies: ["Pauri"]),
    ]
)
