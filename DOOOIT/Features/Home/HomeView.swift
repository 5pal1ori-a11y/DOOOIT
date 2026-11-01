import Charts
import SwiftData
import SwiftUI

/// 홈: 카드만 반복하지 않고 구획마다 다른 형태로 구성
/// 인사 헤더 → 주간 스트립 → 집중 패널(글라스) → 타임라인형 오늘의 플랜 → 메모지 단어 카드 → 원형 바로가기 → 차트
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
                        WeekStrip(selected: now) { day in openPlanner(day) }
                        focusPanel(now: now)
                        plansSection(now: now)
                        wordMemoCard(now: now)
                        weekSection(now: now)
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
                Text(now.kr("M월 d일 EEEE"))
                Spacer()
                DDayChip()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(Greeting.text(name: auth.currentUser?.name ?? "유저", at: now))
                .font(.system(size: 30, weight: .bold))
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

    private func focusPanel(now: Date) -> some View {
        let seconds = todaySeconds(now: now)
        let progress = Double(seconds) / Double(max(studyGoalMinutes * 60, 1))
        let occurrences = plans.occurrences(on: now)
        let done = occurrences.filter(\.isCompleted).count
        let unsolved = mathNotes.filter { $0.status != .correct }.count

        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘 집중한 시간")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(TimeText.duration(seconds: seconds))
                        .font(.system(size: 34, weight: .heavy))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("목표 \(TimeText.duration(minutes: studyGoalMinutes)) · \(Int(min(progress, 1) * 100))% 달성")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 8)
                    Text("\(Int(min(progress, 1) * 100))%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 72, height: 72)
            }

            HStack(spacing: 14) {
                Label("연속 \(streak(now: now))일", systemImage: "flame.fill")
                Label("플랜 \(done)/\(occurrences.count)", systemImage: "checklist")
                if unsolved > 0 {
                    Label("복습 \(unsolved)", systemImage: "arrow.counterclockwise")
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            Button {
                studyTimer.isPresented = true
            } label: {
                Label(studyTimer.isActive ? "타이머 보기" : "집중 시작", systemImage: "play.fill")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
    }

    // MARK: Plans (타임라인, 카드 없음)

    private func plansSection(now: Date) -> some View {
        let occurrences = plans.occurrences(on: now)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("오늘의 플랜").font(.title3.weight(.heavy))
                Spacer()
                if occurrences.count > 3 {
                    Button("전체 \(occurrences.count)개") { showAllPlans = true }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Button("추가") { showNewPlan = true }
                        .font(.subheadline.weight(.semibold))
                }
            }

            if occurrences.isEmpty {
                Button { showNewPlan = true } label: {
                    Label("오늘 등록된 플랜이 없어요. 눌러서 오늘의 목표를 추가해보세요", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { DashedLine() }
                        .overlay(alignment: .bottom) { DashedLine() }
                }
                .buttonStyle(.plain)
            } else {
                ForEach(occurrences.prefix(3)) { occurrence in
                    PlanTimelineRow(occurrence: occurrence) { editingPlan = occurrence.plan }
                }
                if occurrences.count > 3 {
                    Button("+\(occurrences.count - 3)개 더 보기") { showAllPlans = true }
                        .font(.subheadline.weight(.bold))
                        .padding(.leading, 64)
                }
            }
        }
    }

    // MARK: Word memo card (메모지 형태)

    private func wordMemoCard(now: Date) -> some View {
        let unlearned = words.filter { !$0.isLearned }
        let doneToday = wordGoalDoneKey == now.dayKey
        let remaining = doneToday ? 0 : min(wordGoal, unlearned.count)
        let preview = unlearned.prefix(3).map(\.term).joined(separator: " · ")

        return NavigationLink { WordHomeView() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 영어 단어")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                    Text(words.isEmpty ? "단어장을 찍어서 시작해요" : (doneToday ? "오늘의 단어목표 성공!" : "외워야 할 단어 \(remaining)개"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text(doneToday || preview.isEmpty ? "하루 목표 \(wordGoal)개" : preview + " …")
                        .font(.custom("Noteworthy-Bold", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.ink.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: doneToday ? "checkmark" : "arrow.right")
                    .font(.headline)
                    .foregroundStyle(Palette.paper)
                    .frame(width: 38, height: 38)
                    .background(Palette.ink, in: .circle)
            }
            .padding(.vertical, 22)
            .padding(.leading, 46)
            .padding(.trailing, 18)
            .background { NotePaperBackground() }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 22, topTrailingRadius: 22))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.opacity(0.35))
                    .frame(width: 78, height: 20)
                    .rotationEffect(.degrees(-4))
                    .offset(y: -9)
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            .rotationEffect(.degrees(-0.6))
        }
        .buttonStyle(.plain)
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
            HStack {
                Text("이번 주").font(.title3.weight(.heavy))
                Spacer()
                NavigationLink("통계 자세히 보기") { StatsView() }
                    .font(.subheadline.weight(.semibold))
            }
            Text("최근 7일 총 \(TimeText.duration(minutes: total))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart(stats) { stat in
                BarMark(x: .value("요일", stat.label), y: .value("분", stat.minutes))
                    .cornerRadius(7)
                    .foregroundStyle(stat.isToday ? Theme.accent : Theme.accent.opacity(0.32))
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartYAxisLabel("분")
            .frame(height: 150)
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
