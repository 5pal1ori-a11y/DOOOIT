import Foundation
import Observation
import UIKit
#if canImport(MLX)
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLMCommon
#endif

/// 정밀 인식 (PaddleOCR-VL 1.6 4비트, 약 0.72GB): 문제 사진(수학·모든 과목 오답노트, 두잇 AI 사진 질문)을 읽는 선택 모델
/// - 모델 메뉴에서 받으면 문제 사진은 이 모델로 먼저 읽고, 받지 않았거나 · 메모리 6GB 미만 기기거나 · 실패·시간 초과면
///   지금처럼 Apple Vision으로 읽음 (단어장 사진은 늘 Vision: 실험에서 Vision이 더 잘 읽음)
/// - 처음 쓸 때 메모리에 올리고, 메모리가 부족하거나 앱이 뒤로 가거나 한동안 안 쓰면 내림
@MainActor
@Observable
final class PaddleOCRService {
    static let shared = PaddleOCRService()

    enum Phase: Equatable {
        case notInstalled
        case downloading(Double)
        /// 받아 둠 (메모리에는 쓸 때 올림)
        case installed
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .notInstalled
    private(set) var isInstalled = false

    var isDownloading: Bool {
        if case .downloading = phase { return true }
        return false
    }

    /// 실기기 + 메모리 6GB 이상 (시뮬레이터·작은 기기에서는 메뉴에 "못 써요")
    static var isSupported: Bool {
        #if canImport(MLX) && !targetEnvironment(simulator)
        return PaddleOCRRouting.deviceCanRun(physicalMemory: ProcessInfo.processInfo.physicalMemory)
        #else
        return false
        #endif
    }

    private let installedKey = "paddleOCR.installed"
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Bool, Never>?
    @ObservationIgnored private var idleTask: Task<Void, Never>?
    /// 이번 실행에서 연달아 실패한 횟수 (3번이면 Vision만)
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var busy = false
    /// 같은 사진을 두 번 읽지 않게 (오답노트 자동 과목: 과목 판단용으로 한 번, 수학이면 수학용으로 또 한 번)
    @ObservationIgnored private weak var lastImage: UIImage?
    @ObservationIgnored private var lastRaw: String?
    #if canImport(MLX)
    @ObservationIgnored private let engine = PaddleOCREngine()
    #endif

