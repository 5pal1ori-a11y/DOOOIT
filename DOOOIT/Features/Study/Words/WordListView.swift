import SwiftData
import SwiftUI

struct WordListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "전체", notLearned = "학습 전", learned = "외움", wrong = "틀린 단어"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Word.createdAt) private var words: [Word]
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var editing: Word?

    private var filtered: [Word] {
        words.filter { word in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .notLearned: matchesFilter = !word.isLearned
            case .learned: matchesFilter = word.isLearned
            case .wrong: matchesFilter = word.wrongCount > 0
            }
            guard matchesFilter else { return false }
            guard !search.isEmpty else { return true }
            return word.term.localizedCaseInsensitiveContains(search) || word.meaning.contains(search)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("필터", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("\(filtered.count)개") {
                if filtered.isEmpty {
                    EmptyStateView(symbol: "character.book.closed", title: "단어가 없어요", message: "단어장을 촬영하거나 직접 추가해보세요.")
                }
                ForEach(filtered) { word in
                    Button { editing = word } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(word.term).font(.body.weight(.semibold))
                                Text(word.meaning).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if word.wrongCount > 0 {
                                TagLabel(text: "\(word.wrongCount)", symbol: "xmark", color: Palette.danger)
                            }
                            if word.isLearned {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                            }
                        }
                    }
                    .tint(.primary)
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(word)
                            try? context.save()
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .searchable(text: $search, prompt: "단어 또는 뜻 검색")
        .navigationTitle("단어 목록")
        .sheet(item: $editing) { word in
            WordEditSheet(word: word)
        }
    }
}
