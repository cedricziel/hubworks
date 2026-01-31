// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HubWorks",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "HubWorksCore",
            targets: ["HubWorksCore"]
        ),
        .library(
            name: "HubWorksFeatures",
            targets: ["HubWorksFeatures"]
        ),
        .library(
            name: "HubWorksUI",
            targets: ["HubWorksUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "HubWorksCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/HubWorksCore"
        ),
        .testTarget(
            name: "HubWorksCoreTests",
            dependencies: ["HubWorksCore"],
            path: "Tests/HubWorksCoreTests"
        ),

        // MARK: - Features
        .target(
            name: "HubWorksFeatures",
            dependencies: [
                "HubWorksCore",
                "HubWorksUI",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/HubWorksFeatures"
        ),
        .testTarget(
            name: "HubWorksFeaturesTests",
            dependencies: ["HubWorksFeatures"],
            path: "Tests/HubWorksFeaturesTests"
        ),

        // MARK: - UI
        .target(
            name: "HubWorksUI",
            dependencies: [
                "HubWorksCore",
            ],
            path: "Sources/HubWorksUI"
        ),
    ]
)
