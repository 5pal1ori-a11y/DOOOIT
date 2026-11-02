#if canImport(MLX)
import CoreGraphics
import Foundation
import MLX
import MLXNN
import Tokenizers

/// 정밀 인식 실행기: 받아 둔 폴더에서 모델을 올리고, 사진 한 장을 "OCR:" 지시로 읽음 (온도 0, 최대 토큰·되풀이 멈춤)
/// 앱(PaddleOCRService)과 맥 비교 도구(Tests/PaddleOCR)가 같은 코드를 씀
actor PaddleOCREngine {
    struct Reading: Sendable {
        var text: String
        var promptTokens: Int
        var generatedTokens: Int
        /// 되풀이 고리를 찾아 멈췄는지
        var repetitionStopped: Bool
        /// 최대 토큰까지 갔는지 (끝을 못 맺음)
        var hitTokenLimit: Bool
        var seconds: Double
    }

    enum EngineError: LocalizedError {
        case notLoaded, missingFiles, badImage, prompt, timeout, cancelled
        var errorDescription: String? {
            switch self {
            case .notLoaded: return "정밀 인식 모델이 아직 준비되지 않았어요."
            case .missingFiles: return "정밀 인식 모델 파일이 없어요."
            case .badImage: return "사진을 읽을 수 없어요."
            case .prompt: return "프롬프트를 만들지 못했어요."
            case .timeout: return "정밀 인식이 너무 오래 걸려요."
            case .cancelled: return "정밀 인식을 멈췄어요."
            }
        }
    }

    private var model: PaddleOCRVLModel?
    private var tokenizer: (any Tokenizers.Tokenizer)?
    private var stopTokens: Set<Int> = []
    /// 앱이 뒤로 가는 등 이유로 지금 읽기를 멈추게 함 (읽는 중에도 바로 닿게 actor 밖에서)
    nonisolated let cancelFlag = PaddleCancelFlag()

    var isLoaded: Bool { model != nil }

    // MARK: 올리기·내리기

    func load(from directory: URL) async throws {
        if model != nil { return }
        let fm = FileManager.default
        let configURL = directory.appendingPathComponent("config.json")
        let files = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "safetensors" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard fm.fileExists(atPath: configURL.path), !files.isEmpty else { throw EngineError.missingFiles }
        let config = try JSONDecoder().decode(PaddleOCRVLConfiguration.self, from: Data(contentsOf: configURL))

        var weights: [String: MLXArray] = [:]
        for file in files {
            for (key, value) in try loadArrays(url: file) { weights[key] = value }
        }
        weights = PaddleOCRVLModel.sanitize(weights)
        let built = PaddleOCRVLModel(config, hasHead: weights["language_model.lm_head.weight"] != nil)

        // 4비트: 저장된 무게에 scales가 있는 층만 (보기: 사진 쪽 fc2는 4304칸이라 양자화하지 않음)
        quantize(model: built) { path, module -> (groupSize: Int, bits: Int, mode: QuantizationMode)? in
            guard let w = weights["\(path).weight"], let s = weights["\(path).scales"] else { return nil }
            let inputs: Int
            if let linear = module as? Linear { inputs = linear.weight.dim(-1) }
            else if let embedding = module as? Embedding { inputs = embedding.weight.dim(-1) }
            else { return nil }
            let found = PaddleQuantization.infer(packedColumns: w.dim(-1), scaleColumns: s.dim(-1), inputDimensions: inputs)
            return (found?.groupSize ?? 64, found?.bits ?? 4, .affine)
        }
        try built.update(parameters: ModuleParameters.unflattened(weights), verify: [.all])
        eval(built)

        let loaded = try await AutoTokenizer.from(modelFolder: directory, strict: false)
        var stops: Set<Int> = [config.eosTokenID]
        let unknown = loaded.unknownTokenId
        for token in ["</s>", "<|end_of_sentence|>"] {
            if let id = loaded.convertTokenToId(token), id != unknown { stops.insert(id) }
        }
        if let eos = loaded.eosTokenId { stops.insert(eos) }
        model = built
        tokenizer = loaded
        stopTokens = stops
    }

    func unload() {
        model = nil
        tokenizer = nil
        Memory.clearCache()
    }

    nonisolated func requestCancel() { cancelFlag.set(true) }

    // MARK: 읽기

    /// 사진 → 모델이 낸 글 그대로 (LaTeX·마크다운). 앱 글 모양으로 바꾸는 건 PaddleOCRText
    func read(_ image: CGImage, instruction: String = PaddleOCRConfig.instruction,
              maxTokens: Int = PaddleOCRConfig.maxTokens, timeout: TimeInterval = PaddleOCRConfig.timeout) throws -> Reading {
        guard let model, let tokenizer else { throw EngineError.notLoaded }
        cancelFlag.set(false)
        let started = Date()
        let deadline = started.addingTimeInterval(timeout)
        defer { Memory.clearCache() }
        func checkpoint() throws {
            if cancelFlag.value || Task.isCancelled { throw EngineError.cancelled }
            if Date() > deadline { throw EngineError.timeout }
        }

        // 1) 사진: 28의 배수 크기로 줄이고 (-1~1), 14×14 조각으로
        guard let size = PaddleImageSize.target(height: image.height, width: image.width),
              let pixels = Self.normalizedPixels(image, width: size.width, height: size.height) else { throw EngineError.badImage }
        let patch = PaddleOCRConfig.patchSize
        let gridH = size.height / patch, gridW = size.width / patch
        let patches = MLXArray(pixels, [gridH, patch, gridW, patch, 3])
            .transposed(0, 2, 1, 3, 4)
            .reshaped(gridH * gridW, patch, patch, 3)

        // 2) 프롬프트: 사진 자리 토큰을 이미지 토큰 수만큼
        let merge = PaddleOCRConfig.mergeSize
        let imageTokens = (gridH / merge) * (gridW / merge)
        let encoded = tokenizer.encode(text: PaddlePrompt.text(instruction), addSpecialTokens: false)
        guard let prompt = PaddlePrompt.expand(encoded, imageTokenID: model.config.imageTokenID, count: imageTokens),
              let imageStart = prompt.firstIndex(of: model.config.imageTokenID) else { throw EngineError.prompt }

        // 3) 사진 인코더 → 사진 토큰을 글 임베딩 사이에 끼움
        let features = try model.visual(patches, gridH: gridH, gridW: gridW, checkpoint: checkpoint)
        let embed = model.languageModel.model.embedTokens
        let before = embed(MLXArray(prompt[..<imageStart].map { Int32($0) })[.newAxis, 0...])
        let after = embed(MLXArray(prompt[(imageStart + imageTokens)...].map { Int32($0) })[.newAxis, 0...])
        let inputs = concatenated([before, features.asType(before.dtype)[.newAxis, 0..., 0...], after], axis: 1)

        // 4) 3D 위치 (글은 한 줄로, 사진은 세로·가로)
        let config = model.config
        let index = PaddleRopeIndex.positions(tokens: prompt, imageTokenID: config.imageTokenID, gridH: gridH / merge, gridW: gridW / merge)
        let caches = (0..<config.numHiddenLayers).map { _ in PaddleKVCache() }
        func rope(t: [Int32], h: [Int32], w: [Int32]) -> (MLXArray, MLXArray) {
            let angles = PaddleRopeIndex.angles(t: t, h: h, w: w, headDim: config.headDim, theta: config.ropeTheta, sections: config.mropeSection)
            let a = MLXArray(angles, [1, 1, t.count, config.headDim])
            return (MLX.cos(a), MLX.sin(a))
        }

        // 5) 미리 채우기 + 한 토큰씩 (온도 0 = 가장 높은 점수)
        let (cos0, sin0) = rope(t: index.t, h: index.h, w: index.w)
        var logits = model.languageModel.lastLogits(inputs, cos: cos0, sin: sin0, caches: caches)
        var generated: [Int] = []
        var repetition = false
        var limit = false
        while true {
            let next = Int(argMax(logits, axis: -1).asType(.int32).item(Int32.self))
            if stopTokens.contains(next) { break }
            generated.append(next)
            if let cut = PaddleRepetition.cutIndex(generated) {
                generated = Array(generated[..<cut])
                repetition = true
                break
            }
            if generated.count >= maxTokens { limit = true; break }
            try checkpoint()
            let position = Int32(caches[0].offset + index.delta)
            let (c, s) = rope(t: [position], h: [position], w: [position])
            let step = embed(MLXArray([Int32(next)])[.newAxis, 0...])
            logits = model.languageModel.lastLogits(step, cos: c, sin: s, caches: caches)
        }
        // SentencePiece(▁·바이트 조각)면 직접 이어 붙임, 아니면 토크나이저에 맡김
        let pieces = generated.map { tokenizer.convertIdToToken($0) ?? "" }
        var text = pieces.contains(where: { $0.contains("\u{2581}") || PaddleDecode.byte($0) != nil })
            ? PaddleDecode.text(pieces: pieces) : tokenizer.decode(tokens: generated, skipSpecialTokens: true)
        if repetition || limit { text = PaddleRepetition.collapseRepeatedLines(text) }
        return Reading(text: text.trimmingCharacters(in: .whitespacesAndNewlines), promptTokens: prompt.count,
                       generatedTokens: generated.count, repetitionStopped: repetition, hitTokenLimit: limit,
                       seconds: Date().timeIntervalSince(started))
    }

    /// 사진 → [H, W, 3] (RGB, (x/255 − 0.5)/0.5). 투명한 곳은 흰색, 줄일 때는 고품질 보간
    static func normalizedPixels(_ image: CGImage, width: Int, height: Int) -> [Float]? {
        let bytesPerRow = width * 4
        var raw = [UInt8](repeating: 255, count: bytesPerRow * height)
        let drawn: Bool = raw.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var out = [Float](repeating: 0, count: width * height * 3)
        for i in 0..<(width * height) {
            out[i * 3] = Float(raw[i * 4]) / 127.5 - 1
            out[i * 3 + 1] = Float(raw[i * 4 + 1]) / 127.5 - 1
            out[i * 3 + 2] = Float(raw[i * 4 + 2]) / 127.5 - 1
        }
        return out
    }
}

/// 읽기 멈춤 표시 (여러 스레드에서 읽고 씀)
final class PaddleCancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set(_ newValue: Bool) { lock.lock(); flag = newValue; lock.unlock() }
}
#endif
