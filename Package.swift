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
        .executable(name: "maia-uci", targets: ["MaiaCLI"]),
        .executable(name: "maia-smoke", targets: ["MaiaSmoke"]),
        .executable(name: "maia-soak", targets: ["MaiaSoak"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Trickfest/SwiftChessTools.git", from: "1.4.0"),
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", exact: "1.24.2"),
    ],
    targets: [
        .target(name: "MaiaEmbedded", dependencies: [
            .product(name: "ChessCore", package: "SwiftChessTools"),
            .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
        ]),
        .target(name: "MaiaUCI", dependencies: ["MaiaEmbedded"]),
        .target(name: "MaiaBenchmarkSupport", dependencies: ["MaiaEmbedded", "MaiaUCI", .product(name: "ChessCore", package: "SwiftChessTools")], resources: [.copy("Resources/reference.json")]),
        .executableTarget(name: "MaiaBenchmarkCLI", dependencies: ["MaiaBenchmarkSupport"]),
        .executableTarget(name: "MaiaCLI", dependencies: ["MaiaUCI"]),
        .executableTarget(name: "MaiaSmoke", dependencies: ["MaiaUCI", "MaiaBenchmarkSupport"]),
        .executableTarget(name: "MaiaSoak", dependencies: ["MaiaUCI", "MaiaBenchmarkSupport"]),
        .testTarget(name: "MaiaUCITests", dependencies: ["MaiaUCI", "MaiaEmbedded"]),
        .testTarget(name: "MaiaEmbeddedTests", dependencies: ["MaiaEmbedded", "MaiaBenchmarkSupport"]),
    ]
)
