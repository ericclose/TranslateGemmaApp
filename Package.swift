// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TranslateGemmaApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TranslateGemmaKit", targets: ["TranslateGemmaKit"]),
        .executable(name: "TranslateGemmaApp", targets: ["TranslateGemmaApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.3"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "3.31.3"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.2"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.9.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.1"),
    ],
    targets: [
        .target(
            name: "TranslateGemmaKit",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ]
        ),
        .executableTarget(
            name: "TranslateGemmaApp",
            dependencies: [
                "TranslateGemmaKit"
            ],
            exclude: [
                "Resources/Info.plist",
                "Resources/TranslateGemmaApp.entitlements"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "LiveDownloadTest",
            dependencies: [
                "TranslateGemmaKit",
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            path: "Sources/Diagnostic",
            sources: ["live_download_test.swift"]
        ),
        .testTarget(
            name: "TranslateGemmaAppTests",
            dependencies: [
                "TranslateGemmaKit",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ]
        ),
    ]
)
