import SwiftData
import SwiftUI

/// 내 풀이 기록으로 찾은 취약 유형과 맞춤 학습
struct WeaknessView: View {
    @Query private var records: [QuizRecord]
    @Query private var notes: [MathNote]

    struct Weakness: Identifiable {
        let subject: String
        let unit: String
        let correct: Int
        let total: Int
        let wrongNotes: Int
        var id: String { subject + "|" + unit }
        var accuracy: Double { total == 0 ? 0.3 : Double(correct) / Double(total) }

        /// 0: 개념이해 전, 1: 실전활용 가능, 2: 고난도 정복
        var level: Int { accuracy < 0.5 ? 0 : (accuracy < 0.8 ? 1 : 2) }

        var headline: String {
            switch level {
            case 0: return "기본 문제에 오답이 많아요"
            case 1: return "응용 문제에서 실수가 있어요"
            default: return "고난도 문제에 도전할 차례예요"
            }
        }

        var plan: String {
            switch level {
            case 0: return "개념 중심 학습으로 교과서 문제를 쉽게 풀 수 있어요"
            case 1: return "O/X와 유형 문제로 실전 감각을 길러요"
            default: return "실전 문제로 실수 없이 마무리해요"
            }
        }

        var startStep: LearnStep {
            switch level {
            case 0: return .concept
            case 1: return .ox
            default: return .problem
            }
        }

        var minutes: Int { level == 0 ? 90 : (level == 1 ? 60 : 40) }
    }

    private var weaknesses: [Weakness] {
        var map: [String: (subject: String, unit: String, correct: Int, total: Int, notes: Int)] = [:]
        for record in records {
            let key = record.subject + "|" + record.unit
            var entry = map[key] ?? (record.subject, record.unit, 0, 0, 0)
            entry.correct += record.correct
            entry.total += record.total
            map[key] = entry
        }
        for note in notes where note.status == .wrong && !note.unit.isEmpty {
            let unitName = note.unit.components(separatedBy: CharacterSet(charactersIn: "·,/")).first?
                .trimmingCharacters(in: .whitespaces) ?? note.unit
            let key = "수학|" + unitName
            var entry = map[key] ?? ("수학", unitName, 0, 0, 0)
            entry.notes += 1
            map[key] = entry
        }
        return map.values
            .map { Weakness(subject: $0.subject, unit: $0.unit, correct: $0.correct, total: $0.total, wrongNotes: $0.notes) }
            .filter { $0.accuracy < 0.8 || $0.wrongNotes > 0 }
            .sorted { ($0.accuracy - Double($0.wrongNotes) * 0.1) < ($1.accuracy - Double($1.wrongNotes) * 0.1) }
    }

    var body: some View {
        let list = weaknesses
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("빈칸·O/X·문제 풀이 기록과 오답노트를 모아 약한 유형을 찾아요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if list.isEmpty {
                    EmptyStateView(symbol: "scope", title: "아직 찾은 취약 유형이 없어요",
                                   message: "단원별 학습에서 문제를 풀거나\n오답노트에 단원을 적고 오답으로 채점해보세요.")
                        .glassCard()
                }
                ForEach(list) { item in
                    weaknessCard(item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("취약 유형 맞춤 학습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weaknessCard(_ item: Weakness) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                TagLabel(text: item.subject, color: .secondary)
                if item.total > 0 { TagLabel(text: "정답률 \(Int(item.accuracy * 100))%", color: Theme.accent) }
                if item.wrongNotes > 0 { TagLabel(text: "오답노트 \(item.wrongNotes)", color: Palette.danger) }
            }
            Label(item.unit, systemImage: "sparkles").font(.headline).foregroundStyle(Theme.accent)
            Text("\(item.headline)\n\(item.plan)")
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("맞춤 학습 예상 시간 \(TimeText.duration(minutes: item.minutes))")
                .font(.caption)
                .foregroundStyle(.secondary)

            levelBar(item.level)

            NavigationLink {
                UnitStudyView(subject: item.subject, unit: item.unit, initialStep: item.startStep)
            } label: {
                Text("이 맞춤 학습 시작하기")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func levelBar(_ level: Int) -> some View {
        let labels = ["개념이해 전", "실전활용 가능", "고난도 정복"]
        let current = (Double(level) + 0.5) / 3
        let target = min(1, (Double(level) + 1.5) / 3)
        return VStack(spacing: 6) {
            HStack {
                Text("현재 내 실력은?").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label("예상 도달: \(labels[min(level + 1, 2)])", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(Theme.accent.opacity(0.25)).frame(width: geo.size.width * target)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * current)
                }
            }
            .frame(height: 10)
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.caption2.weight(index == level ? .bold : .regular))
                        .foregroundStyle(index == level ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 16))
    }
}

/// AI 학습: 과목과 단원만 직접 입력
struct CurriculumView: View {
    @State private var subject = ""
    @State private var unit = ""
    @FocusState private var focus: Field?

    private enum Field { case subject, unit }

    private var trimmedSubject: String { subject.trimmingCharacters(in: .whitespaces) }
    private var trimmedUnit: String { unit.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("무엇을 공부할까요?").font(.title2.weight(.heavy))
                    Text("과목과 단원을 적으면 AI가 개념 → 빈칸 → O/X → 문제 순서로 자료를 만들어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    field(title: "과목", placeholder: "예: 수학", text: $subject, field: .subject)
                    Divider().padding(.leading, 16)
                    field(title: "단원", placeholder: "예: 이차방정식과 이차함수", text: $unit, field: .unit)
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 22))

                NavigationLink {
                    UnitStudyView(subject: trimmedSubject, unit: trimmedUnit)
                } label: {
                    Label("학습 시작", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.glassProminent)
                .disabled(trimmedSubject.isEmpty || trimmedUnit.isEmpty)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("AI 학습")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if subject.isEmpty { focus = .subject } }
    }

    private func field(title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            TextField(placeholder, text: text)
                .focused($focus, equals: field)
                .submitLabel(field == .subject ? .next : .done)
                .onSubmit { if field == .subject { focus = .unit } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}
