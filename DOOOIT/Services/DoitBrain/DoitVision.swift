import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MLXVLM)
import CoreGraphics
import MLX
import MLXLMCommon
#endif

/// 두잇 2의 눈: 받아 둔 두잇 2(Qwen3.5 4B)를 사진을 보는 모델로 잠깐 올려, 문제 그림에 보이는 사실만 읽음
/// - 8GB 기기 + 두잇 2를 받아 둔 경우만. 큰 모델은 한 번에 하나: 읽기 전에 대화 모델을 내리고, 읽은 뒤 1분 안 쓰면 내림
/// - 답·풀이는 시키지 않음: 정해진 줄 모양의 사실만 받아 DoitFigureFacts.parseVision으로 거름 → 학생이 확인 → 규칙형 풀이
@MainActor
@Observable
final class DoitVision {
    static let shared = DoitVision()

    enum Phase: Equatable {
        case idle
        /// 모델을 사진 보기용으로 올리는 중
        case loading
        /// 그림을 읽는 중
        case reading
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    /// 사진 쪽까지 올릴 때 앱이 더 쓸 수 있어야 하는 메모리 (글 모델 3.7GB + 사진 인코더·사진 토큰 여유)
    static let neededMemory: UInt64 = 4_300_000_000

    /// 그림 읽기를 쓸 수 있는지: 모델을 받을 수 있는 실기기, 8GB 이상, 두잇 2를 받아 둠
    var isAvailable: Bool {
        DoitBrain.isSupported && DoitBrain.Model.dooit2.fitsDevice && DoitBrain.shared.isInstalled(.dooit2)
    }

    var isWorking: Bool { phase == .loading || phase == .reading }

    #if canImport(MLXVLM)
    @ObservationIgnored private var container: ModelContainer?
    #endif
    @ObservationIgnored private var idleTask: Task<Void, Never>?
    @ObservationIgnored private var busy = false
    /// 이번 실행에서 연달아 실패한 횟수 (2번이면 그만 씀)
    @ObservationIgnored private var failures = 0

    private init() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        for name in [UIApplication.didReceiveMemoryWarningNotification, UIApplication.didEnterBackgroundNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in DoitVision.shared.unload() }
            }
        }
        #endif
    }

    /// 메모리에서 내림
    func unload() {
        guard !busy else { return }
        idleTask?.cancel()
        #if canImport(MLXVLM)
        if container != nil {
            container = nil
            MLX.Memory.clearCache()
        }
        #endif
        if phase != .idle, !isWorking { phase = .idle }
    }

    #if canImport(MLXVLM)
    /// 그림 한 장 읽기 (못 쓰거나 실패하면 nil → 다른 판독으로)
    func read(_ image: CGImage) async -> DoitFigureFacts.Reading? {
        guard isAvailable, !busy, failures < 2 else { return nil }
        busy = true
        defer { busy = false; scheduleIdleUnload() }
        if container == nil {
            // 대화 모델을 먼저 내려 메모리를 비우고, 그래도 모자라면 읽지 않음 (앱이 꺼지지 않게)
            DoitBrain.shared.sleep()
            MLX.Memory.clearCache()
            guard DoitBrain.availableMemory >= Self.neededMemory else {
                phase = .failed("메모리가 모자라 그림을 읽지 못했어요.")
                return nil
            }
            guard let directory = DoitVisionEngine.localSnapshot(repository: DoitBrain.Model.dooit2.repository) else {
                phase = .idle
                return nil
            }
            phase = .loading
            do {
                container = try await DoitVisionEngine.load(directory: directory)
                MLX.Memory.cacheLimit = 64 * 1024 * 1024
            } catch {
                failures += 1
                phase = .failed("두잇 2가 그림을 읽을 준비를 하지 못했어요.")
                return nil
            }
        }
        guard let container else { return nil }
        phase = .reading
        do {
            let reading = try await DoitVisionEngine.read(container, image: image)
            failures = 0
            phase = .idle
            guard var parsed = DoitFigureFacts.parseVision(reading.text) else { return nil }
            parsed.source = "두잇 2"
            return parsed
        } catch {
            failures += 1
            phase = .failed("두잇 2가 그림을 읽지 못했어요.")
            return nil
        }
    }
    #endif

    /// 1분 동안 안 쓰면 내림 (여러 장을 연달아 읽을 때는 다시 올리지 않게)
    private func scheduleIdleUnload() {
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self.unload()
        }
    }
}
