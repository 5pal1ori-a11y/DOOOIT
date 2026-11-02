import Foundation

// 정밀 인식(PaddleOCR-VL) 중 MLX 없이 계산하는 부분 (리눅스 테스트에서도 검사)
// - 언제 정밀 인식을 쓰는지 (모델 · 기기 메모리 · 사진 종류)
// - 같은 말을 되풀이하는 고리(반복) 찾기
// - 사진 크기 맞추기, 위치 번호(3D RoPE), 위치 임베딩 늘리기, 프롬프트

enum PaddleOCRConfig {
    /// Hugging Face 저장소 (Apache-2.0, 4비트 MLX 변환)
    static let repository = "mlx-community/PaddleOCR-VL-1.6-4bit"
    static let title = "정밀 인식 (PaddleOCR-VL)"
    static let sizeText = "약 0.72GB"
    /// 받을 파일 (모델 무게 · 설정 · 토크나이저)
    static let downloadPatterns = ["*.safetensors", "*.json", "*.jinja"]
    /// 6GB 기기부터 (6GB 아이폰은 physicalMemory가 5.5~6GB로 나옴 — DoitBrain과 같은 기준)
    static let minimumMemory: UInt64 = 5_500_000_000
    /// 실험과 같은 지시: 글자 그대로 읽기
    static let instruction = "OCR:"
    /// 한 문제에 쓰는 최대 토큰 (실험의 문제 사진은 많아야 150개, 한 번 1024개까지 되풀이가 있었음)
    static let maxTokens = 640
    /// 읽기 제한 시간 (넘으면 그만두고 Vision으로)
    static let timeout: TimeInterval = 45
    /// 사진 픽셀 수 (preprocessor_config.json과 같음: 최대 1003520 ≈ 이미지 토큰 1280개)
    static let minPixels = 112_896
    static let maxPixels = 1_003_520
    static let patchSize = 14
    static let mergeSize = 2
}

// MARK: - 언제 정밀 인식을 쓰는지

enum PaddleOCRRouting {
    /// 무엇을 읽는 사진인지
    enum Purpose: Equatable {
        /// 수학 문제 (오답노트, MathOCRFixer 교정)
        case mathProblem
        /// 수학이 아닌 과목 문제 (보기 번호만 정리)
        case subjectProblem
        /// 두잇 AI 대화에 보낸 문제 사진
        case chatPhoto
        /// 단어장: Vision이 더 잘 읽어서 (실험) 늘 Vision
        case wordBook
        /// 손글씨 풀이 · 한 쪽에서 문제 나누기: 글자 자리(상자)가 필요해서 Vision
        case handwriting
        case problemSplit
    }

    /// 이 종류의 사진을 정밀 인식으로 읽을 수 있는지 (문제 사진만)
    static func prefersPaddle(_ purpose: Purpose) -> Bool {
        switch purpose {
        case .mathProblem, .subjectProblem, .chatPhoto: return true
        case .wordBook, .handwriting, .problemSplit: return false
        }
    }

    /// 기기 메모리가 충분한지 (6GB 미만이면 Vision만)
    static func deviceCanRun(physicalMemory: UInt64) -> Bool {
        physicalMemory >= PaddleOCRConfig.minimumMemory
    }

    /// 정밀 인식으로 읽을지: 문제 사진 + 실기기 + 모델을 받아 둠 + 메모리 6GB 이상 + 이번에 계속 실패하지 않음
    /// (아니면 지금처럼 Vision으로)
    static func shouldUsePaddle(_ purpose: Purpose, supported: Bool, installed: Bool, physicalMemory: UInt64, failures: Int = 0) -> Bool {
        prefersPaddle(purpose) && supported && installed && deviceCanRun(physicalMemory: physicalMemory) && failures < 3
    }
}

// MARK: - 되풀이 고리 찾기

