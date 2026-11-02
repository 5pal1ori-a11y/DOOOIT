#if canImport(MLX)
import Foundation
import MLX
import MLXNN

// 정밀 인식 모델 PaddleOCR-VL 1.6 (Apache-2.0): 사진 인코더(NaViT/SigLIP 400M) + 글 모델(ERNIE-4.5-0.3B)
// mlx-swift-lm 3.32.3의 MLXVLM에는 이 구조가 없고, 공개된 Swift 포트(paddleocr-vl.swift)는 맥 전용·다른 MLX 버전·
// 구조가 실제 모델과 달라서, 비교 실험에 쓴 mlx-vlm 0.7.11 (models/paddleocr_vl)을 그대로 옮김 (앱이 이미 쓰는 MLX 위에서)

// MARK: - 설정 (config.json)

struct PaddleOCRVLConfiguration: Decodable {
    struct Vision: Decodable {
        var hiddenSize = 1152
        var intermediateSize = 4304
        var numHiddenLayers = 27
        var numAttentionHeads = 16
        var numChannels = 3
        var imageSize = 384
        var patchSize = 14
        var layerNormEps: Float = 1e-6
        var spatialMergeSize = 2

        enum CodingKeys: String, CodingKey {
            case hiddenSize = "hidden_size", intermediateSize = "intermediate_size", numHiddenLayers = "num_hidden_layers"
            case numAttentionHeads = "num_attention_heads", numChannels = "num_channels", imageSize = "image_size"
            case patchSize = "patch_size", layerNormEps = "layer_norm_eps", spatialMergeSize = "spatial_merge_size"
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hiddenSize = try c.decodeIfPresent(Int.self, forKey: .hiddenSize) ?? hiddenSize
            intermediateSize = try c.decodeIfPresent(Int.self, forKey: .intermediateSize) ?? intermediateSize
            numHiddenLayers = try c.decodeIfPresent(Int.self, forKey: .numHiddenLayers) ?? numHiddenLayers
            numAttentionHeads = try c.decodeIfPresent(Int.self, forKey: .numAttentionHeads) ?? numAttentionHeads
            numChannels = try c.decodeIfPresent(Int.self, forKey: .numChannels) ?? numChannels
            imageSize = try c.decodeIfPresent(Int.self, forKey: .imageSize) ?? imageSize
            patchSize = try c.decodeIfPresent(Int.self, forKey: .patchSize) ?? patchSize
            layerNormEps = try c.decodeIfPresent(Float.self, forKey: .layerNormEps) ?? layerNormEps
            spatialMergeSize = try c.decodeIfPresent(Int.self, forKey: .spatialMergeSize) ?? spatialMergeSize
        }
    }

    struct RopeScaling: Decodable {
        var mropeSection: [Int]?
        enum CodingKeys: String, CodingKey { case mropeSection = "mrope_section" }
    }

    var vision = Vision()
    var hiddenSize = 1024
    var numHiddenLayers = 18
    var intermediateSize = 3072
    var numAttentionHeads = 16
    var numKeyValueHeads = 2
    var headDim = 128
    var vocabSize = 103_424
    var rmsNormEps: Float = 1e-5
    var ropeTheta: Double = 500_000
    var mropeSection = [16, 24, 24]
    var imageTokenID = 100_295
    var eosTokenID = 2

