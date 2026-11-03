import Foundation

/// 집중 사운드 종류 (소리 파일 없이 기기에서 바로 만드는 소리)
enum SoundKind: String, CaseIterable, Identifiable, Codable {
    case rain, waves, cafe, library, fire, forest, clock, white, pink, brown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "빗소리"
        case .waves: return "파도"
        case .cafe: return "카페"
        case .library: return "도서관"
        case .fire: return "모닥불"
        case .forest: return "숲"
        case .clock: return "시계"
        case .white: return "화이트"
        case .pink: return "핑크"
        case .brown: return "브라운"
        }
    }

    var symbol: String {
        switch self {
        case .rain: return "cloud.rain"
        case .waves: return "water.waves"
        case .cafe: return "cup.and.saucer"
        case .library: return "books.vertical"
        case .fire: return "flame"
        case .forest: return "bird"
        case .clock: return "clock"
        case .white: return "waveform"
        case .pink: return "waveform.path"
        case .brown: return "waveform.path.ecg"
        }
    }

    /// 칩 색 (#RRGGBB)
    var colorHex: String {
        switch self {
        case .rain: return "#4FA3F7"
        case .waves: return "#38BDF8"
        case .cafe: return "#C08457"
        case .library: return "#7C83F7"
        case .fire: return "#FF8A5C"
        case .forest: return "#2FBF8F"
        case .clock: return "#F2B233"
        case .white: return "#94A3B8"
        case .pink: return "#F2709C"
        case .brown: return "#A16207"
        }
    }
}

/// 섞은 소리 상태: 켠 소리 · 소리마다 음량 · 전체 음량 (마지막으로 쓴 섞기를 기억)
struct SoundMix: Codable, Equatable {
    /// 소리마다 음량 (끄더라도 기억)
    var levels: [String: Float] = [:]
    /// 켠 소리 (켠 순서대로)
    var on: [String] = []
    var master: Float = 0.7

    static let defaultLevel: Float = 0.6
    /// 한 번에 켤 수 있는 소리 수 (넘으면 가장 먼저 켠 것을 끔)
    static let maxOn = 5
    static let storageKey = "sound.mix"

    func level(_ kind: SoundKind) -> Float { levels[kind.rawValue] ?? Self.defaultLevel }
    func isOn(_ kind: SoundKind) -> Bool { on.contains(kind.rawValue) }
    var isEmpty: Bool { on.isEmpty }
    var activeKinds: [SoundKind] { on.compactMap(SoundKind.init(rawValue:)) }

    /// 실제로 나는 크기 (켠 소리 음량 × 전체 음량)
    func gain(_ kind: SoundKind) -> Float { isOn(kind) ? level(kind) * master : 0 }

    mutating func toggle(_ kind: SoundKind) {
        if let index = on.firstIndex(of: kind.rawValue) {
            on.remove(at: index)
        } else {
            on.append(kind.rawValue)
            if on.count > Self.maxOn { on.removeFirst(on.count - Self.maxOn) }
            // 음량을 0으로 내려 둔 소리를 다시 켜면 들리게
            if level(kind) < 0.05 { levels[kind.rawValue] = Self.defaultLevel }
        }
    }

    mutating func setLevel(_ kind: SoundKind, _ value: Float) {
        levels[kind.rawValue] = min(max(value, 0), 1)
    }

    mutating func setMaster(_ value: Float) { master = min(max(value, 0), 1) }

    mutating func turnOffAll() { on.removeAll() }

    // MARK: 저장 (모르는 이름은 버림)

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    static func decode(_ data: Data?) -> SoundMix {
        guard let data, var mix = try? JSONDecoder().decode(SoundMix.self, from: data) else { return SoundMix() }
        mix.on = mix.on.filter { SoundKind(rawValue: $0) != nil }
        mix.master = min(max(mix.master, 0), 1)
        return mix
    }
}

/// 실시간 소리 만들기 (오디오 스레드에서 한 샘플씩: 메모리 할당 없음, 켠 소리만 계산)
/// 음량이 바뀌면 부드럽게 따라가서 딸깍 소리가 나지 않아요.
final class AmbientSynth: @unchecked Sendable {
    let sampleRate: Float
    /// allCases는 부를 때마다 새 배열을 만들어서, 오디오 스레드에서는 미리 만든 목록을 씀
    private let kinds: [SoundKind] = SoundKind.allCases
    private let count = SoundKind.allCases.count
    private let target: UnsafeMutablePointer<Float>
    private let gain: UnsafeMutablePointer<Float>
    private let smooth: Float

