import Foundation

/// 시험 D-day 자동 계획: 오늘부터 시험 전날까지 하루씩 공부 블록(25~90분)을 짜 줌.
/// Foundation만 쓰는 순수 계산이라 같은 입력이면 항상 같은 결과 (Linux 테스트 가능).
/// - 쉬는 요일은 건너뛰고, 과목은 (범위 크기 × 중요도 × 취약) 비율로 나누고 돌려 가며 배치
/// - 마지막 이틀은 복습 위주 (날이 모자라면 줄임), 시험 당일은 넣지 않음
/// - 하루 합계는 절대 하루 가능 시간을 넘지 않고, 전체 개수는 250개까지
enum ExamPlanner {
    static let maxItems = 250
    static let minBlock = 25
    static let maxBlock = 90
    static let breakMinutes = 10
    static let minDaily = 25
    static let maxDaily = 720
    /// 시험이 이보다 멀면 가까운 쪽 날들만 계획 (너무 먼 계획은 쓸모없음)
    static let maxHorizonDays = 400

    struct Subject: Equatable {
        var name: String
        /// 범위 크기 (단원 수·쪽 수 등, 0이면 모름 → 보통 크기)
        var size: Int = 0
        var important = false
        /// 취약 개념이 많은 과목 (조금 더 배정)
        var weak = false
        var weight: Double = 1

        init(name: String, size: Int = 0, important: Bool = false, weak: Bool = false, weight: Double = 1) {
            self.name = name
            self.size = size
            self.important = important
            self.weak = weak
            self.weight = weight
        }
    }

    struct Input {
        /// 지금 (시각이 있으면 오늘 남은 시간만 사용)
        var today: Date
        var examDate: Date
        var subjects: [Subject]
        var dailyMinutes: Int
        /// 하루 시작 시각 (자정부터 분)
        var startMinuteOfDay: Int
        /// 쉬는 요일 (Calendar.weekday: 1 일 … 7 토)
        var offWeekdays: Set<Int> = []
        /// 마지막 이틀은 복습 위주
        var reviewTail = true
        var calendar: Calendar = .current

        init(today: Date, examDate: Date, subjects: [Subject], dailyMinutes: Int, startMinuteOfDay: Int,
             offWeekdays: Set<Int> = [], reviewTail: Bool = true, calendar: Calendar = .current) {
            self.today = today
            self.examDate = examDate
            self.subjects = subjects
            self.dailyMinutes = dailyMinutes
            self.startMinuteOfDay = startMinuteOfDay
            self.offWeekdays = offWeekdays
            self.reviewTail = reviewTail
            self.calendar = calendar
        }
    }

    struct Item: Equatable, Identifiable {
        let id: String
        /// 그 날의 0시
        let date: Date
        let subject: String
        let minutes: Int
        let startMinuteOfDay: Int
        /// 범위 번호 (복습이면 0)
        let part: Int
        /// 그 과목의 범위 조각 수 (복습이면 0)
        let parts: Int
        let isReview: Bool
        /// 한국어 이름 (예: "수학 1/6 범위", "수학 복습") — 화면에서는 part/parts/isReview로 번역해서 보임
        let label: String

        var endMinuteOfDay: Int { startMinuteOfDay + minutes }
    }

    enum EmptyReason: String, Equatable {
        case examToday, examPassed, noSubjects, noDays

        var text: String {
            switch self {
            case .examToday: return "시험이 오늘이에요"
            case .examPassed: return "이미 지난 시험이에요"
            case .noSubjects: return "과목을 골라 주세요"
            case .noDays: return "공부할 수 있는 날이 없어요"
            }
        }
    }

    struct Result: Equatable {
        var items: [Item] = []
        var emptyReason: EmptyReason?
        /// 블록이 모자라 넣지 못한 과목
        var droppedSubjects: [String] = []
        /// 개수 제한 때문에 먼 날들을 뺐는지
        var trimmedEarlyDays = false
        /// 모든 날이 쉬는 날이라 쉬는 요일을 무시했는지
        var ignoredOffDays = false
    }

    struct Summary: Equatable {
        var count = 0
        var days = 0
        var totalMinutes = 0
        var averageMinutes = 0
    }

    // MARK: 계획 만들기

