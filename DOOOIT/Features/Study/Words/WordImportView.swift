import SwiftData
import SwiftUI

/// 사진 → 글자 인식 → 단어 확인/수정 → 저장
struct WordImportView: View {
    let images: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var items: [ParsedWord] = []
    @State private var isProcessing = true
    @State private var deck = "기본 단어장"
    @State private var failedMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if isProcessing {
                    VStack(spacing: 18) {
                        ProgressView().controlSize(.large)
                        Text("단어장의 글자를 읽고 있어요")
                            .font(.headline)
                        Text("\(images.count)장의 사진을 분석 중")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    reviewList
                }
            }
            .navigationTitle("단어 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.bold)
                        .disabled(isProcessing || validItems.isEmpty)
                }
            }
            .task { await process() }
        }
    }

    private var validItems: [ParsedWord] {
        items.filter {
            !$0.term.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var reviewList: some View {
        List {
            Section {
                if let failedMessage {
                    Label(failedMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warning)
                } else {
                    Label("\(items.count)개의 단어를 찾았어요. 잘못 읽힌 부분은 직접 고쳐주세요.", systemImage: "text.viewfinder")
                }
                TextField("단어장 이름", text: $deck)
            }

            Section("단어 · 뜻") {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("영어 단어", text: $item.term)
                            .font(.body.weight(.semibold))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("뜻", text: $item.meaning)
                            .foregroundStyle(.secondary)
                        if item.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("뜻이 비어 있으면 저장되지 않아요")
                                .font(.caption2)
                                .foregroundStyle(Palette.danger)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { items.remove(atOffsets: $0) }

                Button {
                    withAnimation { items.append(ParsedWord(term: "", meaning: "")) }
                } label: {
                    Label("단어 추가", systemImage: "plus")
                }
            }
        }
    }

    private func process() async {
        guard isProcessing else { return }
        var all: [ParsedWord] = []
        for image in images {
            if let lines = try? await OCRService.recognize(image) {
                all += WordParser.parse(lines)
            }
        }
        items = all
        if all.isEmpty {
            failedMessage = "글자를 찾지 못했어요. 밝은 곳에서 단어장을 정면으로 찍거나 직접 입력해주세요."
            items = [ParsedWord(term: "", meaning: "")]
        }
        withAnimation { isProcessing = false }
    }

    private func save() {
        let base = Date()
        let deckName = deck.trimmingCharacters(in: .whitespaces).isEmpty ? "기본 단어장" : deck
        for (i, item) in validItems.enumerated() {
            let word = Word(
                term: item.term.trimmingCharacters(in: .whitespaces),
                meaning: item.meaning.trimmingCharacters(in: .whitespaces),
                deck: deckName,
                createdAt: base.addingTimeInterval(Double(i) * 0.001)
            )
            context.insert(word)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

/// 단어 직접 추가 / 수정
struct WordEditSheet: View {
    let word: Word?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var term = ""
    @State private var meaning = ""
    @State private var deck = "기본 단어장"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("영어 단어", text: $term)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("뜻 (여러 개는 쉼표로 구분)", text: $meaning, axis: .vertical)
                    TextField("단어장 이름", text: $deck)
                }
                if let word {
                    Section("학습 기록") {
                        LabeledContent("맞힌 횟수", value: "\(word.correctCount)")
                        LabeledContent("틀린 횟수", value: "\(word.wrongCount)")
                        LabeledContent("상태", value: word.isLearned ? "외움" : "학습 전")
                        if word.isLearned {
                            Button("다시 외울 단어로 되돌리기") {
                                word.learnedAt = nil
                                try? context.save()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(word == nil ? "단어 추가" : "단어 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.bold)
                        .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  meaning.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let word {
                    term = word.term
                    meaning = word.meaning
                    deck = word.deck
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let t = term.trimmingCharacters(in: .whitespaces)
        let m = meaning.trimmingCharacters(in: .whitespaces)
        if let word {
            word.term = t
            word.meaning = m
            word.deck = deck
        } else {
            context.insert(Word(term: t, meaning: m, deck: deck))
        }
        try? context.save()
        dismiss()
    }
}
