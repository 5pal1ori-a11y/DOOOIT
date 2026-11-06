import SwiftData
import SwiftUI

// AI 오답노트 학습 순서: ① 인식 확인 → ② 채점 → ③ 오답 원인 → ④ 풀이 → ⑤ 유사 문제 단계 학습 → ⑥ 재도전 · 취약 개념

/// 학습 단계 머리말: 글자 제목 + 오른쪽 작은 상태 글자 (아이콘·색 칸 없음)
struct FlowHeader: View {
    let number: Int
    let title: String
    let symbol: String
    var trailing: String? = nil
    var trailingColor: Color = Theme.accent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.pt(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            if let trailing {
                StatusText(text: trailing, color: trailingColor)
            }
        }
    }
}

/// 얇은 구분선 (0.5pt)
struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.line).frame(height: 0.5) }
}

/// 작은 상태 표시: 점 하나 + 회색 글자 (뜻 있는 색은 점에만). 긴 글은 lineLimit를 nil로
struct StatusText: View {
    let text: String
    var color: Color = Theme.accent
    var lineLimit: Int? = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if [Palette.success, Palette.danger, Palette.warning].contains(color) {
                Text(Image(systemName: "circle.fill"))
                    .font(.pt(size: 6))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.pt(.footnote))
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: lineLimit == nil)
        }
    }
}

/// 큰 숫자 + 작은 단위: 숫자는 34pt bold, 나머지(단위)는 15pt 회색 (번역된 글 그대로 나눔)
struct BigNumberText: View {
    let text: String
    var size: CGFloat = 36

    private var attributed: AttributedString {
        var result = AttributedString()
        for character in text {
            var piece = AttributedString(String(character))
            let isNumber = character.isNumber || character == "," || character == "." || character == "%"
            piece.font = isNumber ? Font.pt(size: size, weight: .bold).monospacedDigit() : Font.pt(size: 15)
            piece.foregroundColor = isNumber ? Palette.ink : Color.secondary
            result.append(piece)
        }
        return result
    }

    var body: some View {
        Text(attributed).lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// 카드 안 작은 라벨 (회색 13pt)
struct FlowLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.pt(.footnote)).foregroundStyle(.secondary)
    }
}

