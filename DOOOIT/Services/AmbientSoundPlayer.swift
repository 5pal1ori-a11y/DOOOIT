import AVFoundation
import Observation

/// 집중 사운드: 소리 파일 없이 기기에서 실시간으로 만들어서 재생 (빗소리, 파도, 화이트·핑크·브라운 노이즈)
@MainActor
@Observable
final class AmbientSoundPlayer {
    static let shared = AmbientSoundPlayer()

    enum Kind: Int, CaseIterable, Identifiable {
        case rain, waves, white, pink, brown

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .rain: return "빗소리"
            case .waves: return "파도"
            case .white: return "화이트 노이즈"
            case .pink: return "핑크 노이즈"
            case .brown: return "브라운 노이즈"
            }
        }

        var subtitle: String {
            switch self {
            case .rain: return "창밖에 비 내리는 소리"
            case .waves: return "천천히 밀려오는 파도"
            case .white: return "주변 소음을 가려줘요"
            case .pink: return "부드러운 빗줄기 느낌"
            case .brown: return "낮고 깊은 웅웅 소리"
            }
        }

        var symbol: String {
            switch self {
            case .rain: return "cloud.rain.fill"
            case .waves: return "water.waves"
            case .white: return "waveform"
            case .pink: return "waveform.path"
            case .brown: return "waveform.badge.minus"
            }
        }
    }

    private(set) var current: Kind?
    var volume: Float = 0.6 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }
    var isPlaying: Bool { current != nil }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let state = NoiseState()
    @ObservationIgnored private var source: AVAudioSourceNode?

    func play(_ kind: Kind) {
        state.kind = kind.rawValue
        current = kind
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if source == nil { setUpGraph() }
            engine.mainMixerNode.outputVolume = volume
            if !engine.isRunning { try engine.start() }
        } catch {
            print("집중 사운드 재생 실패: \(error)")
            current = nil
        }
    }

    func toggle(_ kind: Kind) {
        current == kind ? stop() : play(kind)
    }

    func stop() {
        current = nil
        engine.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func setUpGraph() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = sampleRate > 0 ? sampleRate : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        state.sampleRate = Float(rate)
        let node = Self.makeSource(format: format, state: state)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
    }
}

extension AmbientSoundPlayer {
    /// 오디오 스레드에서 불리는 콜백이라 메인 액터 밖에서 만듦
    nonisolated fileprivate static func makeSource(format: AVAudioFormat, state: NoiseState) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = state.next()
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
    }
}

/// 실시간 오디오 스레드에서 쓰는 소리 생성기 (메모리 할당 없음)
private final class NoiseState: @unchecked Sendable {
    var kind = 0
    var sampleRate: Float = 44_100

    private var seed: UInt32 = 0x1234_5678
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var brown: Float = 0
    private var drop: Float = 0
    private var dropTone: Float = 0
    private var phase: Float = 0
    private var low: Float = 0

    /// -1...1 사이 난수 (xorshift)
    private func white() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    private func pink(_ w: Float) -> Float {
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
        b6 = w * 0.115926
        return out * 0.11
    }

    private func brownNoise(_ w: Float) -> Float {
        brown = (brown + 0.02 * w) / 1.02
        return brown * 3.5
    }

    func next() -> Float {
        let w = white()
        switch kind {
        case 0: // 빗소리: 핑크 노이즈 + 무작위 빗방울
            let base = pink(w) * 0.55
            if drop < 0.002, white() > 0.9985 {
                drop = 0.25 + 0.35 * abs(white())
            }
            drop *= 0.9965
            dropTone = 0.6 * dropTone + 0.4 * w
            low = 0.97 * low + 0.03 * base
            return (base - low * 0.6) + dropTone * drop
        case 1: // 파도: 브라운 노이즈 + 8초 주기로 커졌다 작아짐
            phase += 1 / (sampleRate * 8)
            if phase > 1 { phase -= 1 }
            let swell = 0.5 + 0.5 * sin(phase * 2 * .pi)
            let envelope = 0.15 + 0.85 * swell * swell
            return (brownNoise(w) * 0.8 + pink(w) * 0.25 * swell) * envelope
        case 2:
            return w * 0.18
        case 3:
            return pink(w)
        default:
            return brownNoise(w) * 0.9
        }
    }
}
