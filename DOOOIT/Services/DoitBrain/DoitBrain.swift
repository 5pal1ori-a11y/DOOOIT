import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MLXLLM)
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
#endif

/// 두잇 AI 두뇌: 휴대폰 안에서 돌아가는 오픈소스 언어 모델 (Qwen3, Apache-2.0)
/// - 처음 한 번만 내려받으면 인터넷 없이도 돌아가요. 질문·대화 내용은 기기 밖으로 나가지 않아요.
/// - 규칙형 엔진이 정확하게 할 수 있는 일(앱 기능, 수학 풀이, 계산)은 그대로 두고,
///   설명·대화·학습 자료 만들기처럼 "자기 말로" 해야 하는 일을 맡아요.
@MainActor
@Observable
final class DoitBrain {
    static let shared = DoitBrain()

    enum Size: String, CaseIterable, Identifiable {
        /// Qwen3 1.7B (약 1GB) — 기본
        case standard
        /// Qwen3 0.6B (약 0.4GB) — 메모리가 적은 기기
        case light

        var id: String { rawValue }
        var title: String { self == .standard ? "표준 두뇌" : "가벼운 두뇌" }
        var detail: String { self == .standard ? "더 똑똑해요 · 약 1GB" : "더 빠르고 작아요 · 약 0.4GB" }
        var repository: String { self == .standard ? "mlx-community/Qwen3-1.7B-4bit" : "mlx-community/Qwen3-0.6B-4bit" }

        /// 기기 메모리에 맞는 크기 (6GB 미만이면 가벼운 두뇌)
        static var recommended: Size {
            ProcessInfo.processInfo.physicalMemory >= 5_500_000_000 ? .standard : .light
        }
    }

    enum Phase: Equatable {
        /// 아직 내려받지 않음
        case notInstalled
        /// 내려받는 중 (0~1)
        case downloading(Double)
        /// 메모리에 올리는 중
        case loading
        /// 바로 답할 수 있음
        case ready
        /// 내려받았지만 메모리에서 내려 둠 (다음에 쓸 때 다시 올림)
        case sleeping
        case failed(String)
    }

    enum BrainError: LocalizedError {
        case notReady, busy, unsupported
        var errorDescription: String? {
            switch self {
            case .notReady: return "두잇 AI 두뇌가 아직 준비되지 않았어요."
            case .busy: return "다른 답을 만드는 중이에요."
            case .unsupported: return "이 기기에서는 두뇌를 쓸 수 없어요."
            }
        }
    }

    private(set) var phase: Phase = .notInstalled
    private(set) var size: Size

    private let installedKey = "doitBrain.installed"
    private let sizeKey = "doitBrain.size"
    private let enabledKey = "doitBrain.enabled"

    /// 사용자가 두뇌를 켜 두었는지 (꺼 두면 규칙형 엔진만 씀)
    var isEnabled: Bool {
        get { access(keyPath: \.isEnabled); return UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { withMutation(keyPath: \.isEnabled) { UserDefaults.standard.set(newValue, forKey: enabledKey) } }
    }

    /// 내려받아 두었는지
    var isInstalled: Bool { UserDefaults.standard.string(forKey: installedKey) != nil }

    /// 질문에 쓸 수 있는지 (내려받았고 켜 둠 — 메모리에 없으면 쓸 때 올림)
    var isAvailable: Bool {
        guard Self.isSupported, isEnabled, isInstalled else { return false }
        switch phase {
        case .ready, .sleeping, .loading: return true
        default: return false
        }
    }

    var isBusy: Bool { generating }

    /// 휴대폰 실기기에서만 (시뮬레이터·리눅스 테스트에서는 꺼짐)
    static var isSupported: Bool {
        #if canImport(MLXLLM) && !targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    @ObservationIgnored private var generating = false
    @ObservationIgnored private var loadTask: Task<Bool, Never>?
    #if canImport(MLXLLM)
    @ObservationIgnored private var container: ModelContainer?
    #endif

    private init() {
        size = Size(rawValue: UserDefaults.standard.string(forKey: sizeKey) ?? "") ?? Size.recommended
        if isInstalled { phase = .sleeping }
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DoitBrain.shared.sleep() }
        }
        #endif
    }

    // MARK: 설치·불러오기

