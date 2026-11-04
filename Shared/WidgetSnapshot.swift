import Foundation

/// 앱이 홈 화면 · 잠금 화면 위젯에 넘겨주는 요약 (App Group으로 공유)
/// - 옛 앱이 저장한 스냅샷도 읽히게: 새로 넣은 값은 모두 없어도 되는 값(기본값)으로 읽음
/// - SwiftUI 없이 Foundation만 (리눅스 테스트에서도 컴파일)
struct WidgetSnapshot: Codable, Equatable {
    struct PlanItem: Codable, Hashable {
        var title: String
        var time: String
        var colorHex: String
        var isDone: Bool
        var isStudy: Bool
        // 아래는 새로 넣은 값 (옛 스냅샷에는 없음)
        /// 플랜 ID (위젯에서 완료 체크할 때)
        var planID: String?
        /// 그 일정의 날짜 키 (yyyy-MM-dd)
        var dayKey: String?
        var start: Date?
        var end: Date?
        var isAllDay: Bool?

        init(title: String, time: String, colorHex: String, isDone: Bool, isStudy: Bool,
             planID: String? = nil, dayKey: String? = nil, start: Date? = nil, end: Date? = nil, isAllDay: Bool? = nil) {
            self.title = title
            self.time = time
            self.colorHex = colorHex
            self.isDone = isDone
            self.isStudy = isStudy
            self.planID = planID
            self.dayKey = dayKey
            self.start = start
            self.end = end
            self.isAllDay = isAllDay
        }

        /// 완료 체크에 쓰는 일정 하나의 이름표 (플랜ID_날짜)
        var occurrenceID: String? {
            guard let planID, let dayKey else { return nil }
            return "\(planID)_\(dayKey)"
        }
    }

    struct WordItem: Codable, Hashable {
        var term: String
        var meaning: String
    }

    /// 달력 한 칸 (공부 시간 · 일정 수 · 일정 색)
    struct DayStat: Codable, Hashable {
        var key: String
        var minutes: Int
        var planCount: Int
        var doneCount: Int
        /// 일정 색 (최대 3개, 달력 점)
        var colors: [String]
        /// 이번 주 칸만: 그날 일정 (최대 4개)
        var items: [PlanItem]?

        init(key: String, minutes: Int = 0, planCount: Int = 0, doneCount: Int = 0, colors: [String] = [], items: [PlanItem]? = nil) {
            self.key = key
            self.minutes = minutes
            self.planCount = planCount
            self.doneCount = doneCount
            self.colors = colors
            self.items = items
        }
    }

    var updatedAt = Date()
    var dayKey = ""
    var plans: [PlanItem] = []
    var dDayTitle = ""
    var dDayDate: Date?
    var words: [WordItem] = []
    var wordsLeft = 0
    var studyMinutes = 0
    var goalMinutes = 180
    var streak = 0
    var accentHex = "#7B68EE"
    // 새로 넣은 값
    /// 가장 긴 연속 공부 일수
    var bestStreak = 0
    /// 이번 달 달력 칸 (앞뒤 달 칸 포함, 최대 42일)
    var days: [DayStat] = []
    /// 앞으로 7일 안의 시간 있는 일정 (끝나지 않은 것, 최대 6개)
    var upcoming: [PlanItem] = []

