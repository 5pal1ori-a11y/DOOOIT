import SwiftData
import SwiftUI

/// 내 단어장: 검색 · 필터 · 저장(별표) · 수정 · 삭제
struct WordListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "전체", notLearned = "학습 전", learned = "외움", wrong = "틀림", starred = "저장"
        var id: String { rawValue }
    }

    let words: [Word]
    var defaultDeck: String = "기본 단어장"

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var editing: Word?
    @State private var showAdd = false

    private var filtered: [Word] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return words.filter { word in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .notLearned: matchesFilter = !word.isLearned
            case .learned: matchesFilter = word.isLearned
            case .wrong: matchesFilter = word.wrongCount > 0
            case .starred: matchesFilter = word.isStarred
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            return word.term.localizedCaseInsensitiveContains(query) || word.meaning.contains(query)
        }
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                if filtered.isEmpty {
                    Text(search.isEmpty ? "단어가 없어요" : "검색 결과가 없어요")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                ForEach(filtered) { word in
                    row(word)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 12))
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(word)
                                try? context.save()
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("\(filtered.count)개")
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").font(.pt(.subheadline).weight(.bold))
                    }
                    .tint(Theme.accent)
                    .accessibilityLabel("단어 추가")
                }
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: $editing) { word in
            WordEditSheet(word: word)
        }
        .sheet(isPresented: $showAdd) {
            WordEditSheet(word: nil, defaultDeck: defaultDeck)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("검색", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("지우기")
                }
            }
            .font(.pt(.subheadline))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Palette.cardInset, in: .capsule)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { item in
                        let selected = item == filter
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy) { filter = item }
                        } label: {
                            Text(item.rawValue)
                                .font(.pt(.subheadline).weight(.semibold))
                                .foregroundStyle(selected ? .white : Palette.ink.opacity(0.75))
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(selected ? Theme.accent : Palette.cardInset, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ word: Word) -> some View {
        HStack(spacing: 6) {
            Button { editing = word } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(word.term).font(.pt(.body).weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(word.meaning).font(.pt(.subheadline)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    if word.isMastered {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success).font(.pt(.subheadline))
                    } else if word.isLearned {
                        Image(systemName: "checkmark").foregroundStyle(Palette.success).font(.pt(.caption).weight(.bold))
                    }
                    if word.wrongCount > 0 {
                        Text("\(word.wrongCount)")
                            .font(.pt(.caption2).weight(.bold).monospacedDigit())
                            .foregroundStyle(Palette.danger)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Palette.danger.opacity(0.12), in: .capsule)
                            .accessibilityLabel("틀린 횟수 \(word.wrongCount)")
                    }
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            iconButton(symbol: "speaker.wave.2", color: .secondary, label: "\(word.term) 발음 듣기") {
                WordSpeaker.shared.speak(word.term)
            }
            iconButton(symbol: word.isStarred ? "bookmark.fill" : "bookmark",
                       color: word.isStarred ? Theme.accent : .secondary,
                       label: word.isStarred ? "저장 취소" : "저장") {
                word.isStarred.toggle()
                try? context.save()
                Haptics.tap()
            }
        }
    }

    private func iconButton(symbol: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
