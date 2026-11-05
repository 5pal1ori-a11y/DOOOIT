import SwiftData
import SwiftUI

/// 사진 → 글자 인식 → 단어 확인/수정 → 저장
struct WordImportView: View {
    let images: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var items: [ParsedWord] = []
    @State private var isProcessing = true
    @State private var deck: String
    @State private var failedMessage: String?

    init(images: [UIImage], deck: String = "기본 단어장") {
        self.images = images
        _deck = State(initialValue: deck)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isProcessing {
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large)
                        Text("읽는 중 · \(images.count)장")
                            .font(.pt(.subheadline).weight(.semibold))
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
                    let unsure = items.filter(\.unsure).count
                    Label(unsure > 0 ? "\(items.count)개 · 확인 필요 \(unsure)" : "\(items.count)개 찾음",
                          systemImage: "text.viewfinder")
                }
                TextField("단어장 이름", text: $deck)
            }

            Section {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            TextField("영어 단어", text: $item.term)
                                .font(.pt(.body).weight(.semibold))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(item.unsure ? Palette.warning : Palette.ink)
                            if item.unsure {
                                Button {
                                    item.unsure = false
                                } label: {
                                    Text("맞아요")
                                        .font(.pt(.caption).weight(.semibold))
                                        .foregroundStyle(Palette.warning)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Palette.warning.opacity(0.12), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("철자 맞음")
                            }
                        }
                        TextField("뜻", text: $item.meaning)
                            .foregroundStyle(.secondary)
                        if item.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("뜻 없음")
                                .font(.pt(.caption2))
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
            for word in await OCRService.readWords(image)
            where !all.contains(where: { $0.term.lowercased() == word.term.lowercased() }) {
                all.append(word)
            }
        }
        // 뜻을 못 찾은 줄은 대부분 유의어·제목 같은 군더더기라 빼고 보여 줌 (개수를 억지로 채우지 않음)
        let withMeaning = all.filter { !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty }
        if !withMeaning.isEmpty { all = withMeaning }
        items = all
        if all.isEmpty {
            failedMessage = "글자를 못 찾았어요"
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
    var defaultDeck: String = "기본 단어장"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var term = ""
    @State private var meaning = ""
    @State private var deck = "기본 단어장"
    @State private var starred = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("영어 단어", text: $term)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("뜻", text: $meaning, axis: .vertical)
                    TextField("단어장", text: $deck)
                    Toggle("저장", isOn: $starred)
                }
                if let word {
                    Section {
                        LabeledContent("맞힘", value: "\(word.correctCount)")
                        LabeledContent("틀림", value: "\(word.wrongCount)")
                        LabeledContent("상태", value: word.isMastered ? "완전히 외움" : (word.isLearned ? "외움" : "학습 전"))
                        if word.isLearned {
                            Button("학습 전으로 되돌리기") {
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
                    starred = word.isStarred
                } else {
                    deck = defaultDeck
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let t = term.trimmingCharacters(in: .whitespaces)
        let m = meaning.trimmingCharacters(in: .whitespaces)
        let d = deck.trimmingCharacters(in: .whitespaces).isEmpty ? "기본 단어장" : deck.trimmingCharacters(in: .whitespaces)
        if let word {
            word.term = t
            word.meaning = m
            word.deck = d
            word.isStarred = starred
        } else {
            let new = Word(term: t, meaning: m, deck: d)
            new.isStarred = starred
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
