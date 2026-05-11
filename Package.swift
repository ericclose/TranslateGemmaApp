// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TranslateGemmaApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TranslateGemmaLibrary", targets: ["TranslateGemmaLibrary"]),
        .executable(name: "TranslateGemmaApp", targets: ["TranslateGemmaApp"]),
        .executable(name: "Diagnostic", targets: ["Diagnostic"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.3"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "3.31.3"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.2"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "TranslateGemmaLibrary",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ]
        ),
        .executableTarget(
            name: "TranslateGemmaApp",
            dependencies: [
                "TranslateGemmaLibrary",
                .product(name: "MLX", package: "mlx-swift"),
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
            name: "Diagnostic",
            dependencies: [
                "TranslateGemmaLibrary",
                .product(name: "MLX", package: "mlx-swift"),
            ]
        ),
        .testTarget(
            name: "TranslateGemmaAppTests",
            dependencies: ["TranslateGemmaLibrary"]
        ),
    ]
)
