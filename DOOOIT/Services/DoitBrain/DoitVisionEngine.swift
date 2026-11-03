import Foundation
#if canImport(MLXVLM)
import CoreGraphics
import CoreImage
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers
#endif

/// 모티 2(Qwen3.5 4B)를 "사진을 보는 모델"로 불러와 그림 한 장을 읽는 부분 (앱 DoitVision과 맥 확인 도구가 같은 코드를 씀)
/// - 받아 둔 모티 2 폴더를 그대로 씀 (사진 쪽 무게도 이미 들어 있어서 더 받지 않음)
/// - 온도 0, 짧은 답, 생각 모드 끔: 그림에 보이는 사실만 정해진 줄 모양으로 (DoitFigureFacts.visionPrompt)
enum DoitVisionEngine {
    /// 사진을 줄이는 크기 (긴 변). 글자·숫자가 작은 그림이라 512보다 크게, 토큰이 너무 많지 않게
    static let imageSide: CGFloat = 1024
    /// 답 최대 토큰 (사실 줄 20개 안팎)
    static let maxTokens = 320
    /// 한 장 읽기 제한 시간 (초)
    static let timeout: TimeInterval = 60

    struct Reading: Sendable {
        var text: String
        var promptTokens: Int
        var generatedTokens: Int
        var seconds: Double
    }

    #if canImport(MLXVLM)
    /// 받아 둔 폴더에서 사진을 보는 모델로 올림 (인터넷 없이)
    static func load(directory: URL) async throws -> ModelContainer {
        try await VLMModelFactory.shared.loadContainer(from: directory, using: #huggingFaceTokenizerLoader())
    }

    /// 사진 한 장 → 모델이 낸 글 그대로 (사실 줄 읽기는 DoitFigureFacts.parseVision)
    static func read(_ container: ModelContainer, image: CGImage, prompt: String = DoitFigureFacts.visionPrompt, side: CGFloat = imageSide) async throws -> Reading {
        let started = Date()
        let parameters = GenerateParameters(maxTokens: maxTokens, temperature: 0)
        let processing = UserInput.Processing(resize: CGSize(width: side, height: side), maxPixels: Int(side * side))
        let session = ChatSession(container, generateParameters: parameters, processing: processing,
                                  additionalContext: ["enable_thinking": false])
        var text = ""
        var promptTokens = 0, generated = 0
        var filter = ThinkFilter()
        for try await event in session.streamDetails(to: prompt, images: [.ciImage(CIImage(cgImage: image))]) {
            if Task.isCancelled { break }
            switch event {
            case .chunk(let chunk):
                text += filter.feed(chunk)
            case .info(let info):
                promptTokens = info.promptTokenCount
                generated = info.generationTokenCount
            default:
                break
            }
            if Date().timeIntervalSince(started) > timeout { break }
        }
        return Reading(text: text.trimmingCharacters(in: .whitespacesAndNewlines), promptTokens: promptTokens,
                       generatedTokens: generated, seconds: Date().timeIntervalSince(started))
    }

    /// Hugging Face 캐시에 받아 둔 스냅숏 폴더 (models--…/refs/main → snapshots/<커밋>)
    static func localSnapshot(repository: String) -> URL? {
        guard let repo = Repo.ID(rawValue: repository) else { return nil }
        let base = HubCache.default.repoDirectory(repo: repo, kind: .model)
        let snapshots = base.appendingPathComponent("snapshots")
        let fm = FileManager.default
        func usable(_ folder: URL) -> Bool {
            fm.fileExists(atPath: folder.appendingPathComponent("config.json").path)
                && ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).contains { $0.hasSuffix(".safetensors") }
        }
        if let commit = try? String(contentsOf: base.appendingPathComponent("refs/main"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !commit.isEmpty {
            let folder = snapshots.appendingPathComponent(commit)
            if usable(folder) { return folder }
        }
        let folders = (try? fm.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil)) ?? []
        return folders.first(where: usable)
    }
    #endif
}
