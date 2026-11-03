import Foundation
import Observation
#if canImport(UIKit)
import UIKit
import os
#endif
#if canImport(MLX)
import MLX
#endif
#if canImport(MLXLLM)
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
#endif

/// 두잇 AI 모델 관리: 두잇 1 · 두잇 2 (휴대폰 안에서 돌아가는 언어 모델)
/// - 고른 모델을 처음 한 번만 다운로드하면 인터넷 없이도 돌아가요.
/// - 앱 기능, 수학 풀이, 계산처럼 정확해야 하는 일은 규칙형 엔진이 그대로 맡고,
///   설명·대화·학습 자료 만들기처럼 "자기 말로" 해야 하는 일을 모델이 맡아요.
/// (두잇 1 = Qwen3 1.7B, 두잇 2 = Qwen3.5 4B — Apache-2.0 오픈소스 모델을 바탕으로 함)
/// 100문제 비교: 수학 외 과목 4B 45/60 · 1.7B 34/60 · Qwen3.5 2B 29/60 → 2B보다 1.7B가 나아서 두잇 1은 1.7B
/// 예전 두잇 2(1.7B)를 받아 둔 기기는 그 파일을 새 두잇 1로 그대로 쓰고, 예전 두잇 1(0.6B) 파일은 지워요.
@MainActor
@Observable
final class DoitBrain {
    static let shared = DoitBrain()

    enum Model: String, CaseIterable, Identifiable {
        case dooit1, dooit2

        var id: String { rawValue }
        var title: String { self == .dooit1 ? "두잇 1" : "두잇 2" }
        var detail: String { self == .dooit1 ? "빠르고 가볍게" : "더 똑똑하고 자세하게" }
        var sizeText: String { self == .dooit1 ? "약 0.9GB" : "약 2.9GB" }
        var repository: String { self == .dooit1 ? "mlx-community/Qwen3-1.7B-4bit" : "mlx-community/Qwen3.5-4B-MLX-4bit" }

        /// 이 모델을 돌릴 메모리: 두잇 1(1.7B)은 지금처럼 모든 기기, 두잇 2(4B)는 8GB 이상 (8GB 기기는 7.5GB 넘게 잡혀요)
        var minimumMemory: UInt64 { self == .dooit1 ? 0 : 7_500_000_000 }
        /// 불러올 때 앱이 더 쓸 수 있어야 하는 메모리 (Mac 측정: 1.7B 최대 1.6GB, 4B 최대 3.2GB + 여유)
        var neededMemory: UInt64 { self == .dooit1 ? 2_000_000_000 : 3_700_000_000 }
        /// 생각 모드를 쓸 수 있는지: Qwen3.5 4B는 앱의 토큰 예산 안에서 생각을 끝내지 못해 답이 비어서 끔
        var thinks: Bool { self == .dooit1 }
        var fitsDevice: Bool { ProcessInfo.processInfo.physicalMemory >= minimumMemory }

        /// 기기 메모리에 맞는 모델 (8GB 미만이면 두잇 1)
        static var recommended: Model { Model.dooit2.fitsDevice ? .dooit2 : .dooit1 }

        /// 예전 두잇 1 (Qwen3 0.6B) — 새 모델로 바꿀 때 지움
        static let legacyRepositories = ["mlx-community/Qwen3-0.6B-4bit"]
    }

    enum Phase: Equatable {
        /// 고른 모델이 없거나 아직 다운로드하지 않음
        case notInstalled
        /// 다운로드 중 (0~1)
        case downloading(Double)
        /// 메모리에 올리는 중
        case loading
        /// 바로 답할 수 있음
        case ready
        /// 다운로드했지만 메모리에서 내려 둠 (다음에 쓸 때 다시 올림)
        case sleeping
        case failed(String)
    }

    enum BrainError: LocalizedError {
        case notReady, busy, unsupported
        var errorDescription: String? {
            switch self {
            case .notReady: return "모델이 아직 준비되지 않았어요."
            case .busy: return "다른 답을 만드는 중이에요."
            case .unsupported: return "이 기기에서는 모델을 쓸 수 없어요."
            }
        }
    }

    private(set) var phase: Phase = .notInstalled
    /// 지금 쓰는 모델 (nil = 기본 모드, 모델 없이 규칙형 엔진만)
    private(set) var selected: Model?
    /// 다운로드 중인 모델
    private(set) var downloading: Model?
    /// 다운로드해 둔 모델들
    private(set) var installed: Set<Model> = []

