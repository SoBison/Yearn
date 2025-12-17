// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YearnAdapters",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "YearnAdapters",
            targets: ["YearnAdapters"]
        ),
    ],
    dependencies: [
        .package(path: "../YearnCore")
    ],
    targets: [
        .target(
            name: "YearnAdapters",
            dependencies: ["YearnCore"],
            path: "Sources/YearnAdapters"
        ),
    ]
)

