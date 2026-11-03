// swift-tools-version: 5.9
// 그림 읽기 확인 도구 (맥): 앱의 그림 읽기 코드(기본 판독 · 정밀 인식 표/차트 · 두잇 2 사진 읽기)로 테스트 그림을 읽음
// run.sh가 앱 파일을 Sources/FigureEval로 복사한 뒤 xcodebuild로 빌드 (MLX Metal 셰이더 때문에 swift build가 아님)
import PackageDescription

let package = Package(
    name: "FigureEval",
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
            name: "FigureEval",
            dependencies: [
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
            ],
            path: "Sources/FigureEval"
        )
    ]
)
