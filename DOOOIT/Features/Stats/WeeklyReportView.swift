import Charts
import SwiftData
import SwiftUI

/// 주간 AI 리포트 화면: 지난 7일 정리 + 잘한 점 + 다음 주 조언과 추천 플랜
struct WeeklyReportView: View {
    @Environment(\.modelContext) private var context
    @State private var report: WeeklyReport?
    @State private var aiComment: String?
    @State private var addedPlans = false
    @State private var chartShown = false

    var body: some View {
        ScrollView {
            if let report {
                // 한눈에: 공부 시간 → 숫자 넷 → 날마다 → 한마디(잘한 점 포함) → 과목 → 다음 주(조언 + 추천 플랜) → 단원 실력
                VStack(spacing: 16) {
                    hero(report).appearAnimation(delay: 0)
                    numbers(report).appearAnimation(delay: 0.05)
                    dailyChart(report).appearAnimation(delay: 0.1)
                    summaryCard(report).appearAnimation(delay: 0.12)
                    if !report.subjects.isEmpty { subjects(report).appearAnimation(delay: 0.15) }
                    if !report.advice.isEmpty || !report.nextWeek.isEmpty { nextWeekCard(report).appearAnimation(delay: 0.2) }
                    if !report.weakUnits.isEmpty || !report.strongUnits.isEmpty { units(report).appearAnimation(delay: 0.25) }
                }
                .padding(16)
                .padding(.bottom, 30)
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
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { chartShown = true }
            await loadComment(made)
        }
    }

    // MARK: 머리 카드

    private func hero(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(r.start.kr("M월 d일")) ~ \(r.end.kr("M월 d일"))", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
            }
            Text("이번 주 공부 시간")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(r.totalMinutes / 60)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("시간").font(.title3.weight(.bold))
                Text("\(r.totalMinutes % 60)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("분").font(.title3.weight(.bold))
            }
            .foregroundStyle(.white)
            if let change = r.change {
                Label("지난주보다 \(change >= 0 ? "+" : "")\(Int((change * 100).rounded()))%",
                      systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: .capsule)
            } else {
                Text("다음 주부터 지난주와 비교해 줘요")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccentGradient.linear, in: .rect(cornerRadius: 26))
        .shadow(color: Theme.accent.opacity(0.16), radius: 8, y: 3)
    }

    // MARK: 날마다

