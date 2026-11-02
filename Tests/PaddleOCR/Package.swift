// swift-tools-version: 5.9
// 정밀 인식(PaddleOCR-VL) 맥 비교 도구: 앱의 Swift 모델 코드(DOOOIT/Services/PaddleOCR)로 테스트 사진을 읽음
// run.sh가 앱 파일을 Sources/PaddleParity로 복사한 뒤 xcodebuild로 빌드 (MLX Metal 셰이더 때문에 swift build가 아님)
import PackageDescription

let package = Package(
    name: "PaddleParity",
    platforms: [.macOS(.v14)],
    dependencies: [
        // 앱과 같은 버전 범위 (DOOOIT.xcodeproj)
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.32.3")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.3.5")),
    ],
    targets: [
        .executableTarget(
            name: "PaddleParity",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/PaddleParity"
        )
    ]
)
