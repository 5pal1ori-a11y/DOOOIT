import SwiftData
import SwiftUI

// MARK: - 결과 화면

private struct GameResultView: View {
    let title: String
    let symbol: String
    let again: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.pt(size: 64, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(title).font(.pt(.title).weight(.bold))
            Button(action: again) {
                Label("다시 하기", systemImage: "arrow.counterclockwise")
                    .font(.pt(.headline))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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
                    Text("\(index + 1)/\(queue.count)").font(.pt(.subheadline).weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        Text(current.term).font(.pt(size: 38, weight: .heavy))
                        Text(current.meaning).font(.pt(.subheadline)).foregroundStyle(.secondary)
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
                    .background(Palette.cardInset, in: .rect(cornerRadius: 14))

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
                            .font(.pt(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(checker.isListening ? Palette.danger : Theme.accent, in: .circle)
                            .symbolEffect(.pulse, isActive: checker.isListening)
                    }
                    .buttonStyle(.plain)

                    Group {
                        if checker.isListening {
                            Text(checker.transcript.isEmpty ? L("듣는 중…") : "“\(checker.transcript)”")
                                .foregroundStyle(.secondary)
                        } else if let result {
                            VStack(spacing: 4) {
                                Label(result ? L("정확해요!") : L("다시 해 봐요"),
                                      systemImage: result ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                                    .font(.pt(.headline))
                                    .foregroundStyle(result ? Palette.success : Palette.warning)
                                if !checker.transcript.isEmpty {
                                    Text(checker.transcript).font(.pt(.caption)).foregroundStyle(.secondary)
                                }
                            }
                        } else if let error = checker.errorMessage {
                            Text(error).font(.pt(.caption)).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
                        } else {
                            Text("눌러서 말하기").foregroundStyle(.secondary)
                        }
                    }
                    .font(.pt(.subheadline))
                    .frame(minHeight: 44)

                    Button {
                        index += 1
                        result = nil
                    } label: {
                        Text(result == true ? L("다음 단어") : L("건너뛰기"))
                            .font(.pt(.headline))
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
                GameResultView(title: L("\(passed)/\(queue.count) 통과"), symbol: "mic.fill") { setUp() }
            } else {
                ProgressView()
            }
        }
        .background(Palette.card.ignoresSafeArea())
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