    enum CodingKeys: String, CodingKey {
        case vision = "vision_config", hiddenSize = "hidden_size", numHiddenLayers = "num_hidden_layers"
        case intermediateSize = "intermediate_size", numAttentionHeads = "num_attention_heads"
        case numKeyValueHeads = "num_key_value_heads", headDim = "head_dim", vocabSize = "vocab_size"
        case rmsNormEps = "rms_norm_eps", ropeTheta = "rope_theta", ropeScaling = "rope_scaling"
        case imageTokenID = "image_token_id", eosTokenID = "eos_token_id"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vision = (try? c.decodeIfPresent(Vision.self, forKey: .vision)) ?? Vision()
        hiddenSize = try c.decodeIfPresent(Int.self, forKey: .hiddenSize) ?? hiddenSize
        numHiddenLayers = try c.decodeIfPresent(Int.self, forKey: .numHiddenLayers) ?? numHiddenLayers
        intermediateSize = try c.decodeIfPresent(Int.self, forKey: .intermediateSize) ?? intermediateSize
        numAttentionHeads = try c.decodeIfPresent(Int.self, forKey: .numAttentionHeads) ?? numAttentionHeads
        numKeyValueHeads = try c.decodeIfPresent(Int.self, forKey: .numKeyValueHeads) ?? numKeyValueHeads
        headDim = try c.decodeIfPresent(Int.self, forKey: .headDim) ?? hiddenSize / numAttentionHeads
        vocabSize = try c.decodeIfPresent(Int.self, forKey: .vocabSize) ?? vocabSize
        rmsNormEps = try c.decodeIfPresent(Float.self, forKey: .rmsNormEps) ?? rmsNormEps
        ropeTheta = try c.decodeIfPresent(Double.self, forKey: .ropeTheta) ?? ropeTheta
        if let section = (try? c.decodeIfPresent(RopeScaling.self, forKey: .ropeScaling))??.mropeSection, section.count == 3 {
            mropeSection = section
        }
        imageTokenID = try c.decodeIfPresent(Int.self, forKey: .imageTokenID) ?? imageTokenID
        if let eos = try? c.decodeIfPresent(Int.self, forKey: .eosTokenID) { eosTokenID = eos }
    }
}

// MARK: - 사진 인코더

final class PaddleVisionEmbeddings: Module {
    @ModuleInfo(key: "patch_embedding") var patchEmbedding: Conv2d
    @ModuleInfo(key: "position_embedding") var positionEmbedding: Embedding
    let side: Int
    let dim: Int

    init(_ config: PaddleOCRVLConfiguration.Vision) {
        side = config.imageSize / config.patchSize
        dim = config.hiddenSize
        _patchEmbedding.wrappedValue = Conv2d(inputChannels: config.numChannels, outputChannels: config.hiddenSize,
                                              kernelSize: IntOrPair(config.patchSize), stride: IntOrPair(config.patchSize))
        _positionEmbedding.wrappedValue = Embedding(embeddingCount: side * side, dimensions: config.hiddenSize)
    }

    /// patches: [N, 14, 14, 3] (위에서 아래, 왼쪽에서 오른쪽 조각 순서) → [N, D]
    func callAsFunction(_ patches: MLXArray, gridH: Int, gridW: Int) -> MLXArray {
        let dtype = patchEmbedding.weight.dtype
        let n = patches.dim(0)
        let embedded = patchEmbedding(patches.asType(dtype)).reshaped(n, dim)
        return embedded + positions(gridH: gridH, gridW: gridW)
    }

    /// 27×27 위치 임베딩을 사진 조각 격자 크기로 쌍선형 보간 (mlx-vlm interpolate_pos_encoding)
    func positions(gridH: Int, gridW: Int) -> MLXArray {
        let table = positionEmbedding(MLXArray(Array(0..<Int32(side * side))))
        let (indices, weights) = PaddleBilinear.corners(inputSide: side, height: gridH, width: gridW)
        var sum: MLXArray?
        for k in 0..<4 {
            let gathered = table.take(MLXArray(indices[k]), axis: 0).asType(.float32)
            let w = MLXArray(weights[k], [weights[k].count, 1])
            let part = gathered * w
            sum = sum.map { $0 + part } ?? part
        }
        return sum!.asType(table.dtype)
    }
}

final class PaddleVisionAttention: Module {
    let heads: Int
    let headDim: Int
    let scale: Float
    @ModuleInfo(key: "qkv") var qkv: Linear
    @ModuleInfo(key: "out_proj") var outProj: Linear

    init(dim: Int, heads: Int) {
        self.heads = heads
        headDim = dim / heads
        scale = pow(Float(headDim), -0.5)
        _qkv.wrappedValue = Linear(dim, dim * 3, bias: true)
        _outProj.wrappedValue = Linear(dim, dim, bias: true)
    }