    private let selectedKey = "doitModel.selected"
    /// 모델 세대 (2 = Qwen3.5). 예전 세대의 '받아 둠' 표시는 새 모델에 맞지 않아서 지움
    private let generationKey = "doitModel.generation"
    private func installedKey(_ model: Model) -> String { "doitModel.installed.\(model.rawValue)" }

    func isInstalled(_ model: Model) -> Bool { installed.contains(model) }

    /// 질문에 쓸 수 있는지 (고른 모델을 다운로드해 둠 — 메모리에 없으면 쓸 때 올림)
    var isAvailable: Bool {
        guard Self.isSupported, let selected, installed.contains(selected) else { return false }
        switch phase {
        case .ready, .sleeping, .loading: return true
        default: return false
        }
    }

    var isBusy: Bool { generating }

    /// 휴대폰 실기기에서만 (시뮬레이터·리눅스 테스트에서는 꺼짐), 메모리 6GB 이상 (두잇 1을 돌릴 수 있어야 함)
    static var isSupported: Bool {
        #if canImport(MLXLLM) && !targetEnvironment(simulator)
        return Model.dooit1.fitsDevice
        #else
        return false
        #endif
    }

    @ObservationIgnored private var generating = false
    @ObservationIgnored private var loadTask: Task<Bool, Never>?
    @ObservationIgnored private var loadedModel: Model?
    #if canImport(MLXLLM)
    @ObservationIgnored private var container: ModelContainer?
    #endif