    /// 내려받고 메모리에 올림 (이미 받았으면 바로 올림)
    @discardableResult
    func install(_ size: Size? = nil) async -> Bool {
        if let size, size != self.size {
            remove()
            self.size = size
            UserDefaults.standard.set(size.rawValue, forKey: sizeKey)
        }
        isEnabled = true
        return await load(downloading: true)
    }

    /// 쓸 준비 (메모리에 없으면 올림). 내려받지 않았으면 false
    @discardableResult
    func prepare() async -> Bool {
        guard Self.isSupported, isEnabled, isInstalled else { return false }
        if phase == .ready { return true }
        return await load(downloading: false)
    }

    private func load(downloading: Bool) async -> Bool {
        // 받지 않은 두뇌는 사용자가 직접 "내려받기"를 눌렀을 때만 받음 (데이터 요금 방지)
        guard downloading || isInstalled else { return false }
        guard Self.isSupported else { phase = .failed(BrainError.unsupported.localizedDescription); return false }
        if let loadTask { return await loadTask.value }
        let task = Task { @MainActor () -> Bool in
            defer { self.loadTask = nil }
            #if canImport(MLXLLM)
            let configuration = self.size == .standard ? LLMRegistry.qwen3_1_7b_4bit : LLMRegistry.qwen3_0_6b_4bit
            self.phase = self.isInstalled ? .loading : .downloading(0)
            do {
                let loaded = try await #huggingFaceLoadModelContainer(configuration: configuration, progressHandler: { progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor in
                        let brain = DoitBrain.shared
                        if case .downloading = brain.phase, fraction < 1 { brain.phase = .downloading(fraction) }
                        else if fraction >= 1 { brain.phase = .loading }
                    }
                })
                self.container = loaded
                UserDefaults.standard.set(self.size.repository, forKey: self.installedKey)
                self.phase = .ready
                return true
            } catch {
                self.container = nil
                self.phase = self.isInstalled ? .failed("두뇌를 불러오지 못했어요. 다시 시도해 주세요.") : .failed("두뇌를 내려받지 못했어요. 와이파이 연결과 저장 공간을 확인해 주세요.")
                return false
            }
            #else
            return false
            #endif
        }
        loadTask = task
        return await task.value
    }

    /// 메모리에서 내림 (기기 메모리가 부족할 때)
    func sleep() {
        guard !generating else { return }
        #if canImport(MLXLLM)
        container = nil
        #endif
        if phase == .ready { phase = .sleeping }
    }

    /// 내려받은 두뇌 지우기
    func remove() {
        #if canImport(MLXLLM)
        container = nil
        for size in Size.allCases {
            if let repo = Repo.ID(rawValue: size.repository) {
                try? FileManager.default.removeItem(at: HubCache.default.repoDirectory(repo: repo, kind: .model))
            }
        }
        #endif
        UserDefaults.standard.removeObject(forKey: installedKey)
        phase = .notInstalled
    }

    // MARK: 답 만들기

    /// 글을 조금씩 만들어 보냄 (생각 과정 <think>는 걸러서)
    func stream(system: String, prompt: String, maxTokens: Int = 700, temperature: Float = 0.6) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                guard !self.generating else { continuation.finish(throwing: BrainError.busy); return }
                guard await self.prepare() else { continuation.finish(throwing: BrainError.notReady); return }
                self.generating = true
                defer { self.generating = false }
                #if canImport(MLXLLM)
                guard let container = self.container else { continuation.finish(throwing: BrainError.notReady); return }
                let session = ChatSession(
                    container,
                    instructions: system,
                    generateParameters: GenerateParameters(maxTokens: maxTokens, temperature: temperature, topP: 0.9, repetitionPenalty: 1.1),
                    additionalContext: ["enable_thinking": false]
                )
                var filter = ThinkFilter()
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
    func complete(system: String, prompt: String, maxTokens: Int = 700, temperature: Float = 0.5) async throws -> String {
        var text = ""
        for try await chunk in stream(system: system, prompt: prompt, maxTokens: maxTokens, temperature: temperature) { text += chunk }
        return text
    }
}

/// 모델이 내보내는 <think>…</think> (생각 과정)를 걸러냄 — 조각으로 나뉘어 와도 처리
struct ThinkFilter {
    private var buffer = ""
    private var inThink = false

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
