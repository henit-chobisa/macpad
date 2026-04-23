// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "macpad",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "macpad", path: "Sources/macpad")
    ]
)
