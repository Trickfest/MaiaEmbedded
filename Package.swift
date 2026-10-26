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
        .library(name: "MaiaBenchmarkSupport", targets: ["MaiaBenchmarkSupport"]),
        .executable(name: "maia-benchmark", targets: ["MaiaBenchmarkCLI"]),
    ],
    dependencies: [
        .package(path: "../SwiftChessTools"),
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", exact: "1.24.2"),
    ],
    targets: [
        .target(name: "MaiaEmbedded", dependencies: [
            .product(name: "ChessCore", package: "SwiftChessTools"),
            .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
        ]),
        .target(name: "MaiaUCI", dependencies: ["MaiaEmbedded"]),
        .target(name: "MaiaBenchmarkSupport", dependencies: ["MaiaEmbedded"], resources: [.copy("Resources/reference.json")]),
        .executableTarget(name: "MaiaBenchmarkCLI", dependencies: ["MaiaBenchmarkSupport"]),
        .testTarget(name: "MaiaEmbeddedTests", dependencies: ["MaiaEmbedded", "MaiaBenchmarkSupport"]),
    ]
)