    /// x: [L, D], cos/sin: [1, L, 1, headDim]
    func callAsFunction(_ x: MLXArray, cos: MLXArray, sin: MLXArray) -> MLXArray {
        let length = x.dim(0)
        let parts = qkv(x).reshaped(1, length, 3, heads, headDim).transposed(2, 0, 1, 3, 4)
        var q = parts[0], k = parts[1]
        let v = parts[2]
        q = PaddleRotary.apply(q, cos: cos, sin: sin)
        k = PaddleRotary.apply(k, cos: cos, sin: sin)
        let out = PaddleRotary.chunkedAttention(q.transposed(0, 2, 1, 3), k.transposed(0, 2, 1, 3), v.transposed(0, 2, 1, 3), scale: scale)
        return outProj(out.transposed(0, 2, 1, 3).reshaped(length, -1))
    }
}

final class PaddleVisionMLP: Module {
    @ModuleInfo(key: "fc1") var fc1: Linear
    @ModuleInfo(key: "fc2") var fc2: Linear

    init(dim: Int, hidden: Int) {
        _fc1.wrappedValue = Linear(dim, hidden)
        _fc2.wrappedValue = Linear(hidden, dim)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // gelu_pytorch_tanh (mlx-vlm: nn.GELU(approx="precise") = tanh 근사)
        fc2(geluApproximate(fc1(x)))
    }
}

final class PaddleVisionLayer: Module {
    @ModuleInfo(key: "layer_norm1") var layerNorm1: LayerNorm
    @ModuleInfo(key: "layer_norm2") var layerNorm2: LayerNorm
    @ModuleInfo(key: "self_attn") var attention: PaddleVisionAttention
    @ModuleInfo(key: "mlp") var mlp: PaddleVisionMLP

    init(_ config: PaddleOCRVLConfiguration.Vision) {
        _layerNorm1.wrappedValue = LayerNorm(dimensions: config.hiddenSize, eps: 1e-6)
        _layerNorm2.wrappedValue = LayerNorm(dimensions: config.hiddenSize, eps: 1e-6)
        _attention.wrappedValue = PaddleVisionAttention(dim: config.hiddenSize, heads: config.numAttentionHeads)
        _mlp.wrappedValue = PaddleVisionMLP(dim: config.hiddenSize, hidden: config.intermediateSize)
    }

    func callAsFunction(_ x: MLXArray, cos: MLXArray, sin: MLXArray) -> MLXArray {
        let h = x + attention(layerNorm1(x), cos: cos, sin: sin)
        return h + mlp(layerNorm2(h))
    }
}

/// 조각 2×2를 하나로 합쳐 글 모델 크기(1024)로
final class PaddleProjector: Module {
    let merge: Int
    @ModuleInfo(key: "pre_norm") var preNorm: LayerNorm
    @ModuleInfo(key: "linear_1") var linear1: Linear
    @ModuleInfo(key: "linear_2") var linear2: Linear

    init(dim: Int, contextDim: Int, merge: Int) {
        self.merge = merge
        let hidden = dim * merge * merge
        _preNorm.wrappedValue = LayerNorm(dimensions: dim, eps: 1e-6)
        _linear1.wrappedValue = Linear(hidden, hidden, bias: true)
        _linear2.wrappedValue = Linear(hidden, contextDim, bias: true)
    }

    /// x: [gridH·gridW, D] → [(gridH/2)·(gridW/2), contextDim]
    func callAsFunction(_ x: MLXArray, gridH: Int, gridW: Int) -> MLXArray {
        let d = x.dim(-1)
        var h = preNorm(x)
        h = h.reshaped(1, gridH / merge, merge, gridW / merge, merge, d)
            .transposed(0, 1, 3, 2, 4, 5)
            .reshaped((gridH / merge) * (gridW / merge), merge * merge * d)
        return linear2(gelu(linear1(h)))
    }
}

final class PaddleVisionModel: Module {
    @ModuleInfo(key: "embeddings") var embeddings: PaddleVisionEmbeddings
    @ModuleInfo(key: "layers") var layers: [PaddleVisionLayer]
    @ModuleInfo(key: "post_layernorm") var postLayerNorm: LayerNorm
    @ModuleInfo(key: "projector") var projector: PaddleProjector
    let headDim: Int

