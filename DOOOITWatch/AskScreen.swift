import SwiftUI

/// 모티에게 묻기: 말하거나 손글씨로 물으면 아이폰의 모티(인터넷 없이 도는 규칙형 엔진)가 답함
/// "내일 4시 수학 추가해줘" 같은 말도 바로 플래너에 반영
struct AskScreen: View {
    @Environment(WatchStore.self) private var store
    @State private var draft = ""
    @State private var askedID: String?
    @State private var askedText = ""

    private var accent: Color { store.snapshot.accent }

    /// 짧은 버튼 → 모티가 알아듣는 말
    private let quick: [(label: String, text: String)] = [
        ("오늘 할 일", "오늘 할 일 알려줘"),
        ("내일 일정", "내일 일정 알려줘"),
        ("공부 통계", "이번 주 공부 통계")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(accent)
                    TextField("모티에게 묻기", text: $draft)
                        .font(.footnote)
                        .submitLabel(.send)
                        .onSubmit { ask(draft) }
                }

                if let question = shownQuestion {
                    bubble(question, mine: true)
                    if let answer = shownAnswer {
                        bubble(answer, mine: false)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView()
                                .frame(width: 18, height: 18)
                            Text("생각 중…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(quick, id: \.label) { item in
                    Button {
                        ask(item.text)
                    } label: {
                        Text(item.label)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(accent.opacity(0.18), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("모티")
        .onAppear {
            if WatchDemo.screen == "ask", let demo = store.snapshot.answer {
                askedID = demo.id
                askedText = demo.question
            }
        }
    }

    private var shownQuestion: String? {
        if askedID != nil { return askedText }
        return store.snapshot.answer?.question
    }

    private var shownAnswer: String? {
        guard let answer = store.snapshot.answer else { return nil }
        if let askedID { return answer.id == askedID ? answer.text : nil }
        return answer.text
    }

    private func ask(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !value.isEmpty else { return }
        askedText = value
        askedID = store.ask(value)
        WatchHaptics.play(.click)
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 20) }
            Text(text)
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(mine ? accent.opacity(0.35) : .gray.opacity(0.22), in: .rect(cornerRadius: 12))
            if !mine { Spacer(minLength: 0) }
        }
    }
}
