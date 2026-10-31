import SwiftData
import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]
    @State private var editing: PlanCategory?
    @State private var showNew = false

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button { editing = category } label: {
                        HStack(spacing: 12) {
                            IconBadge(symbol: category.symbol, color: category.color, size: 36)
                            Text(category.name)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if category.isStudy {
                                TagLabel(text: "공부 타이머", symbol: "timer", color: category.color)
                            }
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(categories[i]) }
                    try? context.save()
                }
                .onMove { from, to in
                    var items = categories
                    items.move(fromOffsets: from, toOffset: to)
                    for (i, item) in items.enumerated() { item.sortIndex = i }
                    try? context.save()
                }
            } footer: {
                Text("'공부 타이머'가 켜진 카테고리의 일정은 시작 시간에 공부 타이머가 자동으로 실행되고, 시작 전에 다이나믹 아일랜드에 남은 시간이 표시돼요.")
            }
        }
        .navigationTitle("카테고리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { category in
            CategoryEditorView(category: category, nextIndex: categories.count)
        }
        .sheet(isPresented: $showNew) {
            CategoryEditorView(category: nil, nextIndex: categories.count)
        }
    }
}

struct CategoryEditorView: View {
    let category: PlanCategory?
    let nextIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var colorHex = Palette.swatches[0]
    @State private var symbol = "book.fill"
    @State private var isStudy = true

    private let symbols = [
        "book.fill", "books.vertical.fill", "character.book.closed.fill", "function", "pencil",
        "graduationcap.fill", "brain.head.profile", "atom", "globe.asia.australia.fill", "laptopcomputer",
        "figure.run", "dumbbell.fill", "music.note", "paintpalette.fill", "briefcase.fill",
        "cart.fill", "heart.fill", "person.fill", "house.fill", "star.fill"
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
                    TextField("카테고리 이름", text: $name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }

                Section {
                    Toggle(isOn: $isStudy) {
                        Label("공부 타이머 자동 실행", systemImage: "timer")
                    }
                } footer: {
                    Text("켜면 이 카테고리의 일정 시간이 되었을 때 공부 타이머가 자동으로 시작돼요.")
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
            .navigationTitle(category == nil ? "새 카테고리" : "카테고리 수정")
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