    init(_ config: PaddleOCRVLConfiguration.Vision, contextDim: Int) {
        headDim = config.hiddenSize / config.numAttentionHeads
        _embeddings.wrappedValue = PaddleVisionEmbeddings(config)
        _layers.wrappedValue = (0..<config.numHiddenLayers).map { _ in PaddleVisionLayer(config) }
        _postLayerNorm.wrappedValue = LayerNorm(dimensions: config.hiddenSize, eps: config.layerNormEps)
        _projector.wrappedValue = PaddleProjector(dim: config.hiddenSize, contextDim: contextDim, merge: config.spatialMergeSize)
    }

    /// patches [N, 14, 14, 3] → 사진 토큰 [N/4, contextDim]. checkpoint: 층마다 불러서 시간 초과·취소를 확인
    func callAsFunction(_ patches: MLXArray, gridH: Int, gridW: Int, checkpoint: () throws -> Void) rethrows -> MLXArray {
        var h = embeddings(patches, gridH: gridH, gridW: gridW)
        let angles = PaddleRopeIndex.visionAngles(gridH: gridH, gridW: gridW, dim: headDim / 2)
        // [N, headDim/2] → 두 번 이어 붙여 [1, N, 1, headDim]
        let a = MLXArray(angles, [gridH * gridW, headDim / 2])
        let full = concatenated([a, a], axis: -1).reshaped(1, gridH * gridW, 1, headDim)
        let cos = MLX.cos(full), sin = MLX.sin(full)
        for layer in layers {
            h = layer(h, cos: cos, sin: sin)
            eval(h)
            try checkpoint()
        }
        h = postLayerNorm(h)
        return projector(h, gridH: gridH, gridW: gridW)
    }
}

// MARK: - 글 모델 (ERNIE-4.5-0.3B)

final class PaddleKVCache {
    private var keys: MLXArray?
    private var values: MLXArray?
    private(set) var offset = 0
    private let step = 256

    func update(_ k: MLXArray, _ v: MLXArray) -> (MLXArray, MLXArray) {
        let previous = offset
        if keys == nil || previous + k.dim(2) > keys!.dim(2) {
            let steps = (step + k.dim(2) - 1) / step
            let newK = MLXArray.zeros([k.dim(0), k.dim(1), steps * step, k.dim(3)], dtype: k.dtype)
            let newV = MLXArray.zeros([v.dim(0), v.dim(1), steps * step, v.dim(3)], dtype: v.dtype)
            if let oldK = keys, let oldV = values {
                keys = concatenated([oldK[.ellipsis, ..<previous, 0...], newK], axis: 2)
                values = concatenated([oldV[.ellipsis, ..<previous, 0...], newV], axis: 2)
            } else {
                keys = newK
                values = newV
            }
        }
        offset += k.dim(2)
        keys![.ellipsis, previous..<offset, 0...] = k
        values![.ellipsis, previous..<offset, 0...] = v
        return (keys![.ellipsis, ..<offset, 0...], values![.ellipsis, ..<offset, 0...])
    }
}

final class PaddleAttention: Module {
    let heads: Int
    let kvHeads: Int
    let headDim: Int
    let scale: Float
    @ModuleInfo(key: "q_proj") var wq: Linear
    @ModuleInfo(key: "k_proj") var wk: Linear
    @ModuleInfo(key: "v_proj") var wv: Linear
    @ModuleInfo(key: "o_proj") var wo: Linear

    init(_ config: PaddleOCRVLConfiguration) {
        heads = config.numAttentionHeads
        kvHeads = config.numKeyValueHeads
        headDim = config.headDim
        scale = pow(Float(headDim), -0.5)
        _wq.wrappedValue = Linear(config.hiddenSize, heads * headDim, bias: false)
        _wk.wrappedValue = Linear(config.hiddenSize, kvHeads * headDim, bias: false)
        _wv.wrappedValue = Linear(config.hiddenSize, kvHeads * headDim, bias: false)
        _wo.wrappedValue = Linear(heads * headDim, config.hiddenSize, bias: false)
    }