    static let appGroup = "group.com.donghyeon.moti"
    private static let key = "widgetSnapshot.v1"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case updatedAt, dayKey, plans, dDayTitle, dDayDate, words, wordsLeft, studyMinutes, goalMinutes, streak, accentHex
        case bestStreak, days, upcoming
    }

    /// 없는 값은 기본값으로 (옛 스냅샷 · 앞으로 줄어들 값도 그대로 읽힘)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = WidgetSnapshot()
        updatedAt = (try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? base.updatedAt
        dayKey = (try? c.decodeIfPresent(String.self, forKey: .dayKey)) ?? ""
        plans = (try? c.decodeIfPresent([PlanItem].self, forKey: .plans)) ?? []
        dDayTitle = (try? c.decodeIfPresent(String.self, forKey: .dDayTitle)) ?? ""
        dDayDate = (try? c.decodeIfPresent(Date.self, forKey: .dDayDate)) ?? nil
        words = (try? c.decodeIfPresent([WordItem].self, forKey: .words)) ?? []
        wordsLeft = (try? c.decodeIfPresent(Int.self, forKey: .wordsLeft)) ?? 0
        studyMinutes = (try? c.decodeIfPresent(Int.self, forKey: .studyMinutes)) ?? 0
        goalMinutes = (try? c.decodeIfPresent(Int.self, forKey: .goalMinutes)) ?? base.goalMinutes
        streak = (try? c.decodeIfPresent(Int.self, forKey: .streak)) ?? 0
        accentHex = (try? c.decodeIfPresent(String.self, forKey: .accentHex)) ?? base.accentHex
        bestStreak = (try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? 0
        days = (try? c.decodeIfPresent([DayStat].self, forKey: .days)) ?? []
        upcoming = (try? c.decodeIfPresent([PlanItem].self, forKey: .upcoming)) ?? []
    }

    static func decode(_ data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = decode(data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// 오늘 날짜 기준 D-Day 문구 (D-12, D-DAY, D+3)
    func dDayText(on date: Date = Date()) -> String? {
        guard !dDayTitle.isEmpty, let dDayDate else { return nil }
        let diff = WidgetMath.daysBetween(date, dDayDate)
        return diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)")
    }

    /// 위젯이 늦게 갱신돼서 어제 데이터일 때
    var isStale: Bool { isStale(at: Date()) }

    func isStale(at date: Date) -> Bool {
        dayKey != WidgetMath.dayKey(date)
    }

    /// 날짜 키로 달력 칸 찾기
    func day(_ key: String) -> DayStat? {
        days.first { $0.key == key }
    }

    func minutes(on date: Date) -> Int {
        let key = WidgetMath.dayKey(date)
        if key == dayKey { return studyMinutes }
        return day(key)?.minutes ?? 0
    }

    /// 그 시각의 연속 공부 일수 (스냅샷이 하루 늦으면: 그날 공부했으면 그대로, 아니면 끊김)
    func streak(at date: Date) -> Int {
        let gap = dayKey.isEmpty ? Int.max : WidgetMath.daysBetween(WidgetMath.date(fromKey: dayKey) ?? date, date)
        switch gap {
        case 0: return streak
        case 1: return studyMinutes >= 1 ? streak : 0
        default: return 0
        }
    }

    /// 그 시각 기준 진행 중이거나 다음에 올 일정 (끝난 것 · 완료한 것 빼고)
    func nextPlans(at date: Date) -> [PlanItem] {
        upcoming.filter { item in
            guard let end = item.end ?? item.start else { return false }
            return end > date && !item.isDone
        }
    }

    /// 위젯에서 완료를 누른 뒤 바로 보이게 스냅샷을 고침 (앱이 실제 저장은 따로)
    func settingPlan(_ occurrenceID: String, done: Bool) -> WidgetSnapshot {
        var copy = self
        func fix(_ items: inout [PlanItem]) -> Int {
            var changed = 0
            for i in items.indices where items[i].occurrenceID == occurrenceID && items[i].isDone != done {
                items[i].isDone = done
                changed += 1
            }
            return changed
        }
        var changed = fix(&copy.plans) + fix(&copy.upcoming)
        guard let dayKey = WidgetPending.split(occurrenceID)?.dayKey else { return copy }
        for i in copy.days.indices where copy.days[i].key == dayKey {
            if var items = copy.days[i].items {
                changed += fix(&items)
                copy.days[i].items = items
            }
            if changed > 0 {
                copy.days[i].doneCount = min(copy.days[i].planCount, max(0, copy.days[i].doneCount + (done ? 1 : -1)))
            }
        }
        return copy
    }
}

// MARK: - 위젯에서 누른 완료 체크 (앱이 다음에 켜질 때 저장)

/// 위젯 확장에서는 앱 저장소를 열 수 없어서, 누른 내용을 App Group에 적어 두고 앱이 읽어서 저장함
enum WidgetPending {
    private static let key = "widgetPendingPlanDone.v1"

    /// 일정 이름표(플랜ID_날짜) → 원하는 완료 상태
    static func load(_ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> [String: Bool] {
        (defaults?.dictionary(forKey: key) as? [String: Bool]) ?? [:]
    }

    static func add(_ occurrenceID: String, done: Bool, _ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        var all = load(defaults)
        all[occurrenceID] = done
        defaults?.set(all, forKey: key)
    }

    static func clear(_ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        defaults?.removeObject(forKey: key)
    }

    /// "플랜ID_yyyy-MM-dd" → (플랜ID, 날짜 키)
    static func split(_ occurrenceID: String) -> (planID: String, dayKey: String)? {
        guard let range = occurrenceID.range(of: "_", options: .backwards) else { return nil }
        let planID = String(occurrenceID[..<range.lowerBound])
        let dayKey = String(occurrenceID[range.upperBound...])
        guard !planID.isEmpty, WidgetMath.date(fromKey: dayKey) != nil else { return nil }
        return (planID, dayKey)
    }
}

// MARK: - 달력 · 그래프 계산 (위젯과 앱이 같이 씀)

enum WidgetMath {
    /// 앱과 같은 날짜 키 (기기 달력 설정과 상관없이 양력 숫자)
    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }

    static func date(fromKey key: String) -> Date? { dayKeyFormatter.date(from: key) }

    /// 두 날짜 사이 날 수 (자정 기준)
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// 월간 달력 칸: 일요일부터, 그 달이 들어가는 주만큼 (플래너 달력과 같은 모양)
    static func monthGrid(for date: Date, calendar: Calendar = .current) -> [Date] {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let first = calendar.date(from: comps) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = (weekday - 1 + daysInMonth + 6) / 7
        guard let start = calendar.date(byAdding: .day, value: -(weekday - 1), to: first) else { return [] }
        return (0..<(rows * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// 그 날이 들어간 주 (일요일 ~ 토요일)
    static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        guard let start = calendar.date(byAdding: .day, value: -(weekday - 1), to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// 지금까지 이어서 공부한 날 수 (오늘 아직 안 했으면 어제부터 셈)
    static func currentStreak(studiedKeys: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !studiedKeys.contains(dayKey(day)) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while studiedKeys.contains(dayKey(day)), count < 3_650 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// 달력 칸 진하기 0(안 함) ~ 4(목표 이상)
    static func heatLevel(minutes: Int, goal: Int) -> Int {
        guard minutes > 0 else { return 0 }
        let ratio = Double(minutes) / Double(max(goal, 1))
        switch ratio {
        case ..<0.25: return 1
        case ..<0.6: return 2
        case ..<1: return 3
        default: return 4
        }
    }

    /// 1시간 20분 / 45분 (짧게)
    static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }

    /// 그래프 숫자용 아주 짧은 표기 (1.5h · 45m 대신 1.5 · 45분)
    static func compactHours(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분" }
        let hours = Double(minutes) / 60
        return hours >= 10 || minutes % 60 == 0 ? "\(Int(hours.rounded()))시간" : String(format: "%.1f시간", hours)
    }

    /// 위젯을 다시 그릴 시각: 지금, 앞으로 하루 안 일정의 시작 · 끝, 자정 직후
    static func refreshDates(now: Date, upcoming: [WidgetSnapshot.PlanItem], calendar: Calendar = .current) -> [Date] {
        let limit = now.addingTimeInterval(24 * 3600)
        var dates: Set<Date> = [now]
        for item in upcoming {
            for d in [item.start, item.end].compactMap({ $0 }) where d > now && d < limit {
                dates.insert(d)
            }
        }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.insert(midnight.addingTimeInterval(60))
        }
        return dates.sorted().prefix(16).map { $0 }
    }
}
