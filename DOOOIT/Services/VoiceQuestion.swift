import AVFoundation
import Observation
import Speech

/// 말로 질문하기: 한국어 음성을 실시간으로 글자로 (기기 안 음성 인식을 먼저 씀)
/// - 다시 누르거나, 말을 멈추고 1.5초 지나면 끝
/// - 권한이 없으면 짧은 안내 + 설정 열기
@MainActor
@Observable
final class VoiceQuestion {
    enum Problem: Equatable {
        /// 마이크 · 음성 인식 권한이 꺼져 있음
        case denied
        /// 지금은 음성 인식을 쓸 수 없음
        case unavailable
    }

    private(set) var isListening = false
    private(set) var transcript = ""
    var problem: Problem?
    /// 말소리 크기 (0...1, 듣는 표시 움직임용)
    private(set) var level: Float = 0

    /// 말을 멈춘 뒤 끝내기까지 기다리는 시간
    static let silence: Duration = .milliseconds(1500)
    /// 아무 말이 없으면 끝내는 시간
    static let noSpeech: Duration = .seconds(7)
    /// 가장 길게 듣는 시간
    static let maxLength: Duration = .seconds(45)

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    @ObservationIgnored private var onFinish: ((String) -> Void)?
    @ObservationIgnored private var silenceTimer: Task<Void, Never>?
    @ObservationIgnored private var limitTimer: Task<Void, Never>?

    /// 이 기기가 인터넷 없이 한국어 음성 인식을 할 수 있는지
    var isOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    /// 이미 거절된 권한이 있는지 (다시 물어볼 수 없어서 설정으로 안내)
    static var isDenied: Bool {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        return speech == .denied || speech == .restricted || mic == .denied
    }

    static func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// 누를 때마다: 듣기 시작 ↔ 끝내기
    func toggle(onFinish: @escaping (String) -> Void) async {
        if isListening { stop() } else { await start(onFinish: onFinish) }
    }

    func start(onFinish: @escaping (String) -> Void) async {
        guard !isListening else { return }
        problem = nil
        transcript = ""
        guard !Self.isDenied, await Self.requestPermission() else {
            problem = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = .unavailable
            return
        }
        AmbientSoundPlayer.shared.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .search
            // 기기 안에서 할 수 있으면 기기 안에서만 (음성이 밖으로 나가지 않게)
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            request.addsPunctuation = true
            self.request = request

            let input = engine.inputNode
            Self.installTap(on: input, request: request, owner: self)
            engine.prepare()
            try engine.start()

            self.onFinish = onFinish
            isListening = true
            task = recognizer.recognitionTask(with: request, resultHandler: Self.makeHandler(owner: self))
            waitForSilence(Self.noSpeech)
            limitTimer?.cancel()
            limitTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.maxLength)
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            problem = .unavailable
            cleanUp()
        }
    }

    /// 듣기를 끝내고 결과 전달
    func stop() {
        guard isListening else { return }
        request?.endAudio()
        finish()
    }

    /// 보내지 않고 그만두기 (화면을 떠날 때)
    func cancel() {
        onFinish = nil
        stop()
    }

    private func waitForSilence(_ duration: Duration) {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private func receive(_ text: String?, isFinal: Bool) {
        guard isListening else { return }
        if let text, !text.isEmpty, text != transcript {
            transcript = text
            // 말을 이어 가면 기다리는 시간을 다시 셈
            waitForSilence(Self.silence)
        }
        if isFinal { finish() }
    }

    private func receive(level value: Float) {
        level = level * 0.6 + value * 0.4
    }

    private func finish() {
        guard isListening else { return }
        isListening = false
        level = 0
        silenceTimer?.cancel()
        limitTimer?.cancel()
        let result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // 오디오·인식 콜백은 다른 스레드에서 불려서 메인 액터 밖에서 만듦
    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest, owner: VoiceQuestion) {
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            // 말소리 크기 (듣는 표시용)
            guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
            let rms = (sum / Float(buffer.frameLength)).squareRoot()
            let value = min(1, rms * 12)
            Task { @MainActor in owner.receive(level: value) }
        }
    }

    nonisolated private static func makeHandler(owner: VoiceQuestion) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in owner.receive(text, isFinal: isFinal) }
        }
    }

    #if DEBUG
    /// 화면 사진용: 듣는 중인 모습만 (마이크는 켜지 않음)
    func showDemo(_ text: String) {
        isListening = true
        transcript = text
        level = 0.6
    }
    #endif
}