    /// x: [1, L, D], cos/sin: [1, 1, L, headDim]
    func callAsFunction(_ x: MLXArray, cos: MLXArray, sin: MLXArray, cache: PaddleKVCache) -> MLXArray {
        let (b, length) = (x.dim(0), x.dim(1))
        var q = wq(x).reshaped(b, length, heads, headDim).transposed(0, 2, 1, 3)
        var k = wk(x).reshaped(b, length, kvHeads, headDim).transposed(0, 2, 1, 3)
        let v = wv(x).reshaped(b, length, kvHeads, headDim).transposed(0, 2, 1, 3)
        q = PaddleRotary.apply(q, cos: cos, sin: sin)
        k = PaddleRotary.apply(k, cos: cos, sin: sin)
        let (keys, values) = cache.update(k, v)
        let out: MLXArray
        if length > 1 {
            out = MLXFast.scaledDotProductAttention(queries: q, keys: keys, values: values, scale: scale,
                                                    mask: MLXFast.ScaledDotProductAttentionMaskMode.causal)
        } else {
            out = MLXFast.scaledDotProductAttention(queries: q, keys: keys, values: values, scale: scale,
                                                    mask: MLXFast.ScaledDotProductAttentionMaskMode.none)
        }
        return wo(out.transposed(0, 2, 1, 3).reshaped(b, length, -1))
    }
}

final class PaddleMLP: Module {
    @ModuleInfo(key: "gate_proj") var gate: Linear
    @ModuleInfo(key: "up_proj") var up: Linear
    @ModuleInfo(key: "down_proj") var down: Linear

    init(dim: Int, hidden: Int) {
        _gate.wrappedValue = Linear(dim, hidden, bias: false)
        _up.wrappedValue = Linear(dim, hidden, bias: false)
        _down.wrappedValue = Linear(hidden, dim, bias: false)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        down(silu(gate(x)) * up(x))
    }
}

final class PaddleDecoderLayer: Module {
    @ModuleInfo(key: "self_attn") var attention: PaddleAttention
    @ModuleInfo(key: "mlp") var mlp: PaddleMLP
    @ModuleInfo(key: "input_layernorm") var inputLayerNorm: RMSNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionLayerNorm: RMSNorm

    init(_ config: PaddleOCRVLConfiguration) {
        _attention.wrappedValue = PaddleAttention(config)
        _mlp.wrappedValue = PaddleMLP(dim: config.hiddenSize, hidden: config.intermediateSize)
        _inputLayerNorm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        _postAttentionLayerNorm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }

    func callAsFunction(_ x: MLXArray, cos: MLXArray, sin: MLXArray, cache: PaddleKVCache) -> MLXArray {
        let h = x + attention(inputLayerNorm(x), cos: cos, sin: sin, cache: cache)
        return h + mlp(postAttentionLayerNorm(h))
    }
}

final class PaddleTextModel: Module {
    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    @ModuleInfo(key: "layers") var layers: [PaddleDecoderLayer]
    @ModuleInfo(key: "norm") var norm: RMSNorm

    init(_ config: PaddleOCRVLConfiguration) {
        _embedTokens.wrappedValue = Embedding(embeddingCount: config.vocabSize, dimensions: config.hiddenSize)
        _layers.wrappedValue = (0..<config.numHiddenLayers).map { _ in PaddleDecoderLayer(config) }
        _norm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }
}

final class PaddleLanguageModel: Module {
    @ModuleInfo(key: "model") var model: PaddleTextModel
    @ModuleInfo(key: "lm_head") var lmHead: Linear?

    init(_ config: PaddleOCRVLConfiguration, hasHead: Bool) {
        _model.wrappedValue = PaddleTextModel(config)
        if hasHead { _lmHead.wrappedValue = Linear(config.hiddenSize, config.vocabSize, bias: false) }
    }

    /// embeddings [1, L, D] → 마지막 토큰의 다음 토큰 점수 [vocab]
    func lastLogits(_ embeddings: MLXArray, cos: MLXArray, sin: MLXArray, caches: [PaddleKVCache]) -> MLXArray {
        var h = embeddings
        for (layer, cache) in zip(model.layers, caches) { h = layer(h, cos: cos, sin: sin, cache: cache) }
        let last = model.norm(h[0..., (h.dim(1) - 1)..., 0...])
        let logits = lmHead.map { $0(last) } ?? model.embedTokens.asLinear(last)
        return logits.reshaped(-1)
    }
}