    init(sampleRate: Float = 44_100) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 44_100
        target = .allocate(capacity: count)
        target.initialize(repeating: 0, count: count)
        gain = .allocate(capacity: count)
        gain.initialize(repeating: 0, count: count)
        smooth = 1 - expf(-1 / (0.06 * self.sampleRate))
        let r = self.sampleRate
        cafeVoices = [Biquad.bandpass(380, q: 1.6, sr: r), Biquad.bandpass(620, q: 1.8, sr: r),
                      Biquad.bandpass(950, q: 2.0, sr: r), Biquad.bandpass(1350, q: 2.2, sr: r)]
        birdWait = 0.4 * r
        clockLeft = 0.1 * r
    }

    deinit {
        target.deallocate()
        gain.deallocate()
    }

    func set(_ kind: SoundKind, _ value: Float) {
        guard let index = kinds.firstIndex(of: kind) else { return }
        target[index] = min(max(value, 0), 1)
    }

    func apply(_ mix: SoundMix) {
        for kind in SoundKind.allCases { set(kind, mix.gain(kind)) }
    }

    /// 다음 한 샘플 (-1...1)
    func next() -> Float {
        var out: Float = 0
        for i in 0..<count {
            let t = target[i]
            var g = gain[i]
            if t == 0 && g < 0.00002 { gain[i] = 0; continue }
            g += (t - g) * smooth
            gain[i] = g
            out += g * sample(i)
        }
        return Self.limit(out)
    }

    /// 여러 소리를 섞어도 찢어지지 않게 (작은 소리는 그대로, 큰 소리만 부드럽게 누름)
    static func limit(_ x: Float) -> Float {
        let a = abs(x)
        guard a > 0.6 else { return x }
        let squeezed = 0.6 + 0.4 * tanhf((a - 0.6) / 0.4)
        return x < 0 ? -squeezed : squeezed
    }

    private func sample(_ index: Int) -> Float {
        switch kinds[index] {
        case .rain: return rain()
        case .waves: return waves()
        case .cafe: return cafe()
        case .library: return library()
        case .fire: return fire()
        case .forest: return forest()
        case .clock: return clock()
        case .white: return white() * 0.18
        case .pink: return pinkNoise.next(white())
        case .brown: return brownNoise.next(white()) * 0.9
        }
    }

    // MARK: 난수

    private var seed: UInt32 = 0x1234_5678
    /// -1...1 (xorshift)
    private func white() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }
    /// 0...1
    private func unit() -> Float { (white() + 1) * 0.5 }
    private func chance(perSecond rate: Float) -> Bool { unit() < rate / sampleRate }

    // MARK: 빗소리 · 파도 (예전 소리 그대로)

    private var rainPink = Pink()
    private var drop: Float = 0, dropTone: Float = 0, rainLow: Float = 0
    private func rain() -> Float {
        let w = white()
        let base = rainPink.next(w) * 0.55
        if drop < 0.002, white() > 0.9985 { drop = 0.25 + 0.35 * abs(white()) }
        drop *= 0.9965
        dropTone = 0.6 * dropTone + 0.4 * w
        rainLow = 0.97 * rainLow + 0.03 * base
        return (base - rainLow * 0.6) + dropTone * drop
    }

    private var wavePink = Pink(), waveBrown = Brown()
    private var wavePhase: Float = 0
    private func waves() -> Float {
        let w = white()
        wavePhase += 1 / (sampleRate * 8)
        if wavePhase > 1 { wavePhase -= 1 }
        let swell = 0.5 + 0.5 * sinf(wavePhase * 2 * .pi)
        let envelope = 0.15 + 0.85 * swell * swell
        return (waveBrown.next(w) * 0.8 + wavePink.next(w) * 0.25 * swell) * envelope
    }

    private var pinkNoise = Pink(), brownNoise = Brown()

    // MARK: 카페: 여러 사람이 웅성거리는 소리 (말소리 대역 잡음 + 음절처럼 커졌다 작아짐) + 가끔 잔 소리

    private var cafeVoices: [Biquad]
    private var cafeEnv: (Float, Float, Float, Float) = (0, 0, 0, 0)
    private var cafeAmp: (Float, Float, Float, Float) = (0, 0, 0, 0)
    private var cafeLeft: (Float, Float, Float, Float) = (0, 0, 0, 0)
    private var cafeRoom = Brown()
    private var cafeSoft = OnePole()
    private var clink: Float = 0, clinkPhase: Float = 0, clinkFreq: Float = 3000

    private func syllable(_ left: inout Float, _ amp: inout Float) {
        left -= 1
        if left <= 0 {
            // 80~260ms 음절, 가끔 쉼
            left = (0.08 + 0.18 * unit()) * sampleRate
            amp = unit() < 0.25 ? 0 : 0.35 + 0.65 * unit()
        }
    }

    private func cafe() -> Float {
        syllable(&cafeLeft.0, &cafeAmp.0); syllable(&cafeLeft.1, &cafeAmp.1)
        syllable(&cafeLeft.2, &cafeAmp.2); syllable(&cafeLeft.3, &cafeAmp.3)
        let k: Float = 1 - expf(-1 / (0.025 * sampleRate))
        cafeEnv.0 += (cafeAmp.0 - cafeEnv.0) * k
        cafeEnv.1 += (cafeAmp.1 - cafeEnv.1) * k
        cafeEnv.2 += (cafeAmp.2 - cafeEnv.2) * k
        cafeEnv.3 += (cafeAmp.3 - cafeEnv.3) * k
        var voices = cafeVoices[0].process(white()) * cafeEnv.0
        voices += cafeVoices[1].process(white()) * cafeEnv.1
        voices += cafeVoices[2].process(white()) * cafeEnv.2 * 0.8
        voices += cafeVoices[3].process(white()) * cafeEnv.3 * 0.6
        let murmur = cafeSoft.lowpass(voices, 0.25) * 1.1
        let room = cafeRoom.next(white()) * 0.25
        // 잔·숟가락 소리 (평균 6초에 한 번)
        if clink < 0.001, chance(perSecond: 0.17) {
            clink = 0.12 + 0.1 * unit()
            clinkFreq = 2600 + 1800 * unit()
            clinkPhase = 0
        }
        var cup: Float = 0
        if clink > 0.0005 {
            clinkPhase += clinkFreq / sampleRate
            if clinkPhase > 1 { clinkPhase -= 1 }
            cup = clink * (sinf(clinkPhase * 2 * .pi) + 0.4 * sinf(clinkPhase * 2 * .pi * 2.76))
            clink *= expf(-1 / (0.09 * sampleRate))
        }
        return murmur + room + cup
    }

    // MARK: 도서관: 조용한 실내 공기 소리 + 가끔 책장 넘기는 소리

    private var roomBrown = Brown(), roomLow = OnePole(), roomPink = Pink()
    private var page: Float = 0, pageRise: Float = 0, pageHigh = OnePole()
    private func library() -> Float {
        let air = roomLow.lowpass(roomBrown.next(white()), 0.08) * 0.9 + roomPink.next(white()) * 0.04
        if page < 0.001, pageRise < 0.001, chance(perSecond: 0.09) { pageRise = 1 }
        if pageRise > 0.001 {
            page += (0.5 - page) * 0.002
            pageRise *= expf(-1 / (0.04 * sampleRate))
        } else {
            page *= expf(-1 / (0.18 * sampleRate))
        }
        let n = white()
        let rustle = (n - pageHigh.lowpass(n, 0.15)) * page * (0.6 + 0.4 * unit())
        return air + rustle * 0.5
    }

    // MARK: 모닥불: 낮게 타오르는 소리 + 타닥타닥 튀는 소리

    private var fireBrown = Brown(), fireLow = OnePole(), fireFlicker: Float = 0.6, fireFlickerTarget: Float = 0.6
    private var crackle: Float = 0, pop: Float = 0, popTone = OnePole(), crackleHigh = OnePole()
    private func fire() -> Float {
        if chance(perSecond: 3) { fireFlickerTarget = 0.4 + 0.6 * unit() }
        fireFlicker += (fireFlickerTarget - fireFlicker) * 0.0004
        let roar = fireLow.lowpass(fireBrown.next(white()), 0.05) * 1.6 * fireFlicker
        if chance(perSecond: 14) {
            let a = unit()
            crackle = max(crackle, 0.15 + 0.6 * a * a * a)
        }
        if chance(perSecond: 0.8) { pop = 0.5 + 0.4 * unit() }
        let n = white()
        let sparkle = (n - crackleHigh.lowpass(n, 0.3)) * crackle
        crackle *= expf(-1 / (0.0028 * sampleRate))
        let thump = popTone.lowpass(white(), 0.2) * pop * 1.4
        pop *= expf(-1 / (0.009 * sampleRate))
        return roar + sparkle + thump
    }

    // MARK: 숲: 잔잔한 바람 + 새가 짹짹

    private var windPink = Pink(), windLow = OnePole(), windPhase: Float = 0
    private var birdWait: Float, birdChirpsLeft = 0, birdT: Float = 0, birdDur: Float = 0, birdGap: Float = 0
    private var birdF0: Float = 3200, birdSweep: Float = 1000, birdPhase: Float = 0, birdVol: Float = 0.2
    private func forest() -> Float {
        windPhase += 1 / (sampleRate * 11)
        if windPhase > 1 { windPhase -= 1 }
        let swell = 0.55 + 0.45 * sinf(windPhase * 2 * .pi)
        let wind = windLow.lowpass(windPink.next(white()), 0.03) * 1.3 * swell
        var bird: Float = 0
        if birdChirpsLeft == 0 {
            birdWait -= 1
            if birdWait <= 0 {
                // 새 한 마리가 2~6번 지저귐
                birdChirpsLeft = 2 + Int(unit() * 5)
                birdF0 = 2400 + 2200 * unit()
                birdSweep = (unit() < 0.5 ? -1 : 1) * (600 + 1200 * unit())
                birdDur = (0.05 + 0.08 * unit()) * sampleRate
                birdGap = (0.04 + 0.1 * unit()) * sampleRate
                birdVol = 0.08 + 0.12 * unit()
                birdT = 0
            }
        } else {
            birdT += 1
            if birdT <= birdDur {
                let x = birdT / birdDur
                let freq = birdF0 + birdSweep * x + 120 * sinf(x * 18)
                birdPhase += freq / sampleRate
                if birdPhase > 1 { birdPhase -= 1 }
                let env = sinf(x * .pi)
                bird = sinf(birdPhase * 2 * .pi) * env * env * birdVol
            } else if birdT > birdDur + birdGap {
                birdChirpsLeft -= 1
                birdT = 0
                if birdChirpsLeft == 0 { birdWait = (1.2 + 3.5 * unit()) * sampleRate }
            }
        }
        return wind + bird
    }

    // MARK: 시계: 1초마다 똑 · 딱

    private var clockLeft: Float, clockTick = false, clockEnv: Float = 0, clockPhase: Float = 0, clockFreq: Float = 2800
    private var clockHigh = OnePole()
    private func clock() -> Float {
        clockLeft -= 1
        if clockLeft <= 0 {
            clockLeft += sampleRate
            clockTick.toggle()
            clockFreq = clockTick ? 2900 : 2300
            clockEnv = 1
            clockPhase = 0
        }
        guard clockEnv > 0.0005 else { return 0 }
        clockPhase += clockFreq / sampleRate
        if clockPhase > 1 { clockPhase -= 1 }
        let n = white()
        let click = 0.5 * sinf(clockPhase * 2 * .pi) + 0.5 * (n - clockHigh.lowpass(n, 0.2))
        let out = click * clockEnv * 0.45
        clockEnv *= expf(-1 / (0.006 * sampleRate))
        return out
    }
}

// MARK: - 작은 필터들

/// 핑크 노이즈 (Paul Kellet 필터)
struct Pink {
    var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    mutating func next(_ w: Float) -> Float {
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
}

/// 브라운 노이즈 (흰 잡음을 쌓아 낮은 소리만)
struct Brown {
    var value: Float = 0
    mutating func next(_ w: Float) -> Float {
        value = (value + 0.02 * w) / 1.02
        return value * 3.5
    }
}

struct OnePole {
    var y: Float = 0
    mutating func lowpass(_ x: Float, _ a: Float) -> Float {
        y += a * (x - y)
        return y
    }
}

/// 띠 통과 필터 (말소리 대역)
struct Biquad {
    var b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
    var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

    static func bandpass(_ freq: Float, q: Float, sr: Float) -> Biquad {
        let w = 2 * Float.pi * freq / sr
        let alpha = sinf(w) / (2 * q)
        let a0 = 1 + alpha
        return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * cosf(w) / a0, a2: (1 - alpha) / a0)
    }

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}
