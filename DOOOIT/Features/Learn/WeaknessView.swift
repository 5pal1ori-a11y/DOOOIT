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
            VStack(alignment: .leading, spacing: 18) {
                Text("빈칸·O/X·문제 풀이 기록과 오답노트를 모아 약한 유형을 찾아요.")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                NavigationLink { WeakConceptListView() } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "target", color: Palette.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("오답노트 취약 개념").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.ink)
                            Text("개념별 오답 횟수·원인·숙련도").font(.pt(.caption)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.pt(.footnote)).foregroundStyle(.tertiary)
                    }
                    .softCard(cornerRadius: 20, padding: 14)
                }
                .buttonStyle(.pressable)
                NavigationLink { MockExamView() } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "doc.text", color: Palette.sky)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI 모의고사").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.ink)
                            Text("취약 개념 10문제").font(.pt(.caption)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.pt(.footnote)).foregroundStyle(.tertiary)
                    }
                    .softCard(cornerRadius: 20, padding: 14)
                }
                .buttonStyle(.pressable)
                if list.isEmpty {
                    EmptyStateView(symbol: "target", title: L("아직 취약 유형이 없어요"))
                        .softCard()
                        .appearAnimation()
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                    weaknessCard(item)
                        .appearAnimation(delay: Double(index) * 0.07)
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
                if item.total > 0 { TagLabel(text: L("정답률 \(Int(item.accuracy * 100))%"), color: Theme.accent) }
                if item.wrongNotes > 0 { TagLabel(text: L("오답노트 \(item.wrongNotes)"), color: Palette.danger) }
            }
            Label(item.unit, systemImage: "sparkles").font(.pt(.headline)).foregroundStyle(Theme.accent)
            Text("\(item.headline)\n\(item.plan)")
                .font(.pt(.title3).weight(.bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("맞춤 학습 예상 시간 \(TimeText.durationL(minutes: item.minutes))")
                .font(.pt(.caption))
                .foregroundStyle(.secondary)

            levelBar(item.level)

            NavigationLink {
                UnitStudyView(subject: item.subject, unit: item.unit, initialStep: item.startStep)
            } label: {
                Text("이 맞춤 학습 시작하기")
                    .font(.pt(.body).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .softCard(cornerRadius: 24, padding: 20)
    }

    private func levelBar(_ level: Int) -> some View {
        let labels = [L("개념이해 전"), L("실전활용 가능"), L("고난도 정복")]
        let current = (Double(level) + 0.5) / 3
        let target = min(1, (Double(level) + 1.5) / 3)
        return VStack(spacing: 6) {
            HStack {
                Text("현재 내 실력은?").font(.pt(.caption)).foregroundStyle(.secondary)
                Spacer()
                Label("예상 도달: \(labels[min(level + 1, 2)])", systemImage: "sparkles")
                    .font(.pt(.caption).weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            LevelFillBar(current: current, target: target)
                .frame(height: 10)
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.pt(.caption2).weight(index == level ? .bold : .regular))
                        .foregroundStyle(index == level ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Theme.accent.opacity(0.05), in: .rect(cornerRadius: 16))
    }
}

/// 실력 막대: 처음 보일 때 왼쪽부터 차오름
private struct LevelFillBar: View {
    let current: Double
    let target: Double
    @State private var filled = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(Theme.accent.opacity(0.25)).frame(width: geo.size.width * (filled ? target : 0))
                Capsule().fill(AccentGradient.linear).frame(width: geo.size.width * (filled ? current : 0))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { filled = true }
        }
    }
}