    private func dailyChart(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "날마다 공부한 시간", symbol: "chart.bar.fill") { EmptyView() }
            Chart {
                ForEach(Array(r.dailyMinutes.enumerated()), id: \.offset) { _, item in
                    BarMark(x: .value("요일", item.day.kr("E")), y: .value("분", chartShown ? item.minutes : 0))
                        .foregroundStyle(item.minutes >= r.goalMinutes ? AnyShapeStyle(AccentGradient.linear) : AnyShapeStyle(Theme.accent.opacity(0.35)))
                        .cornerRadius(6)
                }
                RuleMark(y: .value("목표", r.goalMinutes))
                    .foregroundStyle(Palette.success.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("목표 \(WeeklyReport.duration(r.goalMinutes))").font(.caption2).foregroundStyle(Palette.success)
                    }
            }
            .frame(height: 170)
            HStack(spacing: 8) {
                chip("공부한 날 \(r.studyDays)일", symbol: "checkmark.circle.fill", color: Theme.accent)
                chip("목표 달성 \(r.goalDays)일", symbol: "flag.fill", color: Palette.success)
                chip("연속 \(r.streak)일", symbol: "flame.fill", color: Palette.warning)
            }
        }
        .softCard()
    }

    // MARK: 한마디 (잘한 점 포함)

    private func summaryCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "이번 주 한마디", symbol: "sparkles") { EmptyView() }
            if let aiComment { Text(aiComment).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true) }
            ForEach(r.highlights.prefix(2), id: \.self) { line in
                Label(line, systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .symbolRenderingMode(.multicolor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    // MARK: 다음 주 (조언 두 개 + 추천 플랜)

    private func nextWeekCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "다음 주에는", symbol: "lightbulb") { EmptyView() }
            ForEach(Array(r.advice.prefix(2).enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(AccentGradient.linear, in: .circle)
                    Text(line).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !r.nextWeek.isEmpty {
                ForEach(r.nextWeek) { item in
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text(item.dayText.replacingOccurrences(of: "다음 주 ", with: "").replacingOccurrences(of: "요일", with: ""))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                            Text(item.timeText).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 58)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                            Text("\(item.minutes)분").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Theme.accent.opacity(0.06), in: .rect(cornerRadius: 14))
                }
                Button {
                    for item in r.nextWeek {
                        _ = DoitActions.shared.addPlan(title: item.title, dateText: item.dayText, timeText: item.timeText,
                                                       minutes: item.minutes, isStudy: true, allDay: false, repeatText: nil)
                    }
                    _ = DoitActions.shared.drainLog()
                    Haptics.success()
                    withAnimation(Motion.bouncy) { addedPlans = true }
                } label: {
                    Label(addedPlans ? "플래너에 넣었어요" : "플래너에 넣기", systemImage: addedPlans ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .disabled(addedPlans)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    // MARK: 잘한 점

    private func highlights(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "이번 주 잘한 점", symbol: "hand.thumbsup.fill") { EmptyView() }
            ForEach(r.highlights, id: \.self) { line in
                Label(line, systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .symbolRenderingMode(.multicolor)
            }
        }
        .softCard()
    }

    // MARK: 모티 AI 한마디

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("모티 AI 한마디", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(aiComment ?? "")
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
        }
        .softCard()
    }

    /// 기록을 보고 직접 만드는 한마디: 잘한 점 하나 + 다음 주에 가장 중요한 한 가지
    private func loadComment(_ r: WeeklyReport) async {
        var parts: [String] = []
        if let highlight = r.highlights.first {
            parts.append("잘했어요!")
            _ = highlight
        } else {
            parts.append("조금 쉬어 간 한 주였어요.")
        }
        if let weak = r.weakUnits.first {
            parts.append("다음 주엔 '\(weak.unit)'을(를) 채워 봐요.")
        } else if r.studyDays < 5 {
            parts.append("다음 주엔 매일 조금씩 해 봐요.")
        } else if r.goalDays < r.studyDays {
            parts.append("이제 목표 시간을 채우는 날을 늘려 봐요.")
        } else {
            parts.append("지금처럼만 하면 돼요.")
        }
        withAnimation(Motion.spring) { aiComment = parts.joined(separator: " ") }
    }

    // MARK: 숫자 요약

    private func numbers(_ r: WeeklyReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            stat(title: "플랜 완료", value: r.planRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                 detail: "\(r.planDone)/\(r.planTotal)", symbol: "checklist", color: Theme.accent, progress: r.planRate)
            stat(title: "문제 정답률", value: r.quizRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                 detail: r.quizTotal == 0 ? "AI 학습 기록 없음" : "\(r.quizCorrect)/\(r.quizTotal)", symbol: "target", color: Palette.success, progress: r.quizRate)
            stat(title: "단어", value: "\(r.wordsLearned)개", detail: "외움 · 추가 \(r.wordsAdded)개", symbol: "book.closed.fill", color: Palette.warning, progress: nil)
            stat(title: "오답노트", value: "\(r.notesAdded)문제", detail: "이번 주 추가 · 남은 오답 \(r.notesWrong)", symbol: "pencil", color: Palette.danger, progress: nil)
        }
    }

    private func stat(title: String, value: String, detail: String, symbol: String, color: Color, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                IconBadge(symbol: symbol, color: color, size: 30)
                Spacer()
                if let progress {
                    ZStack {
                        Circle().stroke(color.opacity(0.15), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: chartShown ? progress : 0)
                            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 30, height: 30)
                }
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Palette.ink).contentTransition(.numericText())
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .softCard(cornerRadius: 20, padding: 14)
    }

    // MARK: 과목별

    private func subjects(_ r: WeeklyReport) -> some View {
        let maxMinutes = max(r.subjects.map(\.minutes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "과목별 공부 시간", symbol: "books.vertical.fill") { EmptyView() }
            ForEach(r.subjects.prefix(6)) { subject in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(subject.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(WeeklyReport.duration(subject.minutes)).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        if subject.previousMinutes > 0 {
                            let diff = subject.minutes - subject.previousMinutes
                            Text(diff >= 0 ? "+\(diff)분" : "\(diff)분")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(diff >= 0 ? Palette.success : Palette.danger)
                        }
                    }
                    GeometryReader { proxy in
                        Capsule().fill(Theme.accent.opacity(0.12))
                            .overlay(alignment: .leading) {
                                Capsule().fill(AccentGradient.linear)
                                    .frame(width: chartShown ? proxy.size.width * CGFloat(subject.minutes) / CGFloat(maxMinutes) : 0)
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
        .softCard()
    }

    // MARK: 단원

    private func units(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "단원 실력 (최근 4주)", symbol: "target") { EmptyView() }
            ForEach(r.weakUnits) { unit in unitRow(unit, weak: true) }
            ForEach(r.strongUnits) { unit in unitRow(unit, weak: false) }
        }
        .softCard()
    }

    private func unitRow(_ unit: WeeklyReport.UnitScore, weak: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: weak ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                .foregroundStyle(weak ? Palette.danger : Palette.success)
            VStack(alignment: .leading, spacing: 1) {
                Text(unit.unit).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(unit.subject).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int((unit.rate * 100).rounded()))%")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(weak ? Palette.danger : Palette.success)
            Text(weak ? "보완" : "탄탄")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(weak ? Palette.danger : Palette.success, in: .capsule)
        }
    }

    // MARK: 조언 · 다음 주 플랜

    private func advice(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "다음 주에는 이렇게", symbol: "lightbulb.fill") { EmptyView() }
            ForEach(Array(r.advice.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(AccentGradient.linear, in: .circle)
                    Text(line).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .softCard()
    }

    private func nextWeek(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "다음 주 추천 플랜", symbol: "calendar") { EmptyView() }
            ForEach(r.nextWeek) { item in
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(item.dayText.replacingOccurrences(of: "다음 주 ", with: "").replacingOccurrences(of: "요일", with: ""))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        Text(item.timeText).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 58)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text("\(item.minutes)분").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Theme.accent.opacity(0.06), in: .rect(cornerRadius: 14))
            }
            Button {
                for item in r.nextWeek {
                    _ = DoitActions.shared.addPlan(title: item.title, dateText: item.dayText, timeText: item.timeText,
                                                   minutes: item.minutes, isStudy: true, allDay: false, repeatText: nil)
                }
                _ = DoitActions.shared.drainLog()
                Haptics.success()
                withAnimation(Motion.bouncy) { addedPlans = true }
            } label: {
                Label(addedPlans ? "플래너에 넣었어요" : "추천 플랜을 플래너에 넣기", systemImage: addedPlans ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glassProminent)
            .disabled(addedPlans)
        }
        .softCard()
    }

    private func chip(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.1), in: .capsule)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// 통계·AI 학습 화면에 붙이는 "주간 AI 리포트" 바로가기 카드
struct WeeklyReportLink: View {
    var body: some View {
        NavigationLink { WeeklyReportView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "newspaper.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(AccentGradient.linear, in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("주간 AI 리포트").font(.headline).foregroundStyle(Palette.ink)
                    Text("한 주 정리 · 다음 주 추천").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .softCard(cornerRadius: 22, padding: 14)
        }
        .buttonStyle(.pressable)
    }
}