/// 카드 안 버튼: 회색 칸(기본) / 강조색 칸(주요). 높이 44, 반지름 14, 누르면 투명도만
struct FlatButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pt(.subheadline).weight(.semibold))
            .foregroundStyle(prominent ? Theme.onAccent : Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(prominent ? Theme.accent : Theme.secondaryFill, in: .rect(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    static var flat: FlatButtonStyle { FlatButtonStyle() }
    static var flatProminent: FlatButtonStyle { FlatButtonStyle(prominent: true) }
}

extension View {
    /// 입력칸: 옅은 회색 면, 반지름 10
    func flatField(horizontal: CGFloat = 12, vertical: CGFloat = 10) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
    }
}

// MARK: - ① AI가 인식한 문제 (확인 전에는 확정하지 않음)

struct ProblemReviewCard: View {
    @Bindable var note: MathNote
    var onEdit: () -> Void

    private var scan: ProblemScan { note.scan ?? DoitProblemScan.scan(note.recognizedText, math: note.subjectKind.isMath) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowHeader(number: 1, title: L("AI가 인식한 문제"), symbol: "text.viewfinder",
                       trailing: note.isRecognitionConfirmed ? L("확인됨") : L("확인 전"),
                       trailingColor: note.isRecognitionConfirmed ? Palette.success : Palette.warning)

            if note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("아직 문제가 없어요. 위의 \"고치기\"를 눌러 문제를 직접 적어 주세요.")
                    .font(.pt(.subheadline)).foregroundStyle(.secondary)
            } else {
                if scan.hasDoubts { doubtsBox }
                if !scan.question.isEmpty { row(L("묻는 것"), scan.question) }
                if !scan.conditions.isEmpty { row(L("조건"), scan.conditions.joined(separator: "\n")) }
                if !scan.formulas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        FlowLabel(L("수식"))
                        FlowLayoutChips(items: scan.formulas.map(MathSymbolBar.pretty))
                    }
                }
                if !scan.choices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        FlowLabel(L("선택지 \(scan.choices.count)개"))
                        ForEach(Array(scan.choices.enumerated()), id: \.offset) { index, choice in
                            Text("\(index + 1)) \(MathSymbolBar.pretty(choice))").font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                        }
                    }
                }
                if !scan.table.isEmpty { tableView(scan.table) }
                if let graph = scan.graphNote { row(L("그래프"), graph) }
                if let lines = scan.figureLines, !lines.isEmpty { FigureFactsBox(note: note, lines: lines) }
                kindPicker
            }

            if !note.isRecognitionConfirmed {
                Text("인식 결과가 사진과 같은지 확인해 주세요. 확인하기 전에는 채점·풀이를 하지 않아요. 이미지에서 보이지 않는 내용은 AI가 채우지 않아요.")
                    .font(.pt(.footnote)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Label("고치기", systemImage: "pencil")
                    }
                    .buttonStyle(.flat)
                    Button {
                        withAnimation(.snappy) { note.isRecognitionConfirmed = true }
                        if note.kindRaw.isEmpty { note.kind = scan.kind }
                        if note.correctAnswer.isEmpty, let printed = scan.printedAnswer { note.correctAnswer = printed }
                        Haptics.success()
                    } label: {
                        Label("이대로 확정", systemImage: "checkmark")
                    }
                    .buttonStyle(.flatProminent)
                    .disabled(note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button {
                    withAnimation(.snappy) { note.isRecognitionConfirmed = false }
                } label: {
                    Text("인식 결과 다시 확인하기").font(.pt(.footnote).weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
        }
        .softCard()
    }

    private var doubtsBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusText(text: L("확실하지 않은 부분이 있어요"), color: Palette.warning)
            ForEach(scan.doubts, id: \.self) { doubt in
                VStack(alignment: .leading, spacing: 2) {
                    Text(MathSymbolBar.pretty(doubt.text)).font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(doubt.reason).font(.pt(.footnote)).foregroundStyle(.secondary)
                }
            }
            Text("사진을 다시 찍거나 \"고치기\"로 바로잡아 주세요.").font(.pt(.caption2)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLabel(L("문제 유형 (채점 방법)"))
            Picker("문제 유형", selection: Binding(get: { note.kind ?? scan.kind }, set: { note.kind = $0 })) {
                // 수학이 아닌 과목은 '수학 계산' 채점이 없음
                ForEach(ProblemKind.allCases.filter { note.subjectKind.isMath || $0 != .math }) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func row(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FlowLabel(title)
            Text(MathSymbolBar.pretty(text)).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableView(_ rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLabel(L("표"))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    GridRow {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            Text(cell).font(.pt(.footnote).weight(index == 0 ? .semibold : .regular)).foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            .padding(10)
            .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
        }
    }
}

/// 그림·그래프·표에서 읽은 것 (기계가 읽은 값): 확정 전에는 한 줄씩 고치거나 지움
struct FigureFactsBox: View {
    @Bindable var note: MathNote
    let lines: [String]
    @State private var editing: Int?
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var locked: Bool { note.isRecognitionConfirmed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                FlowLabel(L("\(DoitFigureFacts.title(lines))에서 읽음"))
                Spacer(minLength: 0)
                if !locked { StatusText(text: L("사진과 같은지 확인"), color: Palette.warning) }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if editing == index {
                    HStack(spacing: 8) {
                        TextField("읽은 값", text: $draft)
                            .font(.pt(.subheadline))
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit { commit(index) }
                        Button("완료") { commit(index) }.font(.pt(.footnote).weight(.semibold))
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(MathSymbolBar.pretty(line)).font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if !locked {
                            Button { draft = line; editing = index; focused = true } label: { Image(systemName: "pencil") }
                                .accessibilityLabel("고치기")
                            Button { save(lines.enumerated().filter { $0.offset != index }.map(\.element)) } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("지우기")
                        }
                    }
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
    }

    private func commit(_ index: Int) {
        var next = lines
        let text = draft.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { next.remove(at: index) } else { next[index] = GeometryText.canonical(text) }
        editing = nil
        save(next)
    }

    /// 문제 글의 블록과 나눈 결과를 함께 바꿈 (다른 인식 결과·불확실 표시는 그대로)
    private func save(_ next: [String]) {
        note.recognizedText = DoitFigureFacts.replacing(note.recognizedText, with: next)
        var scan = note.scan ?? DoitProblemScan.scan(note.recognizedText, math: note.subjectKind.isMath)
        scan.figureLines = next.isEmpty ? nil : next
        scan.body = DoitFigureFacts.replacing(scan.body, with: next)
        note.scan = scan
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
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Palette.cardInset, in: .rect(cornerRadius: Radius.chip, style: .continuous))
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

    private var subject: NoteSubject { note.subjectKind }
    private var kind: ProblemKind {
        let k = note.kind ?? note.scan?.kind ?? .shortAnswer
        return !subject.isMath && k == .math ? .shortAnswer : k
    }
    private var choices: [String] { note.scan?.choices ?? [] }
    /// O/X로 답하는 문제 (수학이 아닌 과목)
    private var isOX: Bool { !subject.isMath && kind == .shortAnswer && DoitSubjectNote.isOXQuestion(note.recognizedText, answerKey: note.correctAnswer) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowHeader(number: 2, title: "내 답 채점", symbol: "checkmark.seal", trailing: note.grade?.verdict.title,
                       trailingColor: color(note.grade?.verdict))
            if !note.isRecognitionConfirmed {
                lockedView
            } else {
                Text(hint).font(.pt(.footnote)).foregroundStyle(.secondary)
                answerInputs
                Button(action: grade) {
                    Text(note.grade == nil ? L("채점하기") : L("다시 채점하기"))
                }
                .buttonStyle(.flatProminent)
                .disabled(note.myAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                if let result = note.grade { resultView(result) }
            }
        }
        .softCard()
    }

    private var hint: String {
        if !subject.isMath {
            switch kind {
            case .multipleChoice: return L("고른 번호로 채점해요")
            case .essay: return L("핵심 내용으로 부분 점수를 매겨요")
            default: return isOX ? L("O·X로 채점해요") : (subject == .english ? L("대소문자·띄어쓰기·문장부호는 무시해요") : L("띄어쓰기·기호는 무시해요"))
            }
        }
        switch kind {
        case .multipleChoice: return L("고른 번호로 채점해요")
        case .shortAnswer: return L("띄어쓰기·기호는 무시해요")
        case .math: return L("0.5 = 1/2처럼 같은 값이면 정답이에요")
        case .essay: return L("핵심 내용으로 부분 점수를 매겨요")
        }
    }

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("문제 탭에서 읽은 문제를 먼저 확인해 주세요").font(.pt(.subheadline)).foregroundStyle(.secondary)
            Button("문제 확인하기", action: onNeedConfirm).buttonStyle(.flat)
        }
    }

    @ViewBuilder
    private var answerInputs: some View {
        if kind == .multipleChoice, !choices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                FlowLabel(L("내 답"))
                HStack(spacing: 8) {
                    ForEach(1...max(choices.count, 1), id: \.self) { number in
                        let picked = DoitGrader.choiceNumber(note.myAnswer, choices: choices) == number
                        Button { note.myAnswer = "\(number)"; Haptics.tap() } label: {
                            Text("\(number)")
                                .font(.pt(.headline))
                                .monospacedDigit()
                                .frame(width: 44, height: 44)
                                .foregroundStyle(picked ? Theme.onAccent : Palette.ink)
                                .background(picked ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.secondaryFill), in: .rect(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else if kind == .essay {
            field(L("내 답"), text: $note.myAnswer, axis: .vertical, placeholder: L("내가 쓴 답"))
        } else if isOX {
            HStack(spacing: 8) {
                FlowLabel(L("내 답"))
                ForEach(["O", "X"], id: \.self) { mark in
                    let picked = DoitSubjectNote.oxValue(note.myAnswer) == (mark == "O")
                    Button { note.myAnswer = mark; Haptics.tap() } label: {
                        Text(mark)
                            .font(.pt(.headline))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(picked ? Theme.onAccent : Palette.ink)
                            .background(picked ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.secondaryFill), in: .rect(cornerRadius: Radius.field, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            field(L("내 답"), text: $note.myAnswer, placeholder: L("풀이 후 답을 입력"))
        }
        field(kind == .essay ? L("모범 답안") : L("정답"), text: $note.correctAnswer, axis: kind == .essay ? .vertical : .horizontal,
              placeholder: kind == .essay ? L("모범 답안이나 채점 기준 (핵심 내용)") : (kind == .math ? L("비우면 모티가 직접 풀어서 확인") : (isOX ? L("O 또는 X") : L("정답 (여러 개면 | 로 구분)"))))
    }

    private func field(_ title: String, text: Binding<String>, axis: Axis = .horizontal, placeholder: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).font(.pt(.subheadline)).foregroundStyle(.secondary).frame(width: 58, alignment: .leading)
            TextField(placeholder, text: text, axis: axis)
                .lineLimit(axis == .vertical ? 2...6 : 1...1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .flatField(horizontal: 14, vertical: 12)
    }

    private func resultView(_ result: GradeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Hairline()
            HStack(spacing: 8) {
                Image(systemName: symbol(result.verdict))
                    .environment(\.symbolVariants, .none)
                    .font(.pt(size: 18, weight: .regular))
                    .foregroundStyle(color(result.verdict))
                Text(result.verdict.title)
                    .font(.pt(.headline))
                    .foregroundStyle(Palette.ink)
                if result.verdict == .partial {
                    Text("\(Int((result.score * 100).rounded()))점").font(.pt(.subheadline)).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
            }
            .padding(.top, 4)
            ForEach(result.reasons, id: \.self) { reason in
                Text(MathSymbolBar.pretty(reason)).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            Text(L("채점 방법: \(result.method)") + (result.answerSource.isEmpty ? "" : L(" · 정답: \(result.answerSource)")))
                .font(.pt(.caption2)).foregroundStyle(.secondary)
            if result.verdict == .needsReview || result.verdict == .partial {
                Text(result.verdict == .needsReview ? L("모티가 확실하게 채점할 수 없었어요. 직접 골라 주세요.") : L("부분 정답이에요. 최종 결과를 골라 주세요."))
                    .font(.pt(.footnote).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    confirmButton(L("맞았어요"), correct: true)
                    confirmButton(L("틀렸어요"), correct: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    private func confirmButton(_ title: String, correct: Bool) -> some View {
        Button {
            guard var result = note.grade else { return }
            result.verdict = correct ? .correct : .wrong
            result.score = correct ? 1 : result.score
            result.method += L(" · 직접 확인")
            finish(result)
        } label: {
            Text(title)
        }
        .buttonStyle(.flat)
    }

    private func grade() {
        let result = DoitGrader.grade(.init(kind: kind, student: note.myAnswer, answerKey: note.correctAnswer,
                                            choices: choices, problem: note.scan?.body ?? note.recognizedText, subject: subject))
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
                                                     choices: choices, conditions: note.scan?.conditions ?? [], work: work, subject: subject))
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
                FlowHeader(number: 3, title: "왜 틀렸을까?", symbol: "magnifyingglass", trailing: analysis.certainty.rawValue.loc,
                           trailingColor: analysis.certainty == .confirmed ? Palette.success : (analysis.certainty == .estimated ? Palette.warning : .secondary))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(analysis.cause.rawValue.loc)
                        .font(.pt(.title3).weight(.bold))
                        .foregroundStyle(analysis.cause == .unknown ? Color.secondary : Palette.ink)
                    if analysis.certainty == .estimated { Text("(추정)").font(.pt(.footnote)).foregroundStyle(.secondary) }
                }
                Text(analysis.explanation).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                if !analysis.missedConcepts.isEmpty {
                    Hairline()
                    section(L("놓친 개념"), items: analysis.missedConcepts, symbol: "lightbulb")
                }
                // 근거·풀이 방향·복습은 펼쳐서
                if !analysis.evidence.isEmpty || !analysis.direction.isEmpty || !analysis.review.isEmpty || !analysis.next.isEmpty {
                    DisclosureGroup(L("자세히")) {
                        VStack(alignment: .leading, spacing: 12) {
                            if !analysis.evidence.isEmpty { section(L("근거"), items: analysis.evidence, symbol: "newspaper.fill") }
                            if !analysis.direction.isEmpty { section(L("풀이 방향"), items: [analysis.direction], symbol: "arrow.turn.up.right") }
                            if !analysis.review.isEmpty { section(L("복습"), items: analysis.review, symbol: "book") }
                            if !analysis.next.isEmpty { section(L("다음 학습"), items: analysis.next, symbol: "flag.checkered") }
                        }
                        .padding(.top, 6)
                    }
                    .font(.pt(.subheadline).weight(.semibold))
                    .tint(Theme.secondary)
                }
            }
            .softCard()
        }
    }

    private func section(_ title: String, items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            FlowLabel(title)
            ForEach(items, id: \.self) { item in
                Text("• " + MathSymbolBar.pretty(item)).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("이 문제의 개념: \(concept.concept)").font(.pt(size: 17, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                        Spacer(minLength: 8)
                        StatusText(text: concept.state.rawValue.loc, color: stateColor(concept.state))
                        Image(systemName: "chevron.right").font(.pt(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    MasteryBar(value: concept.mastery)
                    Text("오답 \(concept.wrongCount)회 · 풀이 \(concept.attemptCount)회 · 최근 \(concept.lastStudiedAt.ui("M월 d일"))"
                         + (concept.mainCause.map { L(" · 주된 원인 \($0)") } ?? ""))
                        .font(.pt(.footnote)).foregroundStyle(.secondary)
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
        // 얇은 1pt 줄: 회색 바탕 줄 위에 강조색 줄
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.secondaryFill)
                Rectangle().fill(Theme.accent).frame(width: geo.size.width * min(max(value, 0.02), 1))
            }
        }
        .frame(height: 2)
        .clipShape(.capsule)
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
            VStack(alignment: .leading, spacing: 12) {
                PillSegmentedControl(items: [true, false], selection: $onlyWeak) { $0 ? L("연습할 개념") : L("전체") }
                if shown.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal", title: L("연습할 개념이 없어요"))
                        .softCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, concept in
                            conceptRow(concept)
                            if index < shown.count - 1 { Hairline().padding(.leading, 16) }
                        }
                    }
                    .softCardBackground()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("취약 개념")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func conceptRow(_ concept: WeakConcept) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(concept.concept).font(.pt(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text([concept.subject, concept.unit, concept.problemType].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.pt(.footnote)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                StatusText(text: concept.state.rawValue.loc, color: stateColor(concept.state))
            }
            MasteryBar(value: concept.mastery)
            Text("숙련도 \(Int(concept.mastery * 100))% · 오답 \(concept.wrongCount)회 · 최근 \(concept.lastStudiedAt.ui("M월 d일"))"
                 + (concept.mainCause.map { " · \($0)" } ?? ""))
                .font(.pt(.footnote)).foregroundStyle(.secondary).monospacedDigit()
            if let last = concept.records.last {
                Text("마지막 풀이: \(last.source.loc) \(last.level)단계 \(last.correct ? L("정답") : L("오답"))").font(.pt(.caption2)).foregroundStyle(.secondary)
            }
            if DoitStudy.catalog.contains(where: { $0.subjectName == concept.subject && $0.unit == concept.unit }) {
                NavigationLink {
                    UnitStudyView(subject: concept.subject, unit: concept.unit)
                } label: {
                    HStack(spacing: 4) {
                        Text("AI 학습에서 개념 다시 보기")
                        Image(systemName: "chevron.right").font(.pt(.caption2).weight(.semibold))
                    }
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