final class PaddleOCRVLModel: Module {
    @ModuleInfo(key: "visual") var visual: PaddleVisionModel
    @ModuleInfo(key: "language_model") var languageModel: PaddleLanguageModel
    let config: PaddleOCRVLConfiguration

    init(_ config: PaddleOCRVLConfiguration, hasHead: Bool) {
        self.config = config
        _visual.wrappedValue = PaddleVisionModel(config.vision, contextDim: config.hiddenSize)
        _languageModel.wrappedValue = PaddleLanguageModel(config, hasHead: hasHead)
    }

    /// 앱이 받은 저장소는 mlx-vlm이 이미 정리한 이름(visual.*, language_model.*)이지만, 원본 이름이어도 읽히게
    static func sanitize(_ weights: [String: MLXArray]) -> [String: MLXArray] {
        var out: [String: MLXArray] = [:]
        let converted = weights.keys.contains { $0.hasPrefix("language_model.") }
        for (key, value) in weights {
            var k = key
            if !converted {
                if k.contains("packing_position_embedding") || k.contains("vision_model.head") { continue }
                if k.contains("visual.vision_model") {
                    k = k.replacingOccurrences(of: "visual.vision_model.encoder", with: "visual")
                        .replacingOccurrences(of: "visual.vision_model", with: "visual")
                } else if k.contains("mlp_AR") {
                    k = k.replacingOccurrences(of: "mlp_AR", with: "visual.projector")
                } else if k.hasPrefix("model.") || k.hasPrefix("lm_head") {
                    k = "language_model." + k
                }
            }
            if k.contains("position_ids") { continue }
            var v = value
            // 파이토치 conv [out, in, kH, kW] → MLX [out, kH, kW, in]
            if k.hasSuffix("patch_embedding.weight"), v.ndim == 4, v.dim(1) == 3, v.dim(3) != 3 { v = v.transposed(0, 2, 3, 1) }
            out[k] = v
        }
        if !converted {
            // q_proj·k_proj·v_proj → qkv 하나로
            for key in out.keys where key.hasPrefix("visual") && key.contains("q_proj") {
                let kKey = key.replacingOccurrences(of: "q_proj", with: "k_proj"), vKey = key.replacingOccurrences(of: "q_proj", with: "v_proj")
                guard let q = out[key], let k = out[kKey], let v = out[vKey] else { continue }
                out[key.replacingOccurrences(of: "q_proj", with: "qkv")] = concatenated([q, k, v], axis: 0)
                out[key] = nil; out[kKey] = nil; out[vKey] = nil
            }
        }
        return out
    }
}

// MARK: - 공통 (RoPE · 긴 사진 어텐션)

enum PaddleRotary {
    static func rotateHalf(_ x: MLXArray) -> MLXArray {
        let half = x.dim(-1) / 2
        return concatenated([-x[.ellipsis, half...], x[.ellipsis, ..<half]], axis: -1)
    }

    /// x·cos + rotate_half(x)·sin (float32로 계산하고 원래 형식으로)
    static func apply(_ x: MLXArray, cos: MLXArray, sin: MLXArray) -> MLXArray {
        let dtype = x.dtype
        let f = x.asType(.float32)
        return (f * cos + rotateHalf(f) * sin).asType(dtype)
    }

    /// 사진 조각이 많으면 (긴 사진) 질문 쪽을 1024개씩 나눠 계산: 점수 행렬이 한꺼번에 메모리에 올라가지 않게 (결과는 같음)
    static func chunkedAttention(_ q: MLXArray, _ k: MLXArray, _ v: MLXArray, scale: Float, chunk: Int = 1024) -> MLXArray {
        let length = q.dim(2)
        let none = MLXFast.ScaledDotProductAttentionMaskMode.none
        guard length > chunk * 2 else {
            return MLXFast.scaledDotProductAttention(queries: q, keys: k, values: v, scale: scale, mask: none)
        }
        var parts: [MLXArray] = []
        var start = 0
        while start < length {
            let end = min(length, start + chunk)
            parts.append(MLXFast.scaledDotProductAttention(queries: q[0..., 0..., start..<end, 0...], keys: k, values: v, scale: scale, mask: none))
            start = end
        }
        return concatenated(parts, axis: 2)
    }
}
#endif