    private init() {
        isInstalled = UserDefaults.standard.bool(forKey: installedKey)
        phase = isInstalled ? .installed : .notInstalled
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in PaddleOCRService.shared.unload() }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in PaddleOCRService.shared.unload() }
        }
    }

    // MARK: 받기 · 취소 · 지우기

    /// 받기 (중간에 끊겼으면 받은 데까지 이어서: Hugging Face 캐시의 .incomplete 파일)
    func download() {
        #if canImport(MLX)
        guard Self.isSupported, downloadTask == nil, !isInstalled else { return }
        phase = .downloading(0)
        downloadTask = Task { @MainActor in
            defer { self.downloadTask = nil }
            do {
                let downloader = #hubDownloader()
                let directory = try await downloader.download(
                    id: PaddleOCRConfig.repository, revision: nil, matching: PaddleOCRConfig.downloadPatterns, useLatest: false,
                    progressHandler: { progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor in
                            let service = PaddleOCRService.shared
                            if case .downloading = service.phase { service.phase = .downloading(min(fraction, 0.99)) }
                        }
                    })
                try Task.checkCancellation()
                guard Self.hasModelFiles(directory) else { throw PaddleOCREngine.EngineError.missingFiles }
                self.isInstalled = true
                UserDefaults.standard.set(true, forKey: self.installedKey)
                self.failures = 0
                self.phase = .installed
            } catch {
                self.phase = Task.isCancelled || error is CancellationError ? .notInstalled
                    : .failed("정밀 인식 모델을 받지 못했어요. 와이파이와 저장 공간을 확인해 주세요.")
            }
        }
        #endif
    }

    /// 받기 취소 (받은 부분은 남아 있어 다음에 이어 받음)
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        if !isInstalled { phase = .notInstalled }
    }

    func delete() {
        cancelDownload()
        unload()
        #if canImport(MLX)
        if let repo = Repo.ID(rawValue: PaddleOCRConfig.repository) {
            try? FileManager.default.removeItem(at: HubCache.default.repoDirectory(repo: repo, kind: .model))
        }
        #endif
        isInstalled = false
        UserDefaults.standard.removeObject(forKey: installedKey)
        phase = .notInstalled
        lastRaw = nil
    }

    /// 메모리에서 내림 (받은 파일은 그대로)
    func unload() {
        #if canImport(MLX)
        let engine = self.engine
        engine.requestCancel()
        Task { await engine.unload() }
        #endif
        idleTask?.cancel()
        if phase == .ready || phase == .loading { phase = .installed }
    }

    // MARK: 읽기

    /// 문제 사진을 정밀 인식으로 읽은 앱 글 (nil이면 쓰지 않음 → 호출한 쪽이 Vision으로)
    /// image: 같은 사진을 또 읽을 때 알아보는 용도, cgImage: 바로 세운 사진 (Vision 경로와 같은 것)
    func problemText(_ image: UIImage, cgImage: CGImage, purpose: PaddleOCRRouting.Purpose) async -> String? {
        guard PaddleOCRRouting.shouldUsePaddle(purpose, supported: Self.isSupported, installed: isInstalled,
                                               physicalMemory: ProcessInfo.processInfo.physicalMemory, failures: failures) else { return nil }
        guard let raw = await rawText(image, cgImage: cgImage) else { return nil }
        let text = purpose == .subjectProblem ? PaddleOCRText.subjectText(raw) : PaddleOCRText.mathText(raw)
        return PaddleOCRText.isUsable(text) ? text : nil
    }

    private func rawText(_ image: UIImage, cgImage: CGImage) async -> String? {
        if let lastImage, lastImage === image, let lastRaw { return lastRaw }
        #if canImport(MLX)
        guard !busy, await prepare() else { return nil }
        busy = true
        defer { busy = false; scheduleIdleUnload() }
        let engine = self.engine
        do {
            let reading = try await engine.read(cgImage)
            failures = 0
            lastImage = image
            lastRaw = reading.text
            return reading.text
        } catch {
            failures += 1
            return nil
        }
        #else
        return nil
        #endif
    }

    /// 메모리에 올림 (처음 쓸 때). 파일이 없어졌으면 (기기가 캐시를 비움) 받지 않은 상태로
    private func prepare() async -> Bool {
        #if canImport(MLX)
        if phase == .ready { return true }
        if let loadTask { return await loadTask.value }
        guard let directory = Self.localSnapshot() else {
            isInstalled = false
            UserDefaults.standard.removeObject(forKey: installedKey)
            phase = .notInstalled
            return false
        }
        // 6GB 기기에서는 대화 모델(DOOOIT 1·2)을 잠시 내려 메모리를 비움
        if ProcessInfo.processInfo.physicalMemory < 7_500_000_000 { DoitBrain.shared.sleep() }
        phase = .loading
        let engine = self.engine
        let task = Task { @MainActor () -> Bool in
            defer { self.loadTask = nil }
            do {
                try await engine.load(from: directory)
                self.phase = .ready
                return true
            } catch {
                self.failures += 1
                self.phase = .installed
                return false
            }
        }
        loadTask = task
        return await task.value
        #else
        return false
        #endif
    }

    /// 2분 동안 안 쓰면 메모리에서 내림
    private func scheduleIdleUnload() {
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120 * 1_000_000_000)
            guard !Task.isCancelled, !self.busy else { return }
            self.unload()
        }
    }

    // MARK: 파일 위치 (Hugging Face 캐시: DOOOIT 1·2와 같은 곳)

    #if canImport(MLX)
    /// 받아 둔 스냅숏 폴더 (인터넷 없이): models--…/refs/main → snapshots/<커밋>
    static func localSnapshot() -> URL? {
        guard let repo = Repo.ID(rawValue: PaddleOCRConfig.repository) else { return nil }
        let base = HubCache.default.repoDirectory(repo: repo, kind: .model)
        let snapshots = base.appendingPathComponent("snapshots")
        if let commit = try? String(contentsOf: base.appendingPathComponent("refs/main"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !commit.isEmpty {
            let folder = snapshots.appendingPathComponent(commit)
            if hasModelFiles(folder) { return folder }
        }
        let folders = (try? FileManager.default.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil)) ?? []
        return folders.first(where: hasModelFiles)
    }
    #endif

    static func hasModelFiles(_ folder: URL) -> Bool {
        let fm = FileManager.default
        return ["config.json", "tokenizer.json", "model.safetensors"].allSatisfy {
            fm.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }
}
