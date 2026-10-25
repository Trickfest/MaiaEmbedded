// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MaiaEmbedded",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "MaiaEmbedded", targets: ["MaiaEmbedded"]),
        .library(name: "MaiaUCI", targets: ["MaiaUCI"]),
    ],
    targets: [
        .target(name: "MaiaEmbedded"),
        .target(name: "MaiaUCI", dependencies: ["MaiaEmbedded"]),
    ]
)
