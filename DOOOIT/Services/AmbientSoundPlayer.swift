import AVFoundation
import Observation

/// 집중 사운드 섞기: 소리 파일 없이 기기에서 실시간으로 만들어서 여러 소리를 함께 재생
/// (빗소리 · 파도 · 카페 · 도서관 · 모닥불 · 숲 · 시계 · 화이트·핑크·브라운 노이즈)
/// - 소리마다 음량 + 전체 음량, 마지막으로 쓴 섞기를 기억 (켜 둔 소리는 다음에 "재생"하면 그대로)
/// - 백그라운드 오디오(Info.plist UIBackgroundModes audio)로 화면을 꺼도 계속 나요
@MainActor
@Observable
final class AmbientSoundPlayer {
    static let shared = AmbientSoundPlayer()

    /// 지금 섞은 상태 (켠 소리 · 음량)
    private(set) var mix: SoundMix
    /// 실제로 소리가 나는 중인지
    private(set) var isPlaying = false

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var synth: AmbientSynth?
    @ObservationIgnored private var source: AVAudioSourceNode?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private init() {
        mix = SoundMix.decode(UserDefaults.standard.data(forKey: SoundMix.storageKey))
    }

    /// 타이머 아이콘에 보여 줄 소리 (켠 것 중 첫째)
    var leadKind: SoundKind? { isPlaying ? mix.activeKinds.first : nil }

    // MARK: 섞기

    func isOn(_ kind: SoundKind) -> Bool { isPlaying && mix.isOn(kind) }

    /// 소리 하나 켜기 · 끄기 (켜면 바로 재생, 모두 끄면 멈춤)
    func toggle(_ kind: SoundKind) {
        if !isPlaying && mix.isOn(kind) {
            // 멈춘 상태에서 켜져 있던 소리를 누르면: 그 소리로 다시 시작
            start()
            return
        }
        mix.toggle(kind)
        save()
        if mix.isEmpty { stop() } else { start() }
    }

    func setLevel(_ kind: SoundKind, _ value: Float) {
        mix.setLevel(kind, value)
        synth?.set(kind, isPlaying ? mix.gain(kind) : 0)
        save()
    }

    var master: Float {
        get { mix.master }
        set {
            mix.setMaster(newValue)
            if isPlaying { synth?.apply(mix) }
            save()
        }
    }

    /// 지난번에 섞은 소리 그대로 다시 재생
    func resume() {
        guard !mix.isEmpty else { return }
        start()
    }

    /// 모두 멈춤 (섞은 상태는 기억)
    func stop() {
        isPlaying = false
        synth?.apply(SoundMix())
        // 소리가 부드럽게 줄어든 뒤 엔진을 쉼
        Task { [engine] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !AmbientSoundPlayer.shared.isPlaying else { return }
            engine.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    /// 켠 소리를 모두 끄고 멈춤
    func clear() {
        mix.turnOffAll()
        save()
        stop()
    }

    // MARK: 재생

    private func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if source == nil { setUpGraph() }
            synth?.apply(mix)
            engine.mainMixerNode.outputVolume = 1
            if !engine.isRunning { try engine.start() }
            isPlaying = true
        } catch {
            print("집중 사운드 재생 실패: \(error)")
            isPlaying = false
        }
    }

    private func setUpGraph() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = sampleRate > 0 ? sampleRate : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let synth = AmbientSynth(sampleRate: Float(rate))
        let node = Self.makeSource(format: format, synth: synth)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.synth = synth
        source = node
    }

    /// 슬라이더를 움직이는 동안 너무 자주 쓰지 않게 조금 모아서 저장
    private func save() {
        saveTask?.cancel()
        saveTask = Task { [mix] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            UserDefaults.standard.set(mix.encoded(), forKey: SoundMix.storageKey)
        }
    }
}

extension AmbientSoundPlayer {
    /// 오디오 스레드에서 불리는 콜백이라 메인 액터 밖에서 만듦
    nonisolated fileprivate static func makeSource(format: AVAudioFormat, synth: AmbientSynth) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = synth.next()
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
    }

    #if DEBUG
    /// 화면 사진용: 소리를 내지 않고 섞은 모습만 (저장하지 않음)
    func showDemo(_ kinds: [SoundKind], levels: [SoundKind: Float]) {
        var demo = SoundMix()
        for kind in kinds { demo.toggle(kind) }
        for (kind, value) in levels { demo.setLevel(kind, value) }
        mix = demo
        isPlaying = true
    }
    #endif
}
