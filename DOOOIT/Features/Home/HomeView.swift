import Charts
import SwiftData
import SwiftUI

/// 홈: 인사 → 오늘 카드(목표 링 · 집중 시작 · 랭킹) → 타일 3개(연속·단어·오답) → 오늘 할 일 → 이번 주
/// (흰 카드 · 큰 숫자 · 구역 제목을 같은 모양으로 맞춤)
struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(AuthManager.self) private var auth
    @Environment(StudyTimer.self) private var studyTimer

    @Query(sort: \Plan.startDate) private var plans: [Plan]
    @Query(sort: \StudySession.start, order: .reverse) private var sessions: [StudySession]
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query private var mathNotes: [MathNote]

    @AppStorage(SettingsKey.dailyStudyGoalMinutes) private var studyGoalMinutes = 180
    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    @State private var chartShown = false
    @State private var showAllPlans = false
    @State private var showNewPlan = false
    @State private var editingPlan: Plan?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = timeline.date
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(now: now)
                            .appearAnimation()
                        focusPanel(now: now)
                            .appearAnimation(delay: 0.06)
                        VStack(spacing: 10) {
                            quickTiles(now: now)
                            RecentBadgeChip()
                        }
                        .appearAnimation(delay: 0.12)
                        plansSection(now: now)
                            .appearAnimation(delay: 0.18)
                        weekSection(now: now)
                            .appearAnimation(delay: 0.24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAllPlans) {
                TodayPlansSheet().presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNewPlan) {
                PlanEditorView(target: .new(Date()))
            }
            .sheet(item: $editingPlan) { plan in
                PlanEditorView(target: .edit(plan))
            }
        }
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: Greeting.symbol(at: now))
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.bounce, value: Greeting.symbol(at: now))
                Text(now.ui("M월 d일 EEEE"))
                Spacer()
                DDayChip()
            }
            .font(.pt(.subheadline).weight(.semibold))
            .foregroundStyle(.secondary)

            Text(Greeting.textL(name: auth.currentUser?.name.loc ?? L("유저"), at: now))
                .font(.pt(size: 28, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Focus panel (유일한 큰 글라스 패널)

    private func todaySeconds(now: Date) -> Int {
        let saved = sessions.filter { $0.start.isSameDay(as: now) }.reduce(0) { $0 + $1.seconds }
        let running = studyTimer.isActive ? Int(studyTimer.elapsed(at: now)) : 0
        return saved + running
    }

    private func streak(now: Date) -> Int {
        let studied = Set(sessions.filter { $0.seconds >= 60 }.map { $0.start.dayKey })
        var day = now.startOfDay
        if !studied.contains(day.dayKey) { day = day.adding(days: -1) }
        var count = 0
        while studied.contains(day.dayKey) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    /// 오늘 카드 (애플 피트니스처럼): 목표 링 · 공부 시간 · 남은 시간 → [집중 시작] [랭킹]
    private func focusPanel(now: Date) -> some View {
        let seconds = todaySeconds(now: now)
        let goal = max(studyGoalMinutes * 60, 1)
        let progress = Double(seconds) / Double(goal)
        let left = max(0, goal - seconds)

        return VStack(spacing: 20) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 13, color: Theme.accent)
                    VStack(spacing: 0) {
                        Text("\(Int(min(progress, 9.99) * 100))%")
                            .font(.pt(.title3).weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("목표").font(.pt(.caption2)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 4) {
                    Text(studyTimer.isActive ? L("집중하는 중") : L("오늘 공부"))
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(studyTimer.isActive ? Palette.success : .secondary)
                    Text(TimeText.durationL(seconds: seconds))
                        .font(.pt(size: 30, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(Motion.spring, value: seconds / 60)
                    Text(left == 0 ? L("오늘 목표 달성! 🎉") : L("목표까지 \(TimeText.durationL(seconds: left))"))
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    studyTimer.isPresented = true
                } label: {
                    Label(studyTimer.isActive ? L("타이머 보기") : L("집중 시작"), systemImage: studyTimer.isActive ? "timer" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.primaryFill)

                NavigationLink { RankingView() } label: {
                    Image(systemName: "trophy")
                        .font(.pt(.title3).weight(.regular))
                        .foregroundStyle(Palette.butter)
                        .frame(width: 54, height: 54)
                        .background(Palette.butter.pastel, in: .rect(cornerRadius: 20, style: .continuous))
                }
                .accessibilityLabel("공부 랭킹")
            }
        }
        .softCard(cornerRadius: 26, padding: 20)
    }

    /// 작은 타일 셋: 연속 공부 · 외울 단어 · 복습할 오답
    private func quickTiles(now: Date) -> some View {
        let unlearned = words.filter { !$0.isLearned }.count
        let doneToday = wordGoalDoneKey == now.dayKey
        let wordsLeft = doneToday ? 0 : min(wordGoal, unlearned)
        // 오늘 복습할 단어도 함께 셈
        let due = words.filter(\.isDueForReview).count
        let wordValue = wordsLeft + due == 0 ? L("완료") : L("\(wordsLeft + due)개")
        let unsolved = mathNotes.filter { $0.status != .correct }.count
        return HStack(spacing: 10) {
            tile(symbol: "flame.fill", color: Palette.peach, value: L("\(streak(now: now))일"), label: L("연속 공부"))
            NavigationLink { WordHomeView() } label: {
                tile(symbol: "book.closed.fill", color: Theme.accent, value: wordValue, label: L("오늘 단어"))
            }
            .buttonStyle(.pressable)
            NavigationLink { MathNoteListView() } label: {
                tile(symbol: "pencil", color: Palette.pink, value: L("\(unsolved)개"), label: L("복습할 오답"))
            }
            .buttonStyle(.pressable)
        }
    }

    private func tile(symbol: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol.outlineSymbol)
                .environment(\.symbolVariants, .none)
                .font(.pt(.subheadline).weight(.regular))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.pastel, in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.pt(.title3).weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                Text(label).font(.pt(.caption)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(cornerRadius: 20, padding: 14)
    }

    // MARK: Plans (타임라인, 카드 없음)

    private func plansSection(now: Date) -> some View {
        let occurrences = plans.occurrences(on: now)
        return VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: L("오늘 할 일")) {
                HStack(spacing: 14) {
                    if occurrences.count > 4 {
                        Button("전체 \(occurrences.count)") { showAllPlans = true }
                    }
                    Button { showNewPlan = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("할 일 추가")
                }
            }

            if occurrences.isEmpty {
                Button { showNewPlan = true } label: {
                    RowLabel(symbol: "plus", title: L("할 일 추가"), chevron: false)
                        .softCardBackground(cornerRadius: 20)
                }
                .buttonStyle(.pressable)
                .padding(.top, 4)
            } else {
                PlanListCard(occurrences: Array(occurrences.prefix(4))) { occurrence in
                    PlanTimelineRow(occurrence: occurrence) { editingPlan = occurrence.plan }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Week chart (카드 없이)

    private struct DayStat: Identifiable {
        let id: String
        let label: String
        let minutes: Int
        let isToday: Bool
    }

    private func weekSection(now: Date) -> some View {
        let stats: [DayStat] = (0..<7).reversed().map { offset in
            let day = now.startOfDay.adding(days: -offset)
            let seconds = offset == 0
                ? todaySeconds(now: now)
                : sessions.filter { $0.start.isSameDay(as: day) }.reduce(0) { $0 + $1.seconds }
            return DayStat(id: day.dayKey, label: day.ui("E"), minutes: seconds / 60, isToday: offset == 0)
        }
        let total = stats.reduce(0) { $0 + $1.minutes }

        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: L("이번 주")) {
                NavigationLink("자세히") { StatsView() }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TimeText.durationL(minutes: total))
                        .font(.pt(.title2).weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("최근 7일")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                }
                Chart(stats) { stat in
                    BarMark(x: .value("요일", stat.label), y: .value("분", chartShown ? stat.minutes : 0))
                        .cornerRadius(7)
                        .foregroundStyle(stat.isToday ? Theme.accent : Theme.accent.opacity(0.28))
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartYAxisLabel("분")
                .frame(height: 150)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) { chartShown = true }
                }
            }
            .softCard()
        }
    }
}

/// 점선 구분선
struct DashedLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}
