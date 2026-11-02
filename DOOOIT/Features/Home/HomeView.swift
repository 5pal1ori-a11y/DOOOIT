import Charts
import SwiftData
import SwiftUI

/// 홈: 인사 → 주간 스트립 → 오늘 요약 카드 → 오늘의 플랜 → 오늘의 단어 → 이번 주 차트
/// (흰 카드 · 큰 숫자 · 구역 제목을 같은 모양으로 맞춤)
struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(AuthManager.self) private var auth
    @Environment(StudyTimer.self) private var studyTimer
    @Environment(PlannerRouter.self) private var router

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
                        WeekStrip(selected: now) { day in openPlanner(day) }
                            .appearAnimation(delay: 0.05)
                        focusPanel(now: now)
                            .appearAnimation(delay: 0.1)
                        NavigationLink { RankingView() } label: {
                            RowLabel(symbol: "trophy.fill", color: Palette.warning, title: "공부 랭킹", subtitle: "오늘 다른 학생들과 공부 시간 겨루기")
                                .softCardBackground(cornerRadius: 20)
                        }
                        .buttonStyle(.pressable)
                        .appearAnimation(delay: 0.12)
                        plansSection(now: now)
                            .appearAnimation(delay: 0.15)
                        wordMemoCard(now: now)
                            .appearAnimation(delay: 0.2)
                        weekSection(now: now)
                            .appearAnimation(delay: 0.25)
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

    private func openPlanner(_ day: Date) {
        router.selectedDate = day.startOfDay
        router.mode = .day
        router.scrollRequest += 1
        selectedTab = .planner
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: Greeting.symbol(at: now))
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.bounce, value: Greeting.symbol(at: now))
                Text(now.kr("M월 d일 EEEE"))
                Spacer()
                DDayChip()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(Greeting.text(name: auth.currentUser?.name ?? "유저", at: now))
                .font(.system(size: 28, weight: .bold))
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

    /// 오늘 요약 카드 (애플 피트니스·토스처럼: 큰 숫자 → 목표 막대 → 세 칸 요약 → 버튼 하나)
    private func focusPanel(now: Date) -> some View {
        let seconds = todaySeconds(now: now)
        let progress = Double(seconds) / Double(max(studyGoalMinutes * 60, 1))
        let occurrences = plans.occurrences(on: now)
        let done = occurrences.filter(\.isCompleted).count
        let unsolved = mathNotes.filter { $0.status != .correct }.count

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("오늘 공부한 시간").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if studyTimer.isActive {
                        Label("집중 중", systemImage: "circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.success)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                }
                Text(TimeText.duration(seconds: seconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(Motion.spring, value: seconds / 60)
            }
            VStack(alignment: .leading, spacing: 6) {
                LinearProgressBar(value: progress)
                Text("목표 \(TimeText.duration(minutes: studyGoalMinutes)) 중 \(Int(min(progress, 1) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack(spacing: 0) {
                StatColumn(value: "\(streak(now: now))일", label: "연속 공부")
                StatColumn(value: "\(done)/\(occurrences.count)", label: "오늘 플랜")
                StatColumn(value: "\(unsolved)", label: "복습할 오답", color: unsolved > 0 ? Palette.danger : Palette.ink)
            }
            Button {
                studyTimer.isPresented = true
            } label: {
                Label(studyTimer.isActive ? "타이머 보기" : "집중 시작", systemImage: studyTimer.isActive ? "timer" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.primaryFill)
        }
        .softCard(cornerRadius: 24, padding: 20)
    }

    // MARK: Plans (타임라인, 카드 없음)

    private func plansSection(now: Date) -> some View {
        let occurrences = plans.occurrences(on: now)
        return VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "오늘의 플랜") {
                if occurrences.count > 3 {
                    Button("전체 \(occurrences.count)개") { showAllPlans = true }
                } else {
                    Button { showNewPlan = true } label: { Label("추가", systemImage: "plus") }
                }
            }

            if occurrences.isEmpty {
                Button { showNewPlan = true } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "calendar.badge.plus", size: 40)
                        Text("오늘 등록된 플랜이 없어요. 눌러서 오늘의 목표를 추가해보세요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .softCard(cornerRadius: 20, padding: 16)
                }
                .buttonStyle(.pressable)
                .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(occurrences.prefix(3)) { occurrence in
                        PlanTimelineRow(occurrence: occurrence) { editingPlan = occurrence.plan }
                    }
                    if occurrences.count > 3 {
                        Button("+\(occurrences.count - 3)개 더 보기") { showAllPlans = true }
                            .font(.subheadline.weight(.bold))
                            .padding(.leading, 64)
                            .padding(.top, 4)
                    }
                }
                .softCard(cornerRadius: 22, padding: 14)
                .padding(.top, 4)
            }
        }
    }

    // MARK: Word memo card (메모지 형태)

    private func wordMemoCard(now: Date) -> some View {
        let unlearned = words.filter { !$0.isLearned }
        let doneToday = wordGoalDoneKey == now.dayKey
        let remaining = doneToday ? 0 : min(wordGoal, unlearned.count)
        let preview = unlearned.prefix(3).map(\.term).joined(separator: " · ")
        let learnedToday = max(0, wordGoal - remaining)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("오늘의 영어 단어")
            NavigationLink { WordHomeView() } label: {
                VStack(alignment: .leading, spacing: 12) {
                    RowLabel(symbol: doneToday ? "checkmark.seal.fill" : "character.book.closed.fill",
                             color: doneToday ? Palette.success : Theme.accent,
                             title: words.isEmpty ? "단어장을 찍어서 시작해요" : (doneToday ? "오늘 목표 성공!" : "외울 단어 \(remaining)개"),
                             subtitle: doneToday || preview.isEmpty ? "하루 목표 \(wordGoal)개" : preview,
                             value: words.isEmpty ? nil : "\(learnedToday)/\(wordGoal)")
                    if !words.isEmpty {
                        LinearProgressBar(value: Double(learnedToday) / Double(max(wordGoal, 1)), color: doneToday ? Palette.success : Theme.accent, height: 6)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }
                }
                .softCardBackground(cornerRadius: 20)
            }
            .buttonStyle(.pressable)
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
            return DayStat(id: day.dayKey, label: day.kr("E"), minutes: seconds / 60, isToday: offset == 0)
        }
        let total = stats.reduce(0) { $0 + $1.minutes }

        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "이번 주") {
                NavigationLink("자세히") { StatsView() }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TimeText.duration(minutes: total))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("최근 7일 총 공부")
                        .font(.caption)
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
