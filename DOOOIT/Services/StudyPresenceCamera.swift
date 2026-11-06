import AVFoundation
import CoreImage
import UIKit
import Vision

/// AI 순공부 측정용 카메라: 낮은 해상도로 받아서 1초에 3번쯤만 Vision으로 분석해요.
/// 영상은 메모리에서 바로 버리고 어디에도 저장하거나 보내지 않아요 (결과는 PresenceFrame의 점 좌표뿐).
enum PresenceCameraPosition: String {
    case back, front

    var avPosition: AVCaptureDevice.Position { self == .front ? .front : .back }
}

enum PresenceCameraError: Error {
    case denied
    case noCamera
    case failed

    /// 사용자에게 보여 줄 짧은 안내
    var message: String {
        switch self {
        case .denied: "카메라 권한이 필요해요"
        case .noCamera: "이 기기에서는 카메라를 쓸 수 없어요"
        case .failed: "카메라를 켜지 못했어요"
        }
    }
}

final class PresenceCameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// 분석 결과 (카메라 큐에서 불림): 프레임 요약, 점들, 시각(부팅 후 초)
    var onObservation: (@Sendable (FrameObservation, PresenceFrame, TimeInterval) -> Void)?
    /// 미리보기 그림 (가이드 화면에서만, 카메라 큐에서 불림)
    var onPreview: (@Sendable (UIImage) -> Void)?
    /// 카메라가 끊김(전화 · 다른 앱이 카메라 사용)과 다시 이어짐
    var onInterruption: (@Sendable (Bool) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "moti.presence.camera", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var analyzer = PresenceFrameAnalyzer()
    private var position: PresenceCameraPosition = .back
    private var configuredPosition: PresenceCameraPosition?
    private var wantsPreview = false
    private var lastAnalyzed: CFTimeInterval = 0
    private var lastPreview: CFTimeInterval = 0
    private var observers: [NSObjectProtocol] = []

    /// 분석 간격 (초): 1초에 3번쯤
    static let analysisInterval: CFTimeInterval = 1.0 / 3

    // MARK: 권한

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

    static func requestAccess() async -> Bool {
        switch authorization {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// 이 기기에 카메라가 있는지 (시뮬레이터에는 없음)
    static func hasCamera(_ position: PresenceCameraPosition) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) != nil
        #endif
    }

    // MARK: 켜기 · 끄기

    func start(position: PresenceCameraPosition, layout: PresenceLayout, preview: Bool) async throws {
        guard Self.authorization == .authorized else { throw PresenceCameraError.denied }
        guard Self.hasCamera(position) else { throw PresenceCameraError.noCamera }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    self.position = position
                    wantsPreview = preview
                    analyzer = PresenceFrameAnalyzer(layout: layout)
                    lastAnalyzed = 0
                    if configuredPosition != position { try configure(position) }
                    addObserversIfNeeded()
                    if !session.isRunning { session.startRunning() }
                    continuation.resume()
                } catch let error as PresenceCameraError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: PresenceCameraError.failed)
                }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            removeObservers()
        }
    }

    func setPreview(_ on: Bool) {
        queue.async { [self] in wantsPreview = on }
    }

    func setLayout(_ layout: PresenceLayout) {
        queue.async { [self] in analyzer.layout = layout }
    }

    /// 이전 프레임 기억을 지움 (일시정지 뒤 다시 시작할 때)
    func resetTracking() {
        queue.async { [self] in analyzer.reset() }
    }

    // MARK: 설정 (카메라 큐에서만)

    private func configure(_ position: PresenceCameraPosition) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) else {
            throw PresenceCameraError.noCamera
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .vga640x480
        for input in session.inputs { session.removeInput(input) }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw PresenceCameraError.failed }
        session.addInput(input)
        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw PresenceCameraError.failed }
            session.addOutput(output)
        }
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        configuredPosition = position
        limitFrameRate(device, fps: 10)
    }

    /// 프레임을 느리게 받아 배터리를 아낌 (지원하는 범위 안에서만)
    private func limitFrameRate(_ device: AVCaptureDevice, fps: Double) {
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= fps && $0.maxFrameRate >= fps }) else { return }
        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {}
    }

    private func addObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.onInterruption?(true)
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            self?.onInterruption?(false)
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] _ in
            // 오류로 멈추면 한 번 다시 켬
            self?.queue.async { [weak self] in
                guard let self, !self.session.isRunning else { return }
                self.session.startRunning()
            }
        })
    }

    private func removeObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    // MARK: 프레임 받기

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 폰이 눕혀져 있어도 사람이 똑바로 서 보이도록 영상 방향을 맞춤 (바뀐 첫 프레임은 건너뜀)
        if let angle = rotation?.videoRotationAngleForHorizonLevelCapture,
           connection.isVideoRotationAngleSupported(angle), connection.videoRotationAngle != angle {
            connection.videoRotationAngle = angle
            return
        }
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 미리보기는 1초에 5장쯤만 (배터리)
        let stamp = CACurrentMediaTime()
        if wantsPreview, stamp - lastPreview >= 0.2, let image = previewImage(pixels) {
            lastPreview = stamp
            onPreview?(image)
        }

        let now = CACurrentMediaTime()
        guard now - lastAnalyzed >= Self.analysisInterval else { return }
        lastAnalyzed = now
        let frame = Self.detect(pixels, layout: analyzer.layout)
        let observation = analyzer.observe(frame)
        onObservation?(observation, frame, ProcessInfo.processInfo.systemUptime)
    }

    private func previewImage(_ pixels: CVPixelBuffer) -> UIImage? {
        let image = CIImage(cvPixelBuffer: pixels)
        guard let cg = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: Vision

    /// 한 프레임에서 몸 · 손 · 사람 사각형을 찾아 점들로 바꿈 (좌표는 왼쪽 위 원점)
    static func detect(_ pixels: CVPixelBuffer, layout: PresenceLayout) -> PresenceFrame {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
        let bodyRequest = VNDetectHumanBodyPoseRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let rectRequest = VNDetectHumanRectanglesRequest()
        rectRequest.upperBodyOnly = true
        try? handler.perform([bodyRequest, handRequest, rectRequest])

        var frame = PresenceFrame()
        let minConfidence: Float = 0.3
        func point(_ p: VNRecognizedPoint) -> PresencePoint? {
            p.confidence >= minConfidence ? PresencePoint(x: Double(p.location.x), y: 1 - Double(p.location.y)) : nil
        }

        // 사람 사각형
        for rect in rectRequest.results ?? [] {
            let b = rect.boundingBox
            frame.humanRects.append(PresenceBox(x: Double(b.minX), y: 1 - Double(b.maxY), w: Double(b.width), h: Double(b.height)))
        }

        // 몸 자세: 몸 칸 안에 점이 가장 많은 사람 한 명
        let people = (bodyRequest.results ?? []).compactMap { observation -> (VNHumanBodyPoseObservation, [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint])? in
            guard let points = try? observation.recognizedPoints(.all) else { return nil }
            return (observation, points)
        }
        let best = people.max { a, b in
            func score(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Int {
                points.values.compactMap(point).filter { layout.body.contains($0, margin: 0.04) }.count * 100
                    + points.values.compactMap(point).count
            }
            return score(a.1) < score(b.1)
        }
        if let (_, points) = best {
            let faceJoints: [VNHumanBodyPoseObservation.JointName] = [.nose, .leftEye, .rightEye, .leftEar, .rightEar]
            let bodyJoints: [VNHumanBodyPoseObservation.JointName] = [.neck, .leftShoulder, .rightShoulder, .root, .leftHip, .rightHip]
            frame.facePoints = faceJoints.compactMap { points[$0].flatMap(point) }
            frame.bodyPoints = bodyJoints.compactMap { points[$0].flatMap(point) }
            for joint in [VNHumanBodyPoseObservation.JointName.leftWrist, .rightWrist] {
                if let wrist = points[joint].flatMap(point) { frame.wrists.append(wrist) }
            }
            if let l = points[.leftShoulder].flatMap(point), let r = points[.rightShoulder].flatMap(point) {
                let width = l.distance(to: r)
                if width > 0.05 { frame.scale = width }
            }
        }
        if frame.scale == nil, let tallest = frame.humanRects.map(\.h).max() {
            frame.scale = tallest * 0.3
        }

        // 손 자세의 손목 (몸 자세 손목과 가까우면 같은 손이라 한 번만)
        for hand in handRequest.results ?? [] {
            guard let wrist = (try? hand.recognizedPoint(.wrist)).flatMap(point) else { continue }
            if !frame.wrists.contains(where: { $0.distance(to: wrist) < 0.05 }) { frame.wrists.append(wrist) }
        }
        return frame
    }
}
