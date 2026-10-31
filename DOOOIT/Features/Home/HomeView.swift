import Charts
import SwiftData
import SwiftUI

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
    @AppStorage(SettingsKey.dDayTitle) private var dDayTitle = ""
    @AppStorage(SettingsKey.dDayDate) private var dDayDate: Double = 0

    @State private var showAllPlans = false
    @State private var showNewPlan = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = timeline.date
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(now: now)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        todayPlansCard(now: now)
                        quickActions
                        HStack(spacing: 14) {
                            studyTimeCard(now: now)
                            streakCard(now: now)
                        }
                        wordGoalCard(now: now)
                        if !dDayTitle.isEmpty && dDayDate > 0 {
                            dDayCard(now: now)
                        }
                        weeklyChartCard(now: now)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAllPlans) {
                TodayPlansSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNewPlan) {
                PlanEditorView(target: .new(Date()))
            }
        }
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: Greeting.symbol(at: now))
                    .symbolRenderingMode(.multicolor)
                Text(now.kr("M월 d일 EEEE"))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(Greeting.text(name: auth.currentUser?.name ?? "유저", at: now))
                .font(.system(size: 30, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    // MARK: Today plans

    private func todayPlansCard(now: Date) -> some View {
        let occurrences = plans.occurrences(on: now)
        let done = occurrences.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "오늘의 플랜", symbol: "checklist") {
                if !occurrences.isEmpty {
                    Text("\(done)/\(occurrences.count)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if occurrences.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("오늘 등록된 플랜이 없어요").font(.subheadline.weight(.semibold))
                        Text("눌러서 오늘의 목표를 추가해보세요").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                if !occurrences.isEmpty {
                    ProgressView(value: Double(done), total: Double(occurrences.count))
                        .tint(Color.accentColor)
                }
                VStack(spacing: 12) {
                    ForEach(occurrences.prefix(3)) { occurrence in
                        PlanRow(occurrence: occurrence)
                    }
                }
                if occurrences.count > 3 {
                    HStack {
                        Spacer()
                        Text("+\(occurrences.count - 3)개 더 보기")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
        .glassCard()
        .contentShape(.rect(cornerRadius: 26))
        .onTapGesture {
            if occurrences.isEmpty { showNewPlan = true } else { showAllPlans = true }
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink { WordHomeView() } label: {
                    QuickAction(symbol: "character.book.closed.fill", title: "영어 단어")
                }
                NavigationLink { MathNoteListView() } label: {
                    QuickAction(symbol: "function", title: "오답노트")
                }
                NavigationLink { MemoListView() } label: {
                    QuickAction(symbol: "note.text", title: "메모")
                }
                Button { studyTimer.isPresented = true } label: {
                    QuickAction(symbol: "timer", title: "타이머")
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Study time

    private func todaySeconds(now: Date) -> Int {
        let saved = sessions.filter { $0.start.isSameDay(as: now) }.reduce(0) { $0 + $1.seconds }
        let running = studyTimer.isActive ? Int(studyTimer.elapsed(at: now)) : 0
        return saved + running
    }

    private func studyTimeCard(now: Date) -> some View {
        let seconds = todaySeconds(now: now)
        let progress = Double(seconds) / Double(max(studyGoalMinutes * 60, 1))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("오늘 공부", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressRing(progress: progress, lineWidth: 5)
                    .frame(width: 26, height: 26)
            }
            Text(TimeText.duration(seconds: seconds))
                .font(.title2.weight(.bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("목표 \(TimeText.duration(minutes: studyGoalMinutes))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(padding: 16)
    }

    // MARK: Streak

    private func streak(now: Date) -> Int {
        let studiedDays = Set(sessions.filter { $0.seconds >= 60 }.map { $0.start.dayKey })
        var day = now.startOfDay
        if !studiedDays.contains(day.dayKey) { day = day.adding(days: -1) }
        var count = 0
        while studiedDays.contains(day.dayKey) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    private func streakCard(now: Date) -> some View {
        let days = streak(now: now)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("연속 공부", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(days > 0 ? Color.orange : Color.secondary)
                    .symbolEffect(.bounce, value: days)
            }
            Text("\(days)일")
                .font(.title2.weight(.bold))
            Text(days > 0 ? "기록을 이어가세요" : "오늘 첫 기록을 남겨요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(padding: 16)
    }

    // MARK: Words

    private func wordGoalCard(now: Date) -> some View {
        let unlearned = words.filter { !$0.isLearned }.count
        let doneToday = wordGoalDoneKey == now.dayKey
        let remaining = doneToday ? 0 : min(wordGoal, unlearned)
        let learnedToday = words.filter { $0.learnedAt?.isSameDay(as: now) ?? false }.count

        return NavigationLink {
            WordHomeView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: doneToday ? 1 : Double(learnedToday) / Double(max(wordGoal, 1)),
                                 lineWidth: 6, color: doneToday ? Palette.success : .accentColor)
                    Image(systemName: doneToday ? "checkmark" : "character.book.closed.fill")
                        .font(.headline)
                        .foregroundStyle(doneToday ? Palette.success : Color.accentColor)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 영어 단어")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if words.isEmpty {
                        Text("단어장을 촬영해서 시작해요")
                            .font(.headline)
                    } else if doneToday {
                        Text("오늘의 단어목표 성공!")
                            .font(.headline)
                    } else {
                        Text("외워야 할 단어 \(remaining)개")
                            .font(.headline)
                    }
                    Text("하루 목표 \(wordGoal)개 · 남은 단어 \(unlearned)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .glassCard(interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: D-Day

    private func dDayCard(now: Date) -> some View {
        let target = Date(timeIntervalSince1970: dDayDate).startOfDay
        let diff = Calendar.current.dateComponents([.day], from: now.startOfDay, to: target).day ?? 0
        let label = diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)")

        return HStack(spacing: 14) {
            IconBadge(symbol: "flag.checkered", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(dDayTitle).font(.headline)
                Text(target.kr("yyyy년 M월 d일 (E)")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(label)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .glassCard()
    }

    // MARK: Weekly chart

    private struct DayStat: Identifiable {
        let id: String
        let label: String
        let minutes: Int
        let isToday: Bool
    }

    private func weeklyChartCard(now: Date) -> some View {
        let stats: [DayStat] = (0..<7).reversed().map { offset in
            let day = now.startOfDay.adding(days: -offset)
            let seconds = offset == 0
                ? todaySeconds(now: now)
                : sessions.filter { $0.start.isSameDay(as: day) }.reduce(0) { $0 + $1.seconds }
            return DayStat(id: day.dayKey, label: day.kr("E"), minutes: seconds / 60, isToday: offset == 0)
        }
        let total = stats.reduce(0) { $0 + $1.minutes }
        let unsolved = mathNotes.filter { $0.status != .correct }.count

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "이번 주 공부", symbol: "chart.bar.fill") {
                Text("총 \(TimeText.duration(minutes: total))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Chart(stats) { stat in
                BarMark(
                    x: .value("요일", stat.label),
                    y: .value("분", stat.minutes)
                )
                .cornerRadius(6)
                .foregroundStyle(stat.isToday ? Color.accentColor : Color.accentColor.opacity(0.35))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("분")
            .frame(height: 150)

            if unsolved > 0 {
                Divider()
                NavigationLink { MathNoteListView() } label: {
                    HStack {
                        Label("다시 풀어볼 오답 \(unsolved)문제", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
    }
}

private struct QuickAction: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(height: 24)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
}

// MARK: - Plan row (홈/플래너 공용)

struct PlanRow: View {
    let occurrence: PlanOccurrence
    @Environment(\.modelContext) private var context

    var body: some View {
        let plan = occurrence.plan
        let completed = occurrence.isCompleted

        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { plan.toggleCompleted(on: occurrence.day) }
                try? context.save()
                Haptics.tap()
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(completed ? plan.color : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 2)
                .fill(plan.color)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(completed)
                    .foregroundStyle(completed ? Color.secondary : Color.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(occurrence.timeText)
                    if let category = plan.category {
                        Label(category.name, systemImage: category.symbol)
                    }
                    if plan.repeatRule != .none {
                        Image(systemName: "repeat")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if plan.isStudy {
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(plan.color)
            }
        }
    }
}

/// 오늘의 플랜 전체 보기
struct TodayPlansSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Plan.startDate) private var plans: [Plan]
    @State private var editing: Plan?

    var body: some View {
        NavigationStack {
            let occurrences = plans.occurrences(on: Date())
            List {
                Section {
                    ForEach(occurrences) { occurrence in
                        PlanRow(occurrence: occurrence)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = occurrence.plan }
                    }
                } footer: {
                    Text("완료 \(occurrences.filter(\.isCompleted).count) / \(occurrences.count)")
                }
            }
            .navigationTitle("오늘의 플랜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
            .sheet(item: $editing) { plan in
                PlanEditorView(target: .edit(plan))
            }
        }
    }
}
