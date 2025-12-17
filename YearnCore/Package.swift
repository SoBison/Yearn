// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YearnCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "YearnCore",
            targets: ["YearnCore"]
        ),
    ],
    dependencies: [],
    targets: [
        // C target for libretro header (system library style)
        .target(
            name: "CLibretro",
            dependencies: [],
            path: "Sources/CLibretro",
            sources: ["CLibretro.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                // Enable static cores - required for iOS App Store
                .define("STATIC_CORES_ENABLED")
            ]
        ),
        // Main Swift target
        .target(
            name: "YearnCore",
            dependencies: ["CLibretro"],
            path: "Sources/YearnCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                // Enable static cores - required for iOS App Store
                .define("STATIC_CORES_ENABLED")
            ]
        ),
    ]
)

