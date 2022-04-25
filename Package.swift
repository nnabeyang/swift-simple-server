// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-simple-server",
    products: [
        .library(
            name: "SimpleServer",
            targets: ["SimpleServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.39.0"),
        .package(url: "https://github.com/nnabeyang/swift-mime-type", from: "0.0.2"),
    ],
    targets: [
        .target(
            name: "SimpleServer",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "MimeType", package: "swift-mime-type"),
            ]),
        .testTarget(
            name: "SimpleServerTests",
            dependencies: ["SimpleServer"]),
    ]
)
