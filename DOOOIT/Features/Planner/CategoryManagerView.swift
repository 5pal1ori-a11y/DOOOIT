import SwiftData
import SwiftUI

/// 공부 과목(공부 플랜용)과 일반 카테고리(일반 플랜용)를 나눠서 관리
struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]
    @State private var editing: PlanCategory?
    @State private var newIsStudy: Bool?

    private var subjects: [PlanCategory] { categories.filter(\.isStudy) }
    private var generals: [PlanCategory] { categories.filter { !$0.isStudy } }

    var body: some View {
        List {
            Section {
                ForEach(subjects) { row($0) }
                    .onDelete { delete($0, in: subjects) }
                    .onMove { move($0, $1, in: subjects) }
                Button { newIsStudy = true } label: { Label("과목 추가", systemImage: "plus") }
            } header: {
                Text("공부 과목")
            } footer: {
                Text("통계가 과목별로 모여요")
            }

            Section {
                ForEach(generals) { row($0) }
                    .onDelete { delete($0, in: generals) }
                    .onMove { move($0, $1, in: generals) }
                Button { newIsStudy = false } label: { Label("카테고리 추가", systemImage: "plus") }
            } header: {
                Text("일반 카테고리")
            } footer: {
                Text("약속·개인 일정용")
            }
        }
        .navigationTitle("카테고리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .sheet(item: $editing) { category in
            CategoryEditorView(category: category, nextIndex: categories.count, initialIsStudy: category.isStudy)
        }
        .sheet(isPresented: Binding(get: { newIsStudy != nil }, set: { if !$0 { newIsStudy = nil } })) {
            CategoryEditorView(category: nil, nextIndex: categories.count, initialIsStudy: newIsStudy ?? true)
        }
    }

    private func row(_ category: PlanCategory) -> some View {
        Button { editing = category } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: category.symbol, color: category.color, size: 36)
                Text(category.name).font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    private func delete(_ offsets: IndexSet, in list: [PlanCategory]) {
        for i in offsets { context.delete(list[i]) }
        try? context.save()
    }

    private func move(_ from: IndexSet, _ to: Int, in list: [PlanCategory]) {
        var items = list
        items.move(fromOffsets: from, toOffset: to)
        let base = list.map(\.sortIndex).min() ?? 0
        for (i, item) in items.enumerated() { item.sortIndex = base + i }
        try? context.save()
    }
}

struct CategoryEditorView: View {
    let category: PlanCategory?
    let nextIndex: Int
    var initialIsStudy: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var colorHex = Palette.swatches[0]
    @State private var symbol = "book.fill"
    @State private var isStudy = true

    private let symbols = [
        "book.fill", "books.vertical.fill", "character.book.closed.fill", "function", "pencil",
        "graduationcap.fill", "brain.head.profile", "atom", "globe.asia.australia.fill", "building.columns.fill",
        "flask.fill", "laptopcomputer", "figure.run", "dumbbell.fill", "music.note",
        "paintpalette.fill", "briefcase.fill", "person.2.fill", "person.fill", "star.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        IconBadge(symbol: symbol, color: Color(hex: colorHex), size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    TextField(isStudy ? L("과목 이름 (예: 한국사)") : L("카테고리 이름"), text: $name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }

                Section {
                    Picker("종류", selection: $isStudy) {
                        Text("공부 과목").tag(true)
                        Text("일반 카테고리").tag(false)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(isStudy ? L("공부 플랜에서 고를 수 있고, 시간이 되면 공부 타이머가 자동으로 시작돼요.") : L("일반 플랜에서 고를 수 있고, 알림만 보내요."))
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Palette.swatches, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("아이콘") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(symbols, id: \.self) { item in
                            Image(systemName: item)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(item == symbol ? Color.white : Color.primary)
                                .background(item == symbol ? Color(hex: colorHex) : Color.primary.opacity(0.06), in: .circle)
                                .onTapGesture { symbol = item }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(category == nil ? (isStudy ? L("새 과목") : L("새 카테고리")) : L("카테고리 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    colorHex = category.colorHex
                    symbol = category.symbol
                    isStudy = category.isStudy
                } else {
                    isStudy = initialIsStudy
                    symbol = initialIsStudy ? "book.fill" : "star.fill"
                    colorHex = initialIsStudy ? Palette.swatches[0] : Palette.swatches[8]
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            category.name = trimmed
            category.colorHex = colorHex
            category.symbol = symbol
            category.isStudy = isStudy
        } else {
            context.insert(PlanCategory(name: trimmed, symbol: symbol, colorHex: colorHex, isStudy: isStudy, sortIndex: nextIndex))
        }
        try? context.save()
        PlanScheduler.shared.rescheduleNotifications()
        dismiss()
    }
}