    private struct Day {
        let offset: Int
        let date: Date
        let startMinute: Int
        let span: Int
        var minutes: Int
        var blocks: Int
    }

    static func plan(_ input: Input) -> Result {
        let cal = input.calendar
        let today = cal.startOfDay(for: input.today)
        let exam = cal.startOfDay(for: input.examDate)
        if exam < today { return Result(emptyReason: .examPassed) }
        if exam == today { return Result(emptyReason: .examToday) }

        let subjects = cleaned(input.subjects)
        if subjects.isEmpty { return Result(emptyReason: .noSubjects) }

        let horizon = cal.dateComponents([.day], from: today, to: exam).day ?? 0
        if horizon <= 0 { return Result(emptyReason: .examToday) }

        let daily = max(minDaily, min(maxDaily, input.dailyMinutes)) / 5 * 5
        let baseStart = max(0, min(1380, input.startMinuteOfDay)) / 5 * 5
        let nowParts = cal.dateComponents([.hour, .minute], from: input.today)
        let nowMinute = (nowParts.hour ?? 0) * 60 + (nowParts.minute ?? 0)

        // 1) 후보 날짜 (오늘 ... 시험 전날), 쉬는 요일 빼기
        var result = Result()
        var all: [Day] = []
        for offset in max(0, horizon - maxHorizonDays)..<horizon {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            all.append(makeDay(offset: offset, date: date, baseStart: baseStart, nowMinute: offset == 0 ? nowMinute : 0, daily: daily))
        }
        all = all.filter { $0.minutes >= minBlock }
        var days = all.filter { !input.offWeekdays.contains(cal.component(.weekday, from: $0.date)) }
        if days.isEmpty && !all.isEmpty && !input.offWeekdays.isEmpty {
            days = all
            result.ignoredOffDays = true
        }
        if days.isEmpty { return Result(emptyReason: .noDays) }

        // 2) 개수 제한: 먼 날부터 뺌
        while days.count > 1 && days.reduce(0, { $0 + $1.blocks }) > maxItems {
            days.removeFirst()
            result.trimmedEarlyDays = true
        }

        // 3) 복습 날 수
        let count = days.count
        let reviewDays = input.reviewTail ? (count >= 6 ? 2 : (count >= 3 ? 1 : 0)) : 0
        let partialReview = input.reviewTail && count < 3
        func reviewBlocks(_ index: Int, _ blocks: Int) -> Int {
            if index >= count - reviewDays { return blocks }
            if partialReview && index == count - 1 { return blocks / 2 }
            return 0
        }
        func studyTotal() -> Int { days.indices.reduce(0) { $0 + days[$1].blocks - reviewBlocks($1, days[$1].blocks) } }

        // 4) 공부 블록이 과목 수보다 적으면 (아주 짧은 기간) 블록을 잘게 쪼갬
        var guardCount = 0
        while studyTotal() < subjects.count && guardCount < 1000 {
            guardCount += 1
            var changed = false
            for index in days.indices {
                var day = days[index]
                if canSplitMore(day), day.blocks + 1 <= maxItems {
                    day.blocks += 1
                    days[index] = day
                    changed = true
                    if studyTotal() >= subjects.count { break }
                }
            }
            if !changed { break }
        }

        // 5) 과목 비율
        let studyBlocks = studyTotal()
        var kept = subjects.indices.map { $0 }
        let weights = subjectWeights(subjects)
        if studyBlocks < subjects.count {
            let ranked = kept.sorted { weights[$0] != weights[$1] ? weights[$0] > weights[$1] : $0 < $1 }
            let top = Set(ranked.prefix(max(studyBlocks, 1)))
            kept = kept.filter { top.contains($0) }
            result.droppedSubjects = subjects.indices.filter { !top.contains($0) }.map { subjects[$0].name }
        }
        let keptWeights = kept.map { weights[$0] }
        let quotas = allocate(total: studyBlocks, weights: keptWeights)
        var studyQueue = smoothSequence(weights: quotas.map(Double.init), length: studyBlocks)
        var reviewState = SmoothState(weights: keptWeights)

        // 6) 날마다 블록 배치
        var partCounter = [Int](repeating: 0, count: kept.count)
        var items: [Item] = []
        for (index, day) in days.enumerated() {
            let review = reviewBlocks(index, day.blocks)
            let study = day.blocks - review
            var studyPicks = Array(studyQueue.prefix(study))
            studyQueue.removeFirst(min(study, studyQueue.count))
            studyPicks = arrange(studyPicks, dayIndex: index)
            var reviewPicks: [Int] = []
            for _ in 0..<review { reviewPicks.append(reviewState.next()) }
            reviewPicks = arrange(reviewPicks, dayIndex: index)

            let lengths = split(day.minutes, into: day.blocks)
            var cursor = day.startMinute
            var slot = 0
            for (isReview, picks) in [(false, studyPicks), (true, reviewPicks)] {
                for pick in picks {
                    let subject = subjects[kept[pick]]
                    let part: Int
                    let parts: Int
                    let label: String
                    if isReview {
                        part = 0; parts = 0
                        label = "\(subject.name) 복습"
                    } else {
                        partCounter[pick] += 1
                        part = partCounter[pick]
                        parts = quotas[pick]
                        label = parts > 1 ? "\(subject.name) \(part)/\(parts) 범위" : "\(subject.name) 공부"
                    }
                    let minutes = lengths[slot]
                    items.append(Item(id: "\(day.offset)-\(slot)", date: day.date, subject: subject.name, minutes: minutes,
                                      startMinuteOfDay: cursor, part: part, parts: parts, isReview: isReview, label: label))
                    cursor += minutes + breakMinutes
                    slot += 1
                }
            }
        }
        result.items = items
        return result
    }

