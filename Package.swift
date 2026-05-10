// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TranslateGemmaApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TranslateGemmaApp", targets: ["TranslateGemmaApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "0.1.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TranslateGemmaApp",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TranslateGemmaAppTests",
            dependencies: ["TranslateGemmaApp"]
        ),
    ]
)
