// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgentWatchTower",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentWatchTower",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Swifter", package: "swifter"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AgentWatchTowerTests",
            dependencies: ["AgentWatchTower"],
            path: "Tests"
        ),
    ]
)
