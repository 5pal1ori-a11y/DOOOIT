import SwiftData
import SwiftUI

// AI 오답노트 학습 순서: ① 인식 확인 → ② 채점 → ③ 오답 원인 → ④ 풀이 → ⑤ 유사 문제 단계 학습 → ⑥ 재도전 · 취약 개념

/// 학습 단계 머리말 (번호 + 제목)
struct FlowHeader: View {
    let number: Int
    let title: String
    let symbol: String
    var trailing: String? = nil
    var trailingColor: Color = Theme.accent

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AccentGradient.linear, in: .circle)
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            if let trailing { TagLabel(text: trailing, color: trailingColor) }
        }
    }
}

// MARK: - ① AI가 인식한 문제 (확인 전에는 확정하지 않음)

struct ProblemReviewCard: View {
    @Bindable var note: MathNote
    var onEdit: () -> Void

    private var scan: ProblemScan { note.scan ?? DoitProblemScan.scan(note.recognizedText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowHeader(number: 1, title: "AI가 인식한 문제", symbol: "text.viewfinder",
                       trailing: note.isRecognitionConfirmed ? "확인됨" : "확인 전",
                       trailingColor: note.isRecognitionConfirmed ? Palette.success : Palette.warning)

            if note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("아직 문제가 없어요. 위의 \"고치기\"를 눌러 문제를 직접 적어 주세요.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                if scan.hasDoubts { doubtsBox }
                if !scan.question.isEmpty { row("묻는 것", scan.question, symbol: "questionmark.circle", color: Theme.accent) }
                if !scan.conditions.isEmpty { row("조건", scan.conditions.joined(separator: "\n"), symbol: "exclamationmark.triangle", color: Palette.warning) }
                if !scan.formulas.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("수식").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        FlowLayoutChips(items: scan.formulas.map(MathSymbolBar.pretty))
                    }
                }
                if !scan.choices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("선택지 \(scan.choices.count)개").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        ForEach(Array(scan.choices.enumerated()), id: \.offset) { index, choice in
                            Text("\(index + 1)) \(MathSymbolBar.pretty(choice))").font(.subheadline)
                        }
                    }
                }
                if !scan.table.isEmpty { tableView(scan.table) }
                if let graph = scan.graphNote { row("그래프", graph, symbol: "chart.xyaxis.line", color: Theme.accent) }
                kindPicker
            }

            if !note.isRecognitionConfirmed {
                Text("인식 결과가 사진과 같은지 확인해 주세요. 확인하기 전에는 채점·풀이를 하지 않아요. 이미지에서 보이지 않는 내용은 AI가 채우지 않아요.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Label("고치기", systemImage: "pencil").frame(maxWidth: .infinity).frame(height: 36)
                    }
                    .buttonStyle(.glass)
                    Button {
                        withAnimation(.snappy) { note.isRecognitionConfirmed = true }
                        if note.kindRaw.isEmpty { note.kind = scan.kind }
                        if note.correctAnswer.isEmpty, let printed = scan.printedAnswer { note.correctAnswer = printed }
                        Haptics.success()
                    } label: {
                        Label("이대로 확정", systemImage: "checkmark").frame(maxWidth: .infinity).frame(height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button {
                    withAnimation(.snappy) { note.isRecognitionConfirmed = false }
                } label: {
                    Label("인식 결과 다시 확인하기", systemImage: "arrow.uturn.backward").font(.caption.weight(.semibold))
                }
            }
        }
        .softCard()
    }

    private var doubtsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("확실하지 않은 부분이 있어요", systemImage: "exclamationmark.bubble.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.warning)
            ForEach(scan.doubts, id: \.self) { doubt in
                VStack(alignment: .leading, spacing: 1) {
                    Text(MathSymbolBar.pretty(doubt.text)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(doubt.reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("사진을 다시 찍거나 \"고치기\"로 바로잡아 주세요.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warning.opacity(0.1), in: .rect(cornerRadius: 14))
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("문제 유형 (채점 방법)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Picker("문제 유형", selection: Binding(get: { note.kind ?? scan.kind }, set: { note.kind = $0 })) {
                ForEach(ProblemKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func row(_ title: String, _ text: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(MathSymbolBar.pretty(text)).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tableView(_ rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("표").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    GridRow {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            Text(cell).font(index == 0 ? .caption.weight(.bold) : .caption)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 12))
        }
    }
}

/// 가로로 감싸 놓는 작은 칩들
struct FlowLayoutChips: View {
    let items: [String]
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(.subheadline, design: .serif))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.08), in: .capsule)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - ② 채점 (문제 유형별)

struct MistakeGradingCard: View {
    @Bindable var note: MathNote
    var onNeedConfirm: () -> Void
    @Environment(\.modelContext) private var context

    private var kind: ProblemKind { note.kind ?? note.scan?.kind ?? .shortAnswer }
    private var choices: [String] { note.scan?.choices ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowHeader(number: 2, title: "채점", symbol: "checkmark.seal", trailing: note.grade?.verdict.title,
                       trailingColor: color(note.grade?.verdict))
            if !note.isRecognitionConfirmed {
                lockedView
            } else {
                Text("\(kind.title) 문제예요. " + hint).font(.caption).foregroundStyle(.secondary)
                answerInputs
                Button(action: grade) {
                    Label(note.grade == nil ? "채점하기" : "다시 채점하기", systemImage: "checkmark").frame(maxWidth: .infinity).frame(height: 38)
                }
                .buttonStyle(.glassProminent)
                .disabled(note.myAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                if let result = note.grade { resultView(result) }
            }
        }
        .softCard()
    }

    private var hint: String {
        switch kind {
        case .multipleChoice: return "고른 번호를 누르면 선택지로 자동 채점해요."
        case .shortAnswer: return "띄어쓰기·기호는 무시하고, 정답이 여러 개면 | 로 나눠 적어요."
        case .math: return "0.5 = 1/2, 해의 순서, 같은 식의 다른 모양도 같은 답으로 봐요. 정답을 비우면 직접 풀어서 확인해요."
        case .essay: return "모범 답안의 핵심 내용이 들어 있는지로 부분 점수를 매기고, 최종 결과는 직접 확인해요."
        }
    }

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("먼저 인식한 문제를 확인해 주세요", systemImage: "lock.fill").font(.subheadline.weight(.semibold))
            Text("잘못 읽은 문제로 채점·풀이하지 않도록, 문제 탭에서 인식 결과를 확인한 뒤에 채점해요.").font(.caption).foregroundStyle(.secondary)
            Button("문제 확인하러 가기", action: onNeedConfirm).font(.subheadline.weight(.bold))
        }
    }

    @ViewBuilder
    private var answerInputs: some View {
        if kind == .multipleChoice, !choices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("내 답").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(1...max(choices.count, 1), id: \.self) { number in
                        let picked = DoitGrader.choiceNumber(note.myAnswer, choices: choices) == number
                        Button { note.myAnswer = "\(number)"; Haptics.tap() } label: {
                            Text("\(number)")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(picked ? .white : Palette.ink)
                                .background(picked ? AnyShapeStyle(AccentGradient.linear) : AnyShapeStyle(Color.primary.opacity(0.06)), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else if kind == .essay {
            field("내 답", text: $note.myAnswer, axis: .vertical, placeholder: "내가 쓴 답")
        } else {
            field("내 답", text: $note.myAnswer, placeholder: "풀이 후 답을 입력")
        }
        field(kind == .essay ? "모범 답안" : "정답", text: $note.correctAnswer, axis: kind == .essay ? .vertical : .horizontal,
              placeholder: kind == .essay ? "모범 답안이나 채점 기준 (핵심 내용)" : (kind == .math ? "비우면 두잇이 직접 풀어서 확인" : "정답 (여러 개면 | 로 구분)"))
    }

    private func field(_ title: String, text: Binding<String>, axis: Axis = .horizontal, placeholder: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).frame(width: 58, alignment: .leading)
            TextField(placeholder, text: text, axis: axis)
                .lineLimit(axis == .vertical ? 2...6 : 1...1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
    }

    private func resultView(_ result: GradeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(result.verdict.title, systemImage: symbol(result.verdict))
                    .font(.headline)
                    .foregroundStyle(color(result.verdict))
                if result.verdict == .partial { Text("\(Int((result.score * 100).rounded()))점").font(.subheadline.weight(.bold)) }
                Spacer()
            }
            ForEach(result.reasons, id: \.self) { reason in
                Text(MathSymbolBar.pretty(reason)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Text("채점 방법: \(result.method)" + (result.answerSource.isEmpty ? "" : " · 정답: \(result.answerSource)"))
                .font(.caption2).foregroundStyle(.secondary)
            if result.verdict == .needsReview || result.verdict == .partial {
                Text(result.verdict == .needsReview ? "두잇이 확실하게 채점할 수 없었어요. 직접 골라 주세요." : "부분 정답이에요. 최종 결과를 골라 주세요.")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 10) {
                    confirmButton("맞았어요", correct: true)
                    confirmButton("틀렸어요", correct: false)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(result.verdict).opacity(0.08), in: .rect(cornerRadius: 16))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func confirmButton(_ title: String, correct: Bool) -> some View {
        Button {
            guard var result = note.grade else { return }
            result.verdict = correct ? .correct : .wrong
            result.score = correct ? 1 : result.score
            result.method += " · 직접 확인"
            finish(result)
        } label: {
            Text(title).font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(correct ? Palette.success : Palette.danger, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func grade() {
        let result = DoitGrader.grade(.init(kind: kind, student: note.myAnswer, answerKey: note.correctAnswer,
                                            choices: choices, problem: note.scan?.body ?? note.recognizedText))
        if result.verdict == .needsReview || (kind == .essay) {
            withAnimation(.snappy) { note.grade = result }
            return
        }
        finish(result)
    }

    /// 채점이 정해지면: 상태 저장 → (오답이면) 원인 분석 → 취약 개념 기록
    private func finish(_ result: GradeResult) {
        withAnimation(.snappy) {
            note.grade = result
            note.status = result.verdict == .correct ? .correct : .wrong
        }
        note.updatedAt = Date()
        var cause: String?
        if result.verdict == .wrong || result.verdict == .partial {
            let work = note.workCheckData.flatMap { try? JSONDecoder().decode(DoitWorkChecker.Report.self, from: $0) }
            let analysis = DoitMistake.analyze(.init(problem: note.scan?.body ?? note.recognizedText, kind: kind, student: note.myAnswer, grade: result,
                                                     choices: choices, conditions: note.scan?.conditions ?? [], work: work))
            note.analysis = analysis
            cause = analysis?.cause.rawValue
            Haptics.error()
        } else {
            note.analysis = nil
            Haptics.success()
        }
        WeakConceptStore.recordGrade(note: note, correct: result.verdict == .correct, source: "오답노트", cause: cause, context: context)
    }

    private func color(_ verdict: GradeResult.Verdict?) -> Color {
        switch verdict {
        case .correct?: return Palette.success
        case .wrong?: return Palette.danger
        case .partial?, .needsReview?: return Palette.warning
        case nil: return Theme.accent
        }
    }

    private func symbol(_ verdict: GradeResult.Verdict) -> String {
        switch verdict {
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .needsReview: return "questionmark.circle.fill"
        }
    }
}

// MARK: - ③ 오답 원인 분석

struct MistakeAnalysisCard: View {
    @Bindable var note: MathNote

    var body: some View {
        if let analysis = note.analysis {
            VStack(alignment: .leading, spacing: 12) {
                FlowHeader(number: 3, title: "왜 틀렸을까?", symbol: "magnifyingglass", trailing: analysis.certainty.rawValue,
                           trailingColor: analysis.certainty == .confirmed ? Palette.success : (analysis.certainty == .estimated ? Palette.warning : .secondary))
                HStack(spacing: 8) {
                    Text(analysis.cause.rawValue)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(analysis.cause == .unknown ? .secondary : Palette.danger)
                    if analysis.certainty == .estimated { Text("(추정)").font(.caption).foregroundStyle(.secondary) }
                }
                Text(analysis.explanation).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                if !analysis.evidence.isEmpty {
                    section("근거", items: analysis.evidence, symbol: "doc.text.magnifyingglass")
                }
                if !analysis.missedConcepts.isEmpty {
                    section("놓친 핵심 개념", items: analysis.missedConcepts, symbol: "lightbulb")
                }
                if !analysis.direction.isEmpty {
                    section("올바른 풀이 방향", items: [analysis.direction], symbol: "arrow.triangle.turn.up.right.diamond")
                }
                if !analysis.review.isEmpty { section("추천 복습", items: analysis.review, symbol: "book") }
                if !analysis.next.isEmpty { section("다음 학습", items: analysis.next, symbol: "flag.checkered") }
            }
            .softCard()
        }
    }

    private func section(_ title: String, items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Text("• " + MathSymbolBar.pretty(item)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - ⑥ 취약 개념 상태

struct WeakConceptBadge: View {
    let note: MathNote
    @Query private var concepts: [WeakConcept]

    private var concept: WeakConcept? { concepts.first { $0.key == note.conceptKey } }

    var body: some View {
        if let concept {
            NavigationLink { WeakConceptListView() } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("이 문제의 개념: \(concept.concept)", systemImage: "scope").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        Spacer()
                        TagLabel(text: concept.state.rawValue, color: stateColor(concept.state))
                    }
                    MasteryBar(value: concept.mastery)
                    Text("오답 \(concept.wrongCount)회 · 풀이 \(concept.attemptCount)회 · 최근 \(concept.lastStudiedAt.kr("M월 d일"))"
                         + (concept.mainCause.map { " · 주된 원인 \($0)" } ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(concept.state == .mastered ? "여러 날에 걸쳐 연속으로 맞혀서 익힌 개념이에요." : "한 번 맞혔다고 끝이 아니에요. 다른 날 다시 풀어서 확인해요.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .softCard()
            }
            .buttonStyle(.plain)
        }
    }
}

struct MasteryBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(AccentGradient.linear).frame(width: geo.size.width * min(max(value, 0.02), 1))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("숙련도 \(Int(value * 100))%")
    }
}

func stateColor(_ state: DoitMastery.State) -> Color {
    switch state {
    case .weak: return Palette.danger
    case .practicing: return Palette.warning
    case .almost: return Theme.accent
    case .mastered: return Palette.success
    }
}

/// 취약 개념 모아 보기
struct WeakConceptListView: View {
    @Query(sort: \WeakConcept.mastery) private var concepts: [WeakConcept]
    @State private var onlyWeak = true

    private var shown: [WeakConcept] { onlyWeak ? concepts.filter { $0.isWeak || $0.state != .mastered } : concepts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("보기", selection: $onlyWeak) {
                    Text("연습할 개념").tag(true)
                    Text("전체").tag(false)
                }
                .pickerStyle(.segmented)
                if shown.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal", title: "연습할 개념이 없어요", message: "오답노트에서 채점하면 개념별로 모아 드려요.")
                        .softCard()
                }
                ForEach(shown) { concept in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(concept.concept).font(.headline).foregroundStyle(Palette.ink)
                                Text([concept.subject, concept.unit, concept.problemType].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TagLabel(text: concept.state.rawValue, color: stateColor(concept.state))
                        }
                        MasteryBar(value: concept.mastery)
                        Text("숙련도 \(Int(concept.mastery * 100))% · 오답 \(concept.wrongCount)회 · 최근 \(concept.lastStudiedAt.kr("M월 d일"))"
                             + (concept.mainCause.map { " · \($0)" } ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                        if let last = concept.records.last {
                            Text("마지막 풀이: \(last.source) \(last.level)단계 \(last.correct ? "정답" : "오답")").font(.caption2).foregroundStyle(.secondary)
                        }
                        if DoitStudy.catalog.contains(where: { $0.subjectName == concept.subject && $0.unit == concept.unit }) {
                            NavigationLink {
                                UnitStudyView(subject: concept.subject, unit: concept.unit)
                            } label: {
                                Label("AI 학습에서 개념 다시 보기", systemImage: "book.pages").font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .softCard()
                }
            }
            .padding(20)
        }
        .background { AppBackground() }
        .navigationTitle("취약 개념")
        .navigationBarTitleDisplayMode(.inline)
    }
}
