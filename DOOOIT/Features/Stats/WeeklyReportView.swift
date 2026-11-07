import Charts
import SwiftData
import SwiftUI

/// 주간 AI 리포트 화면: 큰 공부 시간 하나 + 날마다 막대 + 숫자 표 + 과목 표 + 다음 주 (헤어라인 카드, 강조색은 오늘·최고에만)
struct WeeklyReportView: View {
    @Environment(\.modelContext) private var context
    @State private var report: WeeklyReport?
    @State private var aiComment: String?
    @State private var addedPlans = false
    @State private var chartShown = false

    var body: some View {
        ScrollView {
            if let report {
                // 한눈에: 공부 시간 + 날마다 → 숫자 표 → 한마디(잘한 점 포함) → 과목 → 다음 주(조언 + 추천 플랜) → 단원 실력
                VStack(alignment: .leading, spacing: 24) {
                    hero(report).appearAnimation(delay: 0)
                    numbers(report).appearAnimation(delay: 0.04)
                    summaryCard(report).appearAnimation(delay: 0.08)
                    if !report.subjects.isEmpty { subjects(report).appearAnimation(delay: 0.12) }
                    if !report.advice.isEmpty || !report.nextWeek.isEmpty { nextWeekCard(report).appearAnimation(delay: 0.16) }
                    if !report.weakUnits.isEmpty || !report.strongUnits.isEmpty { units(report).appearAnimation(delay: 0.2) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("주간 AI 리포트")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard report == nil else { return }
            let made = WeeklyReportBuilder.build(context: context)
            withAnimation(Motion.spring) { report = made }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.5)) { chartShown = true }
            await loadComment(made)
        }
    }

    // MARK: 머리 카드 (큰 공부 시간 + 지난주 비교 + 날마다 막대)

    private func hero(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(r.start.ui("M월 d일")) ~ \(r.end.ui("M월 d일"))")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("이번 주 공부 시간")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(r.totalMinutes / 60)")
                        .font(.pt(size: 40, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(L("시간(단위)")).font(.pt(.subheadline)).foregroundStyle(.secondary)
                    Text("\(r.totalMinutes % 60)")
                        .font(.pt(size: 40, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.leading, 4)
                    Text("분").font(.pt(.subheadline)).foregroundStyle(.secondary)
                }
                .foregroundStyle(Palette.ink)
                if let change = r.change {
                    Text("지난주보다 \(change >= 0 ? "+" : "")\(Int((change * 100).rounded()))%")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("다음 주부터 지난주와 비교해 줘요")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
            Hairline()
            dailyChart(r)
            Hairline()
            HStack(spacing: 12) {
                StatColumn(value: L("\(r.studyDays)일"), label: L("공부한 날"))
                StatColumn(value: L("\(r.goalDays)일"), label: L("목표 달성"))
                StatColumn(value: L("\(r.streak)일"), label: L("연속 공부"))
            }
        }
        .softCard()
    }

    /// 날마다 막대: 회색 막대, 가장 많이 한 날과 오늘만 강조색, 목표는 가는 점선 하나
    private func dailyChart(_ r: WeeklyReport) -> some View {
        let best = r.dailyMinutes.map(\.minutes).max() ?? 0
        let top = max(best, r.goalMinutes, 1) * 6 / 5
        return Chart {
            ForEach(Array(r.dailyMinutes.enumerated()), id: \.offset) { _, item in
                let highlight = (best > 0 && item.minutes == best) || item.day.isSameDay(as: Date())
                BarMark(x: .value("요일", item.day.ui("E")), y: .value("분", chartShown ? item.minutes : 0))
                    .cornerRadius(3)
                    .foregroundStyle(highlight ? Theme.accent : Theme.secondary.opacity(0.45))
            }
            RuleMark(y: .value("목표", r.goalMinutes))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("목표 \(WeeklyReport.duration(r.goalMinutes))").font(.pt(.caption2)).foregroundStyle(.secondary).monospacedDigit()
                }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .font(.pt(.caption2))
        .frame(height: 150)
    }

    // MARK: 숫자 요약 (표처럼 한 줄씩)

    private func numbers(_ r: WeeklyReport) -> some View {
        let rows: [(title: String, value: String, detail: String, progress: Double?)] = [
            (L("플랜 완료"), r.planRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–", "\(r.planDone)/\(r.planTotal)", r.planRate),
            (L("문제 정답률"), r.quizRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
             r.quizTotal == 0 ? L("AI 학습 기록 없음") : "\(r.quizCorrect)/\(r.quizTotal)", r.quizRate),
            (L("단어"), L("\(r.wordsLearned)개"), L("외움 · 추가 \(r.wordsAdded)개"), nil),
            (L("오답노트"), L("\(r.notesAdded)문제"), L("이번 주 추가 · 남은 오답 \(r.notesWrong)"), nil)
        ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                numberRow(title: row.title, value: row.value, detail: row.detail, progress: row.progress)
                if index < rows.count - 1 { Hairline().padding(.leading, 16) }
            }
        }
        .softCardBackground()
    }

    private func numberRow(title: String, value: String, detail: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.pt(.body)).foregroundStyle(Palette.ink)
                    Text(detail).font(.pt(.footnote)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
                Spacer(minLength: 8)
                BigNumberText(text: value, size: 22)
                    .contentTransition(.numericText())
            }
            if let progress {
                thinBar(progress)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 얇은 줄 막대 (2pt)
    private func thinBar(_ value: Double, color: Color = Theme.accent) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.secondaryFill)
                Rectangle().fill(color).frame(width: chartShown ? proxy.size.width * CGFloat(min(max(value, 0), 1)) : 0)
            }
            .clipShape(.capsule)
        }
        .frame(height: 2)
    }

    // MARK: 한마디 (잘한 점 포함)

    private func summaryCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(L("이번 주 한마디"))
            VStack(alignment: .leading, spacing: 12) {
                if let aiComment {
                    Text(aiComment).font(.pt(.body)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(r.highlights.prefix(2).enumerated()), id: \.offset) { _, line in
                    Hairline()
                    Text(line)
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .softCard()
        }
    }

    // MARK: 과목별 (표)

    private func subjects(_ r: WeeklyReport) -> some View {
        let shown = Array(r.subjects.prefix(6))
        let maxMinutes = max(shown.map(\.minutes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(L("과목별 공부 시간"))
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, subject in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(subject.name.loc).font(.pt(.body)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            if subject.previousMinutes > 0 {
                                let diff = subject.minutes - subject.previousMinutes
                                Text(diff >= 0 ? L("+\(diff)분") : L("\(diff)분"))
                                    .font(.pt(.footnote))
                                    .foregroundStyle(diff >= 0 ? Palette.success : Palette.danger)
                                    .monospacedDigit()
                            }
                            Text(WeeklyReport.duration(subject.minutes))
                                .font(.pt(.body).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .monospacedDigit()
                                .frame(minWidth: 64, alignment: .trailing)
                        }
                        thinBar(Double(subject.minutes) / Double(maxMinutes), color: subject.minutes == maxMinutes ? Theme.accent : Theme.secondary.opacity(0.55))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if index < shown.count - 1 { Hairline().padding(.leading, 16) }
                }
            }
            .softCardBackground()
        }
    }

    // MARK: 다음 주 (조언 두 개 + 추천 플랜)

    private func nextWeekCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(L("다음 주에는"))
            VStack(alignment: .leading, spacing: 0) {
                let advice = Array(r.advice.prefix(2))
                ForEach(Array(advice.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.pt(.subheadline).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(line).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if index < advice.count - 1 || !r.nextWeek.isEmpty { Hairline().padding(.leading, 16) }
                }
                ForEach(Array(r.nextWeek.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppDateFormat.weekdayLabel(item.dayText))
                                .font(.pt(.subheadline).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(item.timeText).font(.pt(.caption2)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .frame(width: 64, alignment: .leading)
                        Text(item.title).font(.pt(.subheadline)).foregroundStyle(Palette.ink).lineLimit(2)
                        Spacer(minLength: 8)
                        Text("\(item.minutes)분").font(.pt(.footnote)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if index < r.nextWeek.count - 1 { Hairline().padding(.leading, 16) }
                }
            }
            .softCardBackground()
            if !r.nextWeek.isEmpty {
                Button {
                    for item in r.nextWeek {
                        _ = DoitActions.shared.addPlan(title: item.title, dateText: item.dayText, timeText: item.timeText,
                                                       minutes: item.minutes, isStudy: true, allDay: false, repeatText: nil)
                    }
                    _ = DoitActions.shared.drainLog()
                    Haptics.success()
                    withAnimation(Motion.quick) { addedPlans = true }
                } label: {
                    Text(addedPlans ? L("플래너에 넣었어요") : L("플래너에 넣기"))
                }
                .buttonStyle(.primaryFill)
                .disabled(addedPlans)
                .opacity(addedPlans ? 0.5 : 1)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 단원

    private func units(_ r: WeeklyReport) -> some View {
        let all: [(unit: WeeklyReport.UnitScore, weak: Bool)] = r.weakUnits.map { (unit: $0, weak: true) } + r.strongUnits.map { (unit: $0, weak: false) }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(L("단원 실력 (최근 4주)"))
            VStack(spacing: 0) {
                ForEach(Array(all.enumerated()), id: \.element.unit.id) { index, entry in
                    unitRow(entry.unit, weak: entry.weak)
                    if index < all.count - 1 { Hairline().padding(.leading, 16) }
                }
            }
            .softCardBackground()
        }
    }

    private func unitRow(_ unit: WeeklyReport.UnitScore, weak: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.unit).font(.pt(.body)).foregroundStyle(Palette.ink)
                Text(unit.subject.loc).font(.pt(.footnote)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            StatusText(text: weak ? L("보완") : L("탄탄"), color: weak ? Palette.danger : Palette.success)
            Text("\(Int((unit.rate * 100).rounded()))%")
                .font(.pt(.body).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 기록을 보고 직접 만드는 한마디: 잘한 점 하나 + 다음 주에 가장 중요한 한 가지
    private func loadComment(_ r: WeeklyReport) async {
        var parts: [String] = []
        if let highlight = r.highlights.first {
            parts.append(L("잘했어요!"))
            _ = highlight
        } else {
            parts.append(L("조금 쉬어 간 한 주였어요."))
        }
        if let weak = r.weakUnits.first {
            parts.append(L("다음 주엔 '\(weak.unit)'을(를) 채워 봐요."))
        } else if r.studyDays < 5 {
            parts.append(L("다음 주엔 매일 조금씩 해 봐요."))
        } else if r.goalDays < r.studyDays {
            parts.append(L("이제 목표 시간을 채우는 날을 늘려 봐요."))
        } else {
            parts.append(L("지금처럼만 하면 돼요."))
        }
        withAnimation(Motion.spring) { aiComment = parts.joined(separator: " ") }
    }
}

/// 통계·AI 학습 화면에 붙이는 "주간 AI 리포트" 바로가기 카드
struct WeeklyReportLink: View {
    var body: some View {
        NavigationLink { WeeklyReportView() } label: {
            RowLabel(symbol: "newspaper", title: L("주간 AI 리포트"), subtitle: L("한 주 정리 · 다음 주 추천"))
                .softCardBackground()
        }
        .buttonStyle(.pressable)
    }
}
