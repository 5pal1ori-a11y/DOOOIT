import SwiftData
import SwiftUI

struct MemoListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @State private var search = ""
    @State private var opened: Memo?

    private var filtered: [Memo] {
        guard !search.isEmpty else { return memos }
        return memos.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            if memos.isEmpty {
                EmptyStateView(symbol: "note.text", title: "메모가 없어요", message: "오른쪽 위 버튼을 눌러 새 메모를 작성해보세요.")
                    .listRowBackground(Color.clear)
            }

            let pinned = filtered.filter(\.isPinned)
            if !pinned.isEmpty {
                Section("고정됨") {
                    ForEach(pinned) { row($0) }
                }
            }

            let others = filtered.filter { !$0.isPinned }
            if !others.isEmpty {
                Section(pinned.isEmpty ? "메모" : "기타") {
                    ForEach(others) { row($0) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .searchable(text: $search, prompt: "메모 검색")
        .navigationTitle("메모장")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let memo = Memo()
                    context.insert(memo)
                    opened = memo
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .navigationDestination(item: $opened) { memo in
            MemoEditorView(memo: memo)
        }
    }

    private func row(_ memo: Memo) -> some View {
        Button { opened = memo } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if memo.isPinned {
                        Image(systemName: "pin.fill").font(.caption).foregroundStyle(Palette.warning)
                    }
                    Text(memo.displayTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(memo.updatedAt.kr("M월 d일"))
                    Text(memo.content.replacingOccurrences(of: "\n", with: " "))
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .tint(.primary)
        .swipeActions(edge: .leading) {
            Button {
                memo.isPinned.toggle()
                try? context.save()
            } label: {
                Label(memo.isPinned ? "고정 해제" : "고정", systemImage: memo.isPinned ? "pin.slash" : "pin")
            }
            .tint(Palette.warning)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(memo)
                try? context.save()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

struct MemoEditorView: View {
    @Bindable var memo: Memo
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @State private var showDeleteConfirm = false

    enum Field { case title, content }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("제목", text: $memo.title)
                .font(.title2.weight(.bold))
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .content }
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Text(memo.updatedAt.kr("yyyy년 M월 d일 a h:mm"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            TextEditor(text: $memo.content)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .content)
                .padding(.horizontal, 15)
                .padding(.top, 6)
        }
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    memo.isPinned.toggle()
                } label: {
                    Image(systemName: memo.isPinned ? "pin.fill" : "pin")
                }
                Menu {
                    ShareLink(item: "\(memo.displayTitle)\n\n\(memo.content)") {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("완료") { focus = nil }
                }
            }
        }
        .confirmationDialog("메모를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                context.delete(memo)
                try? context.save()
                dismiss()
            }
        }
        .onChange(of: memo.content) { _, _ in memo.updatedAt = Date() }
        .onChange(of: memo.title) { _, _ in memo.updatedAt = Date() }
        .onAppear {
            if memo.title.isEmpty && memo.content.isEmpty { focus = .title }
        }
        .onDisappear {
            // 빈 메모는 저장하지 않음
            if memo.modelContext != nil,
               memo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               memo.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.delete(memo)
            }
            try? context.save()
        }
    }
}