/// 모델이 같은 말을 끝없이 되풀이하는 고리 (예: "δὰὑσσί ἐπιρὰν δὰὑσσί ἐπιρὰν …")를 찾아 일찍 멈춤
enum PaddleRepetition {
    /// 끝부분이 같은 토큰 묶음의 되풀이면, 남길 토큰 수 (한 번은 남기고 나머지 되풀이는 버림). 아니면 nil
    /// - period: 되풀이 묶음 길이 1…maxPeriod
    /// - 묶음이 길수록 적게 되풀이돼도 고리로 봄 (묶음×횟수 ≥ minSpan, 4번 이상), 한 토큰 되풀이는 minSingle번 이상
    static func cutIndex(_ tokens: [Int], maxPeriod: Int = 48, minRepeats: Int = 4, minSpan: Int = 40, minSingle: Int = 32) -> Int? {
        let n = tokens.count
        guard n >= 2 * minRepeats else { return nil }
        for period in 1...min(maxPeriod, n / 2) {
            let needed = period == 1 ? minSingle : max(minRepeats, (minSpan + period - 1) / period)
            guard needed * period <= n else { continue }
            var repeats = 1
            while (repeats + 1) * period <= n {
                let start = n - (repeats + 1) * period
                var same = true
                for k in 0..<period where tokens[start + k] != tokens[n - period + k] { same = false; break }
                guard same else { break }
                repeats += 1
            }
            if repeats >= needed { return n - repeats * period + period }
        }
        return nil
    }

    /// 글 기준 되풀이 (줄 단위): 같은 줄이 연달아 minRepeats번 이상이면 한 줄만 남김 — 토큰이 조금씩 달라도 잡음
    static func collapseRepeatedLines(_ text: String, minRepeats: Int = 4) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0
        while i < lines.count {
            let key = lines[i].trimmingCharacters(in: .whitespaces)
            var j = i + 1
            while j < lines.count, !key.isEmpty, lines[j].trimmingCharacters(in: .whitespaces) == key { j += 1 }
            result.append(contentsOf: j - i >= minRepeats ? [lines[i]] : Array(lines[i..<j]))
            i = j
        }
        return result.joined(separator: "\n")
    }
}

// MARK: - 토큰 → 글