    private init() {
        let defaults = UserDefaults.standard
        // 예전 버전(모델 하나)의 설정을 이어받음
        if let oldRepo = defaults.string(forKey: "doitBrain.installed") {
            let model: Model = oldRepo.contains("1.7B") ? .dooit2 : .dooit1
            defaults.set(true, forKey: installedKey(model))
            if defaults.object(forKey: "doitBrain.enabled") as? Bool ?? true { defaults.set(model.rawValue, forKey: selectedKey) }
            for key in ["doitBrain.installed", "doitBrain.enabled", "doitBrain.size"] { defaults.removeObject(forKey: key) }
        }
        // 예전 세대: 두잇 1 = 0.6B, 두잇 2 = 1.7B → 새 세대: 두잇 1 = 1.7B, 두잇 2 = 4B
        // 받아 둔 1.7B는 새 두잇 1로 그대로 쓰고 (다시 받지 않음), 0.6B 파일은 지움
        if defaults.integer(forKey: generationKey) < 2 {
            let had17 = defaults.bool(forKey: installedKey(.dooit2))
            for model in Model.allCases { defaults.removeObject(forKey: installedKey(model)) }
            if had17 {
                defaults.set(true, forKey: installedKey(.dooit1))
                if defaults.string(forKey: selectedKey) != nil { defaults.set(Model.dooit1.rawValue, forKey: selectedKey) }
            } else {
                defaults.removeObject(forKey: selectedKey)
            }
            #if canImport(MLXLLM)
            for name in Model.legacyRepositories {
                if let repo = Repo.ID(rawValue: name) { try? FileManager.default.removeItem(at: HubCache.default.repoDirectory(repo: repo, kind: .model)) }
            }
            #endif
            defaults.set(2, forKey: generationKey)
        }
        installed = Set(Model.allCases.filter { defaults.bool(forKey: installedKey($0)) })
        selected = defaults.string(forKey: selectedKey).flatMap(Model.init(rawValue:)).flatMap { installed.contains($0) ? $0 : nil }
        if selected != nil { phase = .sleeping }
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DoitBrain.shared.sleep() }
        }
        #endif
    }

    // MARK: 고르기·다운로드·삭제

    /// 모델 고르기 (nil = 기본 모드). 다운로드하지 않은 모델은 download로
    func select(_ model: Model?) {
        guard model != selected else { return }
        if let model, !installed.contains(model) { return }
        unload()
        selected = model
        UserDefaults.standard.set(model?.rawValue, forKey: selectedKey)
        phase = model == nil ? .notInstalled : .sleeping
    }

    /// 다운로드하고 그 모델로 바꿈 (이미 받았으면 바로 바꿈)
    @discardableResult
    func download(_ model: Model) async -> Bool {
        guard Self.isSupported, model.fitsDevice else { phase = .failed(BrainError.unsupported.localizedDescription); return false }
        if installed.contains(model) { select(model); return await prepare() }
        guard downloading == nil else { return false }
        unload()
        selected = model
        UserDefaults.standard.set(model.rawValue, forKey: selectedKey)
        return await load(model, downloading: true)
    }

    /// 다운로드한 모델 지우기
    func delete(_ model: Model) {
        if loadedModel == model { unload() }
        #if canImport(MLXLLM)
        if let repo = Repo.ID(rawValue: model.repository) {
            try? FileManager.default.removeItem(at: HubCache.default.repoDirectory(repo: repo, kind: .model))
        }
        #endif
        installed.remove(model)
        UserDefaults.standard.removeObject(forKey: installedKey(model))
        if selected == model {
            // 다른 모델이 있으면 그걸로, 없으면 기본 모드
            selected = installed.first
            UserDefaults.standard.set(selected?.rawValue, forKey: selectedKey)
            phase = selected == nil ? .notInstalled : .sleeping
        }
    }

    /// 쓸 준비 (메모리에 없으면 올림). 다운로드하지 않았으면 false
    @discardableResult
    func prepare() async -> Bool {
        guard Self.isSupported, let selected, installed.contains(selected) else { return false }
        if phase == .ready, loadedModel == selected { return true }
        return await load(selected, downloading: false)
    }

    /// iOS가 앱을 끄기 전까지 앱이 더 쓸 수 있는 메모리 (리눅스 테스트·맥에서는 제한 없음)
    static var availableMemory: UInt64 {
        #if canImport(UIKit) && !targetEnvironment(simulator)
        return UInt64(os_proc_available_memory())
        #else
        return .max
        #endif
    }

    private func load(_ model: Model, downloading isDownload: Bool) async -> Bool {
        // 받지 않은 모델은 사용자가 직접 "다운로드"를 눌렀을 때만 받음 (데이터 요금 방지)
        guard isDownload || installed.contains(model) else { return false }
        if let loadTask { return await loadTask.value }
        // 메모리가 모자라면 불러오지 않음 (불러오다 iOS가 앱을 끄는 것 막기) → 규칙형 엔진으로 답함
        if loadedModel != model {
            unload()
            // 그림 읽기(두잇 2 사진 모델)가 올라와 있으면 내림: 큰 모델은 한 번에 하나만
            DoitVision.shared.unload()
            #if canImport(MLX)
            MLX.Memory.clearCache()
            #endif
            if Self.availableMemory < model.neededMemory {
                phase = .failed(model == .dooit2 ? "메모리가 모자라 두잇 2를 켜지 못했어요. 다른 앱을 닫거나 두잇 1을 써 주세요."
                                                 : "메모리가 모자라 \(model.title)을(를) 켜지 못했어요. 다른 앱을 닫고 다시 해 주세요.")
                return false
            }
        }
        let task = Task { @MainActor () -> Bool in
            defer { self.loadTask = nil; self.downloading = nil }
            #if canImport(MLXLLM)
            let configuration = ModelConfiguration(id: model.repository, defaultPrompt: "", extraEOSTokens: ["<|im_end|>"])
            let fresh = !self.installed.contains(model)
            if fresh { self.downloading = model }
            self.phase = fresh ? .downloading(0) : .loading
            do {
                // 글 모델로만 올림 (앱에 사진을 보는 MLXVLM도 들어 있어서, 공용 불러오기를 쓰면 Qwen3.5가 사진 쪽 무게까지 올라감)
                let loaded = try await LLMModelFactory.shared.loadContainer(from: #hubDownloader(), using: #huggingFaceTokenizerLoader(),
                                                                            configuration: configuration, progressHandler: { progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor in
                        let brain = DoitBrain.shared
                        if case .downloading = brain.phase, fraction < 1 { brain.phase = .downloading(fraction) }
                        else if fraction >= 1 { brain.phase = .loading }
                    }
                })
                self.container = loaded
                self.loadedModel = model
                #if canImport(MLX)
                // 계산에 쓴 메모리를 오래 붙잡지 않게 (메모리 부족으로 앱이 꺼지지 않게)
                MLX.Memory.cacheLimit = 64 * 1024 * 1024
                #endif
                self.installed.insert(model)
                UserDefaults.standard.set(true, forKey: self.installedKey(model))
                // 받는 동안 다른 모델로 바꿨으면 그 모델을 그대로 둠
                if self.selected == model { self.phase = .ready } else { self.unload() }
                return self.selected == model
            } catch {
                self.container = nil
                self.loadedModel = nil
                self.phase = fresh ? .failed("\(model.title)을(를) 다운로드하지 못했어요. 와이파이와 저장 공간을 확인해 주세요.")
                                   : .failed("\(model.title)을(를) 불러오지 못했어요. 다시 시도해 주세요.")
                return false
            }
            #else
            _ = model
            return false
            #endif
        }
        loadTask = task
        return await task.value
    }

    private func unload() {
        #if canImport(MLXLLM)
        container = nil
        #endif
        loadedModel = nil
    }

    /// 메모리에서 내림 (기기 메모리가 부족할 때)
    func sleep() {
        guard !generating else { return }
        unload()
        if phase == .ready { phase = .sleeping }
    }

    // MARK: 답 만들기

    /// 글을 조금씩 만들어 보냄 (생각 과정 <think>는 걸러서)
    /// thinking: 답하기 전에 속으로 생각(추론)하게 함 — 더 정확하지만 느림, 생각 과정은 걸러서 안 보여 줌
    /// history: 이전 대화 (학생·두잇 역할 그대로 Qwen 대화 형식으로 넣음, 학생 말로 시작)
    func stream(system: String, prompt: String, history: [DoitMind.Turn] = [], maxTokens: Int = 700, temperature: Float = 0.6, thinking: Bool = false) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                guard !self.generating else { continuation.finish(throwing: BrainError.busy); return }
                guard await self.prepare() else { continuation.finish(throwing: BrainError.notReady); return }
                self.generating = true
                defer { self.generating = false }
                // 생각 모드를 못 쓰는 모델(두잇 2, Qwen3.5 4B)은 끔
                let thinking = thinking && (self.selected?.thinks ?? false)
                #if canImport(MLXLLM)
                guard let container = self.container else { continuation.finish(throwing: BrainError.notReady); return }
                let parameters = GenerateParameters(maxTokens: maxTokens, temperature: temperature, topP: 0.9, repetitionPenalty: 1.1)
                let session: ChatSession
                if history.isEmpty {
                    session = ChatSession(container, instructions: system, generateParameters: parameters, additionalContext: ["enable_thinking": thinking])
                } else {
                    let turns = history.map { turn -> MLXLMCommon.Chat.Message in turn.fromUser ? .user(turn.text) : .assistant(turn.text) }
                    session = ChatSession(container, instructions: system, history: turns, generateParameters: parameters, additionalContext: ["enable_thinking": thinking])
                }
                // Qwen3.5는 생각 모드에서 대화 형식이 '<think>'를 미리 넣어 줘서, 모델 글은 '<think>' 없이 생각부터 나옴
                var filter = ThinkFilter(startsInThink: thinking)
                do {
                    for try await chunk in session.streamResponse(to: prompt) {
                        if Task.isCancelled { break }
                        let visible = filter.feed(chunk)
                        if !visible.isEmpty { continuation.yield(visible) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: BrainError.unsupported)
                #endif
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 한 번에 다 만든 답
    func complete(system: String, prompt: String, history: [DoitMind.Turn] = [], maxTokens: Int = 700, temperature: Float = 0.5, thinking: Bool = false) async throws -> String {
        var text = ""
        for try await chunk in stream(system: system, prompt: prompt, history: history, maxTokens: maxTokens, temperature: temperature, thinking: thinking) { text += chunk }
        return text
    }

    /// 이전 대화에 쓸 토큰 예산 (작은 모델은 짧게)
    var historyBudget: Int { selected == .dooit2 ? 1500 : 1100 }
}

/// 모델이 내보내는 <think>…</think> (생각 과정)를 걸러냄 — 조각으로 나뉘어 와도 처리
struct ThinkFilter {
    private var buffer = ""
    private var inThink = false

    /// startsInThink: 생각 과정 안에서 시작 (대화 형식이 '<think>'를 미리 넣은 경우) → '</think>'까지 버림
    init(startsInThink: Bool = false) { inThink = startsInThink }

    mutating func feed(_ chunk: String) -> String {
        buffer += chunk
        var output = ""
        while true {
            if inThink {
                guard let end = buffer.range(of: "</think>") else {
                    // 닫는 태그 조각이 남아 있을 수 있어 끝부분만 남김
                    buffer = String(buffer.suffix(8))
                    return output
                }
                buffer = String(buffer[end.upperBound...])
                inThink = false
            } else if let start = buffer.range(of: "<think>") {
                output += buffer[..<start.lowerBound]
                buffer = String(buffer[start.upperBound...])
                inThink = true
            } else {
                // "<thi"처럼 태그가 잘려 왔을 수 있으면 그 부분은 다음 조각과 합쳐서 봄
                if let lt = buffer.lastIndex(of: "<"), "<think>".hasPrefix(buffer[lt...]) {
                    output += buffer[..<lt]
                    buffer = String(buffer[lt...])
                } else {
                    output += buffer
                    buffer = ""
                }
                return output
            }
        }
    }
}
