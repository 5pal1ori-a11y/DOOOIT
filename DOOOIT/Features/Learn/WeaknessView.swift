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
            case 0: return L("기본 문제에 오답이 많아요")
            case 1: return L("응용 문제에서 실수가 있어요")
            default: return L("고난도 문제에 도전할 차례예요")
            }
        }

        var plan: String {
            switch level {
            case 0: return L("개념 중심 학습으로 교과서 문제를 쉽게 풀 수 있어요")
            case 1: return L("O/X와 유형 문제로 실전 감각을 길러요")
            default: return L("실전 문제로 실수 없이 마무리해요")
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
            VStack(alignment: .leading, spacing: 16) {
                Text("빈칸·O/X·문제 풀이 기록과 오답노트를 모아 약한 유형을 찾아요.")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                VStack(spacing: 0) {
                    NavigationLink { WeakConceptListView() } label: {
                        RowLabel(symbol: "target", title: L("오답노트 취약 개념"), subtitle: L("개념별 오답 횟수·원인·숙련도"))
                    }
                    .buttonStyle(.pressable)
                    RowDivider()
                    NavigationLink { MockExamView() } label: {
                        RowLabel(symbol: "doc.text", title: L("AI 모의고사"), subtitle: L("취약 개념 10문제"))
                    }
                    .buttonStyle(.pressable)
                }
                .softCardBackground()
                if list.isEmpty {
                    EmptyStateView(symbol: "target", title: L("아직 취약 유형이 없어요"))
                        .softCard()
                        .appearAnimation()
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                    weaknessCard(item)
                        .appearAnimation(delay: Double(index) * 0.05)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("취약 유형 맞춤 학습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weaknessCard(_ item: Weakness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.unit)
                    .font(.pt(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(item.subject.loc)
                    .font(.pt(.caption2).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.cardInset, in: .rect(cornerRadius: Radius.chip, style: .continuous))
            }
            if item.total > 0 || item.wrongNotes > 0 {
                HStack(spacing: 16) {
                    if item.total > 0 { StatusText(text: L("정답률 \(Int(item.accuracy * 100))%"), color: .secondary).monospacedDigit() }
                    if item.wrongNotes > 0 { StatusText(text: L("오답노트 \(item.wrongNotes)"), color: Palette.danger).monospacedDigit() }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.headline)
                    .font(.pt(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.plan)
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Hairline()
            levelBar(item.level)
            Text("맞춤 학습 예상 시간 \(TimeText.durationL(minutes: item.minutes))")
                .font(.pt(.footnote))
                .foregroundStyle(.secondary)

            NavigationLink {
                UnitStudyView(subject: item.subject, unit: item.unit, initialStep: item.startStep)
            } label: {
                Text("이 맞춤 학습 시작하기")
            }
            .buttonStyle(.flatProminent)
        }
        .softCard()
    }

    private func levelBar(_ level: Int) -> some View {
        let labels = [L("개념이해 전"), L("실전활용 가능"), L("고난도 정복")]
        let current = (Double(level) + 0.5) / 3
        let target = min(1, (Double(level) + 1.5) / 3)
        return VStack(spacing: 8) {
            HStack {
                Text("현재 내 실력은?").font(.pt(.footnote)).foregroundStyle(.secondary)
                Spacer()
                Text("예상 도달: \(labels[min(level + 1, 2)])")
                    .font(.pt(.footnote).weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            LevelFillBar(current: current, target: target)
                .frame(height: 3)
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.pt(.caption2).weight(index == level ? .semibold : .regular))
                        .foregroundStyle(index == level ? Palette.ink : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// 실력 막대: 얇은 줄, 처음 보일 때 왼쪽부터 차오름
private struct LevelFillBar: View {
    let current: Double
    let target: Double
    @State private var filled = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.secondaryFill)
                Rectangle().fill(Theme.accent.opacity(0.3)).frame(width: geo.size.width * (filled ? target : 0))
                Rectangle().fill(Theme.accent).frame(width: geo.size.width * (filled ? current : 0))
            }
            .clipShape(.capsule)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { filled = true }
        }
    }
}
