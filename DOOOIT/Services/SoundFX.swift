import AVFoundation

/// 효과음: 소리 파일 없이 기기에서 바로 만들어 재생 (맞았을 때 · 틀렸을 때 · 끝냈을 때)
/// - 무음 스위치를 따르고, 다른 앱 음악·집중 사운드를 끊지 않아요
/// - 계정 → 앱 → "효과음"에서 끌 수 있어요
@MainActor
final class SoundFX {
    static let shared = SoundFX()

    enum Kind: CaseIterable { case correct, wrong, complete }

    @ObservationIgnored private var cache: [Kind: Data] = [:]
    private var players: [AVAudioPlayer] = []

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.soundEffects) as? Bool ?? true
    }

    func play(_ kind: Kind) {
        guard Self.isEnabled else { return }
        let session = AVAudioSession.sharedInstance()
        // 집중 사운드(재생 모드)가 켜져 있으면 그 설정을 건드리지 않음
        if session.category != .playback {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        let data = cache[kind] ?? SoundFXSynth.wav(for: kind)
        cache[kind] = data
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.7
        player.prepareToPlay()
        player.play()
        players.removeAll { !$0.isPlaying }
        players.append(player)
    }
}

/// 짧은 소리 만들기 (사인파 + 배음, 끝으로 갈수록 작아지는 종소리)
enum SoundFXSynth {
    private struct Note { let hz: Double; let start: Double; let length: Double; let gain: Double }

    private static func notes(for kind: SoundFX.Kind) -> [Note] {
        switch kind {
        case .correct:   // 띠-링: 밝게 올라가는 두 음
            return [Note(hz: 880, start: 0, length: 0.14, gain: 0.8), Note(hz: 1318.5, start: 0.09, length: 0.34, gain: 0.9)]
        case .wrong:     // 뚜-웅: 낮게 내려가는 두 음
            return [Note(hz: 311, start: 0, length: 0.16, gain: 0.7), Note(hz: 233, start: 0.12, length: 0.3, gain: 0.7)]
        case .complete:  // 도-미-솔-도 팡파르
            return [Note(hz: 523.3, start: 0, length: 0.16, gain: 0.7), Note(hz: 659.3, start: 0.11, length: 0.16, gain: 0.7),
                    Note(hz: 784, start: 0.22, length: 0.18, gain: 0.75), Note(hz: 1046.5, start: 0.34, length: 0.55, gain: 0.9)]
        }
    }

    static let sampleRate = 44100

    /// 16비트 모노 WAV
    static func wav(for kind: SoundFX.Kind) -> Data {
        let list = notes(for: kind)
        let total = Int((list.map { $0.start + $0.length }.max() ?? 0.2) * Double(sampleRate)) + 200
        var mix = [Double](repeating: 0, count: total)
        for note in list {
            let begin = Int(note.start * Double(sampleRate))
            let count = Int(note.length * Double(sampleRate))
            for i in 0..<count where begin + i < total {
                let t = Double(i) / Double(sampleRate)
                let attack = min(1, t / 0.004)                       // 딱 소리 없이 시작
                let decay = exp(-t * (5.5 / max(note.length, 0.1)))  // 종처럼 줄어듦
                let phase = 2 * Double.pi * note.hz * t
                let wave = sin(phase) + 0.3 * sin(2 * phase) + 0.1 * sin(3 * phase)
                mix[begin + i] += wave * attack * decay * note.gain * 0.45
            }
        }
        var pcm = Data(capacity: total * 2)
        for v in mix {
            let s = Int16(max(-1, min(1, v)) * 30000)
            pcm.append(UInt8(truncatingIfNeeded: s)); pcm.append(UInt8(truncatingIfNeeded: s >> 8))
        }
        func le32(_ v: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) } }
        func le16(_ v: Int) -> [UInt8] { (0..<2).map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) } }
        var out = Data("RIFF".utf8)
        out.append(contentsOf: le32(36 + pcm.count)); out.append(Data("WAVEfmt ".utf8))
        out.append(contentsOf: le32(16)); out.append(contentsOf: le16(1)); out.append(contentsOf: le16(1))
        out.append(contentsOf: le32(sampleRate)); out.append(contentsOf: le32(sampleRate * 2))
        out.append(contentsOf: le16(2)); out.append(contentsOf: le16(16))
        out.append(Data("data".utf8)); out.append(contentsOf: le32(pcm.count)); out.append(pcm)
        return out
    }
}
