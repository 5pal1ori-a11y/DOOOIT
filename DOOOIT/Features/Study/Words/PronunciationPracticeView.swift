import SwiftData
import SwiftUI

// MARK: - 결과 화면

private struct GameResultView: View {
    let title: String
    let detail: String
    let symbol: String
    let again: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: title)
            Text(title).font(.title.weight(.heavy))
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(action: again) {
                Label("다시 하기", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(20)
    }
}


/// 발음 연습: 듣고 따라 말하면 기기 안 음성 인식으로 확인
struct SpeakPracticeView: View {
    let pool: [Word]

    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var checker = SpeechChecker()
    @State private var result: Bool?
    @State private var passed = 0

    private var current: Word? { index < queue.count ? queue[index] : nil }

    var body: some View {
        Group {
            if let current {
                VStack(spacing: 22) {
                    Text("\(index + 1) / \(queue.count)").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        Text(current.term).font(.system(size: 38, weight: .heavy))
                        Text(current.meaning).font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button { WordSpeaker.shared.speak(current.term) } label: {
                                Label("듣기", systemImage: "speaker.wave.2.fill")
                            }
                            Button { WordSpeaker.shared.speak(current.term, slow: true) } label: {
                                Label("천천히", systemImage: "tortoise.fill")
                            }
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .glassEffect(.regular, in: .rect(cornerRadius: 26))

                    Button {
                        if checker.isListening {
                            checker.stop()
                        } else {
                            result = nil
                            Task {
                                await checker.start(expected: current.term) { spoken in
                                    let ok = SpeechChecker.matches(spoken, expected: current.term)
                                    withAnimation(.snappy) { result = ok }
                                    if ok { passed += 1; Haptics.success() } else { Haptics.error() }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: checker.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(checker.isListening ? Palette.danger : Theme.accent, in: .circle)
                            .symbolEffect(.pulse, isActive: checker.isListening)
                    }
                    .buttonStyle(.plain)

                    Group {
                        if checker.isListening {
                            Text(checker.transcript.isEmpty ? "듣고 있어요… 단어를 말해보세요" : "“\(checker.transcript)”")
                                .foregroundStyle(.secondary)
                        } else if let result {
                            VStack(spacing: 4) {
                                Label(result ? "정확해요!" : "다시 해볼까요?",
                                      systemImage: result ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(result ? Palette.success : Palette.warning)
                                if !checker.transcript.isEmpty {
                                    Text("들린 말: \(checker.transcript)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } else if let error = checker.errorMessage {
                            Text(error).font(.caption).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
                        } else {
                            Text("마이크를 누르고 단어를 말해보세요").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)

                    Button {
                        index += 1
                        result = nil
                    } label: {
                        Text(result == true ? "다음 단어" : "건너뛰기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                .padding(20)
                .onAppear { WordSpeaker.shared.speak(current.term) }
                .onChange(of: index) { if let next = self.current { WordSpeaker.shared.speak(next.term) } }
            } else if !queue.isEmpty {
                GameResultView(title: "\(passed) / \(queue.count) 통과!", detail: "기기 안 음성 인식으로 확인했어요",
                               symbol: "mic.fill") { setUp() }
            } else {
                ProgressView()
            }
        }
        .background { AppBackground() }
        .navigationTitle("발음 연습")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if queue.isEmpty { setUp() } }
        .onDisappear { checker.stop() }
    }

    private func setUp() {
        queue = Array(pool.shuffled().prefix(10))
        index = 0
        passed = 0
        result = nil
    }
}