/// SentencePiece 조각(▁ = 띄어쓰기, <0xE3> 같은 바이트 조각)을 글로
/// swift-transformers 1.3의 ByteFallback 디코더는 끝에 남은 바이트 조각을 버려서 ("O²⁻" → "O²", 끝의 "ㄷ" 사라짐) 직접 이어 붙임
enum PaddleDecode {
    static func text(pieces: [String]) -> String {
        var bytes: [UInt8] = []
        for piece in pieces {
            if let byte = byte(piece) { bytes.append(byte); continue }
            if isSpecial(piece) { continue }
            bytes.append(contentsOf: Array(piece.replacingOccurrences(of: "\u{2581}", with: " ").utf8))
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func byte(_ piece: String) -> UInt8? {
        guard piece.count == 6, piece.hasPrefix("<0x"), piece.hasSuffix(">") else { return nil }
        return UInt8(piece.dropFirst(3).prefix(2), radix: 16)
    }

    /// 특수 토큰 (<|LOC_3|>, </s>, <unk> …)
    static func isSpecial(_ piece: String) -> Bool {
        (piece.hasPrefix("<|") && piece.hasSuffix("|>")) || ["<s>", "</s>", "<unk>", "<mask:1>"].contains(piece)
    }
}

// MARK: - 사진 크기

enum PaddleImageSize {
    /// 모델에 넣을 크기 (Qwen2-VL과 같은 smart_resize: 28의 배수, 픽셀 수 min~max) — 파이썬 round(반올림 짝수)까지 같게
    static func target(height: Int, width: Int, factor: Int = PaddleOCRConfig.patchSize * PaddleOCRConfig.mergeSize,
                       minPixels: Int = PaddleOCRConfig.minPixels, maxPixels: Int = PaddleOCRConfig.maxPixels) -> (height: Int, width: Int)? {
        guard height > 0, width > 0 else { return nil }
        var h = Double(height), w = Double(width)
        let f = Double(factor)
        if h < f { w = (w * f / h).rounded(.toNearestOrEven); h = f }
        if w < f { h = (h * f / w).rounded(.toNearestOrEven); w = f }
        guard max(h, w) / min(h, w) <= 200 else { return nil }
        var hBar = (h / f).rounded(.toNearestOrEven) * f
        var wBar = (w / f).rounded(.toNearestOrEven) * f
        if hBar * wBar > Double(maxPixels) {
            let beta = ((h * w) / Double(maxPixels)).squareRoot()
            hBar = (h / beta / f).rounded(.down) * f
            wBar = (w / beta / f).rounded(.down) * f
        } else if hBar * wBar < Double(minPixels) {
            let beta = (Double(minPixels) / (h * w)).squareRoot()
            hBar = (h * beta / f).rounded(.up) * f
            wBar = (w * beta / f).rounded(.up) * f
        }
        guard hBar >= f, wBar >= f else { return nil }
        return (Int(hBar), Int(wBar))
    }

    /// 사진 한 장의 이미지 토큰 수 (14×14 조각 4개를 하나로 합침)
    static func imageTokens(height: Int, width: Int) -> Int {
        (height / PaddleOCRConfig.patchSize) * (width / PaddleOCRConfig.patchSize) / (PaddleOCRConfig.mergeSize * PaddleOCRConfig.mergeSize)
    }
}

// MARK: - 프롬프트

enum PaddlePrompt {
    static let imageToken = "<|IMAGE_PLACEHOLDER|>"

    /// 모델의 대화 틀(chat_template.jinja)과 같은 글: 사진 한 장 + 지시
    static func text(_ instruction: String = PaddleOCRConfig.instruction) -> String {
        "<|begin_of_sentence|>User: <|IMAGE_START|>\(imageToken)<|IMAGE_END|>\(instruction)\nAssistant:\n"
    }

    /// 사진 자리 토큰 하나를 이미지 토큰 수만큼 늘림 (자리가 정확히 하나가 아니면 nil)
    static func expand(_ tokens: [Int], imageTokenID: Int, count: Int) -> [Int]? {
        let places = tokens.indices.filter { tokens[$0] == imageTokenID }
        guard places.count == 1, count > 0, let at = places.first else { return nil }
        return Array(tokens[..<at]) + Array(repeating: imageTokenID, count: count) + Array(tokens[(at + 1)...])
    }
}

// MARK: - 위치 번호 (3D RoPE: 글은 한 줄로, 사진 토큰은 세로·가로 자리)

enum PaddleRopeIndex {
    /// 토큰마다 (t, h, w) 위치와 delta (다음 글 토큰 위치 = 캐시 길이 + delta)
    /// gridH, gridW: 합친 뒤 사진 토큰의 세로·가로 개수 (14×14 조각 2×2 = 한 토큰)
    static func positions(tokens: [Int], imageTokenID: Int, gridH: Int, gridW: Int) -> (t: [Int32], h: [Int32], w: [Int32], delta: Int) {
        var t: [Int32] = [], h: [Int32] = [], w: [Int32] = []
        t.reserveCapacity(tokens.count); h.reserveCapacity(tokens.count); w.reserveCapacity(tokens.count)
        var next: Int32 = 0
        func text(_ count: Int) {
            for _ in 0..<max(count, 0) { t.append(next); h.append(next); w.append(next); next += 1 }
        }
        guard let start = tokens.firstIndex(of: imageTokenID), gridH > 0, gridW > 0 else {
            text(tokens.count)
            return (t, h, w, 0)
        }
        text(start)
        let base = next
        for row in 0..<gridH {
            for col in 0..<gridW {
                t.append(base); h.append(base + Int32(row)); w.append(base + Int32(col))
            }
        }
        next = base + Int32(max(gridH, gridW))
        text(tokens.count - start - gridH * gridW)
        return (t, h, w, Int(next) - tokens.count)
    }

    /// 글 RoPE의 주파수 (head_dim 128 → 64개), 3D 구역 [16, 24, 24]: 앞 16개는 t, 다음 24개는 h, 나머지 24개는 w 위치를 씀
    static func angles(t: [Int32], h: [Int32], w: [Int32], headDim: Int, theta: Double, sections: [Int]) -> [Float] {
        let half = headDim / 2
        let inv = (0..<half).map { Float(1.0 / pow(theta, Double(2 * $0) / Double(headDim))) }
        var owner = [Int](repeating: 2, count: half)
        var k = 0
        for (s, length) in sections.enumerated() {
            for _ in 0..<length where k < half { owner[k] = s % 3; k += 1 }
        }
        let count = t.count
        var out = [Float](repeating: 0, count: count * headDim)
        for i in 0..<count {
            let p = [Float(t[i]), Float(h[i]), Float(w[i])]
            for j in 0..<half {
                let a = p[owner[j]] * inv[j]
                out[i * headDim + j] = a
                out[i * headDim + half + j] = a
            }
        }
        return out
    }

    /// 사진 쪽 RoPE (조각마다 세로·가로 자리): dim = head_dim/2, 결과는 조각마다 [세로 주파수…, 가로 주파수…] (dim개)
    static func visionAngles(gridH: Int, gridW: Int, dim: Int, theta: Double = 10_000) -> [Float] {
        let count = dim / 2
        let inv = (0..<count).map { Float(1.0 / pow(theta, Double(2 * $0) / Double(dim))) }
        var out = [Float](repeating: 0, count: gridH * gridW * dim)
        for row in 0..<gridH {
            for col in 0..<gridW {
                let base = (row * gridW + col) * dim
                for j in 0..<count {
                    out[base + j] = Float(row) * inv[j]
                    out[base + count + j] = Float(col) * inv[j]
                }
            }
        }
        return out
    }
}

// MARK: - 위치 임베딩 늘리기 (27×27 → 사진 조각 수, 쌍선형)

enum PaddleBilinear {
    /// 한 축의 샘플 위치: (아래 칸, 위 칸, 무게) — mlx-vlm bilinear_interpolate(align_corners=False)와 같은 계산
    static func axis(input: Int, output: Int) -> [(lo: Int, hi: Int, weight: Float)] {
        (0..<output).map { i in
            let pos: Float = output == 1 ? 0 : (Float(i) + 0.5) * Float(input) / Float(output) - 0.5
            let floorIndex = Int(pos.rounded(.down))
            let lo = min(max(floorIndex, 0), input - 1)
            let hi = min(max(floorIndex + 1, 0), input - 1)
            return (lo, hi, pos - Float(lo))
        }
    }

    /// 출력 칸마다 네 모서리 (입력 칸 번호, 무게)
    static func corners(inputSide: Int, height: Int, width: Int) -> (indices: [[Int32]], weights: [[Float]]) {
        let rows = axis(input: inputSide, output: height), cols = axis(input: inputSide, output: width)
        var indices = [[Int32]](repeating: [], count: 4), weights = [[Float]](repeating: [], count: 4)
        for r in rows {
            for c in cols {
                let pairs: [(Int, Int, Float)] = [
                    (r.lo, c.lo, (1 - r.weight) * (1 - c.weight)), (r.lo, c.hi, (1 - r.weight) * c.weight),
                    (r.hi, c.lo, r.weight * (1 - c.weight)), (r.hi, c.hi, r.weight * c.weight),
                ]
                for (k, p) in pairs.enumerated() {
                    indices[k].append(Int32(p.0 * inputSide + p.1))
                    weights[k].append(p.2)
                }
            }
        }
        return (indices, weights)
    }
}

// MARK: - 양자화 설정 알아내기

enum PaddleQuantization {
    /// 저장된 무게 모양으로 (group_size, bits): weight [out, in·bits/32], scales [out, in/group]
    static func infer(packedColumns: Int, scaleColumns: Int, inputDimensions: Int) -> (groupSize: Int, bits: Int)? {
        guard inputDimensions > 0, scaleColumns > 0, (packedColumns * 32) % inputDimensions == 0, inputDimensions % scaleColumns == 0 else { return nil }
        let bits = packedColumns * 32 / inputDimensions
        let group = inputDimensions / scaleColumns
        guard [2, 3, 4, 5, 6, 8].contains(bits), [32, 64, 128].contains(group) else { return nil }
        return (group, bits)
    }
}