    // MARK: 요약

    static func summarize(_ items: [Item]) -> Summary {
        guard !items.isEmpty else { return Summary() }
        let total = items.reduce(0) { $0 + $1.minutes }
        let days = Set(items.map(\.date)).count
        let average = days > 0 ? Int((Double(total) / Double(days)).rounded()) : 0
        return Summary(count: items.count, days: days, totalMinutes: total, averageMinutes: average)
    }

    /// "하루 평균 142분 · 총 18시간"
    static func summaryText(_ summary: Summary) -> String {
        "하루 평균 \(summary.averageMinutes)분 · 총 \(hoursText(minutes: summary.totalMinutes))시간"
    }

    /// 90분 → "1.5", 120분 → "2"
    static func hoursText(minutes: Int) -> String {
        let tenths = Int((Double(minutes) / 6.0).rounded())
        return tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
    }

    // MARK: 도우미

    private static func cleaned(_ list: [Subject]) -> [Subject] {
        var seen = Set<String>()
        var out: [Subject] = []
        for var subject in list {
            subject.name = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !subject.name.isEmpty, seen.insert(subject.name).inserted else { continue }
            out.append(subject)
        }
        return out
    }

    /// 과목별 비율: 가중치 × 범위 크기 × 중요도(1.5) × 취약(1.15)
    static func subjectWeights(_ subjects: [Subject]) -> [Double] {
        let sizes = subjects.map(\.size).filter { $0 > 0 }
        let average = sizes.isEmpty ? 0 : Double(sizes.reduce(0, +)) / Double(sizes.count)
        return subjects.map { subject in
            var weight = max(0.1, subject.weight)
            if subject.size > 0, average > 0 { weight *= min(2, max(0.5, Double(subject.size) / average)) }
            if subject.important { weight *= 1.5 }
            if subject.weak { weight *= 1.15 }
            return weight
        }
    }

    private static func makeDay(offset: Int, date: Date, baseStart: Int, nowMinute: Int, daily: Int) -> Day {
        var start = baseStart
        if nowMinute > start { start = min(1440, (nowMinute + 10 + 4) / 5 * 5) }
        let span = max(0, 1440 - start)
        var minutes = daily
        var blocks = blockCount(minutes)
        while minutes + breakMinutes * (blocks - 1) > span && minutes >= minBlock + 5 {
            minutes -= 5
            blocks = blockCount(minutes)
        }
        if minutes + breakMinutes * (blocks - 1) > span || minutes < minBlock { minutes = 0; blocks = 0 }
        return Day(offset: offset, date: date, startMinute: start, span: span, minutes: minutes, blocks: blocks)
    }

