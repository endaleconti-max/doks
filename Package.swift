// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocumentOrganizer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Ingestion", targets: ["Ingestion"]),
        .library(name: "Categorization", targets: ["Categorization"]),
        .library(name: "Privacy", targets: ["Privacy"]),
        .library(name: "PluginKit", targets: ["PluginKit"]),
        .library(name: "AppleAppCore", targets: ["AppleAppCore"]),
        .library(name: "Services", targets: ["Services"]),
        .executable(name: "DocumentOrganizer", targets: ["DocumentOrganizer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0")
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Ingestion"),
        .target(
            name: "Categorization",
            dependencies: ["Core"]
        ),
        .target(name: "Privacy"),
        .target(
            name: "PluginKit",
            dependencies: ["Core"]
        ),
        .target(
            name: "AppleAppCore",
            dependencies: ["Services", "Core", "Privacy", "PluginKit"]
        ),
        .target(
            name: "Services",
            dependencies: ["Core", "Ingestion", "Categorization", "Privacy", "PluginKit"]
        ),
        .executableTarget(
            name: "DocumentOrganizer",
            dependencies: ["Services", "Core", "Privacy", "PluginKit"]
        ),
        .testTarget(
            name: "ServicesTests",
            dependencies: [
                "Services",
                "Core",
                "Ingestion",
                "PluginKit",
                "Privacy",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "AppleAppCoreTests",
            dependencies: [
                "AppleAppCore",
                "Core",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ]
)
