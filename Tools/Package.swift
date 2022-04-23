// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Tools",
    platforms: [.macOS(.v10_11)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format", .exact("0.50600.0"))
    ],
    targets: [.target(name: "Tools", path: "")]
)