    /// 하루 공부 시간에 맞는 블록 수 (보통 55분 안팎, 25~90분 안에서)
    static func blockCount(_ minutes: Int) -> Int {
        guard minutes >= minBlock else { return 0 }
        let low = (minutes + maxBlock - 1) / maxBlock
        let high = max(low, minutes / minBlock)
        return min(high, max(low, Int((Double(minutes) / 55.0).rounded())))
    }

    private static func canSplitMore(_ day: Day) -> Bool {
        let next = day.blocks + 1
        return next <= day.minutes / minBlock && day.minutes + breakMinutes * (next - 1) <= day.span
    }

    /// 총 시간을 5분 단위로 n개 블록에 나눔 (앞 블록이 5분씩 더 김)
    static func split(_ minutes: Int, into count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let base = minutes / count / 5 * 5
        var extra = (minutes - base * count) / 5
        return (0..<count).map { _ in
            defer { extra = max(0, extra - 1) }
            return base + (extra > 0 ? 5 : 0)
        }
    }

    /// 비율대로 개수 나누기 (가장 큰 나머지 방식, 0개가 되는 과목이 없게)
    static func allocate(total: Int, weights: [Double]) -> [Int] {
        guard !weights.isEmpty, total > 0 else { return [Int](repeating: 0, count: weights.count) }
        let sum = weights.reduce(0, +)
        let exact = weights.map { Double(total) * $0 / sum }
        var counts = exact.map { Int($0) }
        var left = total - counts.reduce(0, +)
        let order = exact.indices.sorted {
            let a = exact[$0] - Double(counts[$0]), b = exact[$1] - Double(counts[$1])
            return a != b ? a > b : $0 < $1
        }
        for index in order where left > 0 {
            counts[index] += 1
            left -= 1
        }
        if total >= weights.count {
            for index in counts.indices where counts[index] == 0 {
                if let donor = counts.indices.max(by: { counts[$0] != counts[$1] ? counts[$0] < counts[$1] : $0 > $1 }), counts[donor] > 1 {
                    counts[donor] -= 1
                    counts[index] += 1
                }
            }
        }
        return counts
    }

    /// 매끄러운 가중 순환: 같은 과목이 몰리지 않고 비율대로 섞임
    private struct SmoothState {
        let weights: [Double]
        var credit: [Double]
        init(weights: [Double]) {
            self.weights = weights
            self.credit = [Double](repeating: 0, count: weights.count)
        }
        mutating func next() -> Int {
            let total = weights.reduce(0, +)
            for index in weights.indices { credit[index] += weights[index] }
            var best = 0
            for index in weights.indices where credit[index] > credit[best] + 1e-9 { best = index }
            credit[best] -= total
            return best
        }
    }

    private static func smoothSequence(weights: [Double], length: Int) -> [Int] {
        guard !weights.isEmpty else { return [] }
        var state = SmoothState(weights: weights)
        return (0..<length).map { _ in state.next() }
    }

    /// 하루 안에서 순서 돌리기 (맨 마지막이 늘 같은 과목이 되지 않게) + 같은 과목 연달아 피하기
    private static func arrange(_ picks: [Int], dayIndex: Int) -> [Int] {
        guard picks.count > 1 else { return picks }
        let shift = dayIndex % picks.count
        var list = Array(picks[shift...]) + Array(picks[..<shift])
        for index in 1..<list.count where list[index] == list[index - 1] {
            if let swap = (index + 1..<list.count).first(where: { list[$0] != list[index - 1] }) {
                list.swapAt(index, swap)
            }
        }
        return list
    }
}

/// 플랜 메모에 넣는 표시 줄: 시험 계획으로 만든 플랜을 한꺼번에 찾고 지우기 위함
enum ExamPlanMarker {
    static let prefix = "exam-plan:"

    static func note(name: String, id: UUID) -> String {
        let title = name.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return "\(title)\n\(prefix)\(id.uuidString)"
    }

    static func id(in note: String) -> UUID? {
        for line in note.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix(prefix), let id = UUID(uuidString: String(text.dropFirst(prefix.count))) { return id }
        }
        return nil
    }

    /// 표시 줄 앞의 시험 이름
    static func name(in note: String) -> String {
        guard id(in: note) != nil else { return "" }
        let first = note.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return first.hasPrefix(prefix) ? "" : first
    }
}
