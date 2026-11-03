import AVFoundation
import Observation
import Speech
import SwiftUI

/// 영어 단어 읽어주기 (기기 안 음성)
@MainActor
final class WordSpeaker {
    static let shared = WordSpeaker()
    private let synthesizer = AVSpeechSynthesizer()

    /// 발음: 미국식 / 영국식 (설정에 저장)
    enum Accent: String, CaseIterable, Identifiable {
        case us, uk
        var id: String { rawValue }
        var title: String { self == .us ? "미국식" : "영국식" }
        var language: String { self == .us ? "en-US" : "en-GB" }
    }

    static let accentKey = "word.accent"

    var accent: Accent {
        Accent(rawValue: UserDefaults.standard.string(forKey: Self.accentKey) ?? "") ?? .us
    }

    func speak(_ text: String, slow: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: accent.language) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = slow ? 0.32 : 0.45
        synthesizer.speak(utterance)
    }
}

/// 🔊 단어 듣기 버튼 (누를 때마다 보통 ↔ 천천히)
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 40
    @State private var slow = false
    @State private var tick = 0

    var body: some View {
        Button {
            WordSpeaker.shared.speak(text, slow: slow)
            slow.toggle()
            tick += 1
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: tick)
                .frame(width: size, height: size)
                .background(Theme.accent.opacity(0.12), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("발음 듣기")
    }
}

/// 따라 말하기: 마이크로 듣고 기기 안 음성 인식으로 단어와 비교
@MainActor
@Observable
final class SpeechChecker {
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var onFinish: ((String) -> Void)?
    @ObservationIgnored private var stopTimer: Task<Void, Never>?

    /// 마이크 + 음성 인식 권한
    static func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// 말하기 시작 (최대 4초 듣고 자동으로 멈춤)
    func start(expected: String, onFinish: @escaping (String) -> Void) async {
        guard !isListening else { return }
        errorMessage = nil
        transcript = ""
        guard await Self.requestPermission() else {
            errorMessage = "설정 > MOTI에서 마이크와 음성 인식을 허용해주세요."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "지금은 음성 인식을 쓸 수 없어요. 잠시 후 다시 시도해주세요."
            return
        }
        AmbientSoundPlayer.shared.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.contextualStrings = [expected]
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            self.request = request

            let input = engine.inputNode
            Self.installTap(on: input, request: request)
            engine.prepare()
            try engine.start()

            self.onFinish = onFinish
            isListening = true
            task = recognizer.recognitionTask(with: request, resultHandler: Self.makeHandler(owner: self))

            stopTimer?.cancel()
            stopTimer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            errorMessage = "마이크를 시작하지 못했어요."
            cleanUp()
        }
    }

    /// 듣기를 끝내고 결과 전달
    func stop() {
        guard isListening else { return }
        request?.endAudio()
        finish()
    }

    private func receive(_ text: String?, isFinal: Bool) {
        if let text { transcript = text }
        if isFinal { finish() }
    }

    private func finish() {
        guard isListening else { return }
        isListening = false
        stopTimer?.cancel()
        let result = transcript
        let callback = onFinish
        onFinish = nil
        cleanUp()
        callback?(result)
    }

    private func cleanUp() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    // 오디오·인식 콜백은 다른 스레드에서 불려서 메인 액터 밖에서 만듦
    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func makeHandler(owner: SpeechChecker) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in owner.receive(text, isFinal: isFinal) }
        }
    }

    /// 말한 내용에 단어가 들어 있는지 (대소문자·문장부호 무시, 긴 단어는 한 글자 차이 허용)
    static func matches(_ spoken: String, expected: String) -> Bool {
        let target = normalize(expected)
        guard !target.isEmpty else { return false }
        let said = normalize(spoken)
        if said == target || said.contains(target) { return true }
        let words = said.split(separator: " ").map(String.init)
        return words.contains { word in
            target.count > 4 && distance(word, target) <= 1
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.union(.whitespaces).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
