// swift-tools-version: 5.9
// 두잇 1·2 모델 확인 도구 (맥): 앱(DoitBrain)과 똑같이 모델을 불러와 답을 만들어 봄
// mac.sh가 앱의 ThinkFilter를 Sources/ModelEval로 복사한 뒤 xcodebuild로 빌드 (MLX Metal 셰이더 때문에 swift build가 아님)
import PackageDescription

let package = Package(
    name: "ModelEval",
    platforms: [.macOS(.v14)],
    dependencies: [
        // 앱과 같은 버전 범위 (project.yml · DOOOIT.xcodeproj)
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.32.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.3.5")),
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.32.3")),
    ],
    targets: [
        .executableTarget(
            name: "ModelEval",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "MLX", package: "mlx-swift"),
            ],
            path: "Sources/ModelEval"
        )
    ]
)
