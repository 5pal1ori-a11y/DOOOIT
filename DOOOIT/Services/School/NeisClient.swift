import Foundation

/// NEIS 열린 데이터 API 불러오기 (https, URLSession). 인증키는 Info.plist `NEISAPIKey` (비어 있어도 됨)
/// - 키가 있으면 pSize=1000으로 한 번 (넘치면 pIndex로 이어 받음)
/// - 키가 없으면 한 번에 5줄까지만 오고 pIndex도 안 먹어서, 날짜·교시·학교급 필터로 잘게 나눠 받음 (NeisChunker)
struct NeisClient: Sendable {
    var session: URLSession = .shared
    /// 쪽을 넘기는 최대 횟수 (끝없이 도는 것 방지)
    var maxPages = 20
    /// 테스트·주입용 (기본은 Info.plist 값)
    var key: String? = NeisClient.apiKey

    static var apiKey: String? {
        NeisAPI.sanitizedKey(Bundle.main.object(forInfoDictionaryKey: "NEISAPIKey") as? String)
    }

    var hasKey: Bool { key != nil }

    struct SchoolSearch: Sendable {
        var schools: [School]
        /// 더 있는데 다 못 보여 줌
        var truncated: Bool
    }

    struct DaySlice: Sendable {
        var rows: [NeisParser.Row]
        var incomplete: Bool
    }

    // MARK: 학교 찾기

    func searchSchools(name: String, office: String) async throws -> SchoolSearch {
        let query = name.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return SchoolSearch(schools: [], truncated: false) }
        if hasKey {
            let rows = try await pagedRows(service: "schoolInfo", maxPages: 3) { index, size in
                NeisAPI.schoolSearch(name: query, office: office, key: key, pIndex: index, pSize: size)
            }
            return SchoolSearch(schools: NeisParser.schools(rows), truncated: false)
        }
        // 키가 없으면 5줄뿐: 많으면 초·중·고로 나눠서 한 번씩 더
        let first = try await page(NeisAPI.schoolSearch(name: query, office: office, key: nil, pSize: 5), service: "schoolInfo")
        if first.rows.count >= first.total {
            return SchoolSearch(schools: NeisParser.schools(first.rows), truncated: false)
        }
        var rows = first.rows
        var truncated = false
        try await withThrowingTaskGroup(of: (Int, NeisParser.Page).self) { group in
            for (i, kind) in NeisChunker.schoolKinds.enumerated() {
                group.addTask {
                    (i, try await self.page(NeisAPI.schoolSearch(name: query, office: office, kindName: kind, key: nil, pSize: 5), service: "schoolInfo"))
                }
            }
            var parts: [(Int, NeisParser.Page)] = []
            for try await part in group { parts.append(part) }
            for (_, p) in parts.sorted(by: { $0.0 < $1.0 }) {
                rows = NeisChunker.merge(rows, p.rows)
                if p.total > p.rows.count { truncated = true }
            }
        }
        // 학교급 순서(초 → 중 → 고)로 정렬해서 보여 줌
        let schools = NeisParser.schools(rows).sorted { a, b in
            (rank(a.kind), a.name) < (rank(b.kind), b.name)
        }
        return SchoolSearch(schools: schools, truncated: truncated || schools.count < first.total)
    }

    private func rank(_ kind: SchoolKind) -> Int {
        switch kind {
        case .elementary: return 0
        case .middle: return 1
        case .high: return 2
        case .other: return 3
        }
    }

    /// 학과 이름들 (고등학교). 키가 없으면 앞 5줄뿐이라 complete가 false
    func departments(for school: School) async throws -> (names: [String], complete: Bool) {
        let first = try await page(NeisAPI.majors(school: school, key: key, pSize: NeisAPI.pageSize(hasKey: hasKey)), service: "schoolMajorinfo")
        var rows = first.rows
        if hasKey, rows.count < first.total {
            rows = try await pagedRows(service: "schoolMajorinfo", maxPages: 5) { index, size in
                NeisAPI.majors(school: school, key: key, pIndex: index, pSize: size)
            }
        }
        var names: [String] = []
        for r in rows {
            let name = (r["DDDEP_NM"] ?? "").trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !names.contains(name) { names.append(name) }
        }
        return (names, rows.count >= first.total)
    }

    // MARK: 시간표

    func timetable(for selection: SchoolSelection, weekStart: String) async throws -> TimetableWeek {
        guard let service = selection.school.kind.timetableEndpoint else { throw NeisError.badRequest("") }
        if hasKey {
            let range = NeisDate.timetableRange(weekStart: weekStart)
            let rows = try await pagedRows(service: service) { index, size in
                NeisAPI.timetable(selection: selection, fromYMD: range.from, toYMD: range.to, key: key, pIndex: index, pSize: size)
            }
            return NeisParser.timetable(rows, weekStart: weekStart)
        }
        // 키가 없으면 하루씩 받고, 5줄이 넘는 날은 남은 교시를 따로 받음
        var rows: [NeisParser.Row] = []
        var incomplete = false
        try await withThrowingTaskGroup(of: (String, DaySlice).self) { group in
            for day in NeisChunker.timetableDays(weekStart: weekStart) {
                group.addTask { (day, try await self.timetableDay(selection, service: service, day: day)) }
            }
            var parts: [(String, DaySlice)] = []
            for try await part in group { parts.append(part) }
            for (_, slice) in parts.sorted(by: { $0.0 < $1.0 }) {
                rows += slice.rows
                if slice.incomplete { incomplete = true }
            }
        }
        var week = NeisParser.timetable(rows, weekStart: weekStart)
        week.incomplete = incomplete ? true : nil
        return week
    }

    private func timetableDay(_ selection: SchoolSelection, service: String, day: String) async throws -> DaySlice {
        let first = try await page(NeisAPI.timetable(selection: selection, fromYMD: day, toYMD: day, key: nil, pSize: 5), service: service)
        var rows = first.rows
        guard rows.count < first.total else { return DaySlice(rows: rows, incomplete: false) }
        // 교시 필터는 초·중등 API만 먹어요 (고등학교는 앞 5줄까지만 받을 수 있음)
        if selection.school.kind != .high {
            for period in NeisChunker.missingPeriods(rows: rows, total: first.total) {
                let more = try await page(NeisAPI.timetable(selection: selection, fromYMD: day, toYMD: day, period: period, key: nil, pSize: 5), service: service)
                rows = NeisChunker.merge(rows, more.rows)
            }
            return DaySlice(rows: rows, incomplete: rows.count < first.total)
        }
        return DaySlice(rows: rows, incomplete: true)
    }

    // MARK: 급식

    func meals(for school: School, weekStart: String) async throws -> MealRange {
        let range = NeisDate.mealRange(weekStart: weekStart)
        let first = try await page(NeisAPI.meals(school: school, fromYMD: range.from, toYMD: range.to, key: key, pSize: NeisAPI.pageSize(hasKey: hasKey)), service: "mealServiceDietInfo")
        var rows = first.rows
        if rows.count < first.total {
            if hasKey {
                rows = try await pagedRows(service: "mealServiceDietInfo") { index, size in
                    NeisAPI.meals(school: school, fromYMD: range.from, toYMD: range.to, key: key, pIndex: index, pSize: size)
                }
            } else {
                // 키가 없으면 하루씩 (한 날은 조식·중식·석식 해서 3줄 이하)
                rows = []
                try await withThrowingTaskGroup(of: (String, NeisParser.Page).self) { group in
                    for day in NeisDate.weekDays(start: weekStart) {
                        group.addTask { (day, try await self.page(NeisAPI.meals(school: school, fromYMD: day, toYMD: day, ymd: day, key: nil, pSize: 5), service: "mealServiceDietInfo")) }
                    }
                    var parts: [(String, NeisParser.Page)] = []
                    for try await part in group { parts.append(part) }
                    for (_, p) in parts.sorted(by: { $0.0 < $1.0 }) { rows += p.rows }
                }
            }
        }
        return MealRange(fromYMD: range.from, toYMD: range.to, days: NeisParser.mealDays(rows))
    }

    // MARK: 공통

    /// 키가 있을 때: 첫 쪽에서 전체 줄 수를 알고, 모자라면 다음 쪽을 이어 받음. 데이터 없음(INFO-200)은 빈 목록
    private func pagedRows(service: String, maxPages limit: Int? = nil, url: (_ pIndex: Int, _ pSize: Int) -> URL?) async throws -> [NeisParser.Row] {
        let size = NeisAPI.pageSize(hasKey: hasKey)
        var rows: [NeisParser.Row] = []
        var index = 1
        let cap = min(maxPages, limit ?? maxPages)
        while index <= cap {
            let result = try await page(url(index, size), service: service)
            rows += result.rows
            if result.rows.isEmpty { break }
            guard let next = NeisAPI.nextPage(received: rows.count, total: result.total, currentIndex: index) else { break }
            index = next
        }
        return rows
    }

    private func page(_ url: URL?, service: String) async throws -> NeisParser.Page {
        guard let url else { throw NeisError.badRequest("") }
        return try NeisParser.page(try await fetch(url), service: service)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NeisError.server("HTTP \(http.statusCode)")
            }
            return data
        } catch let error as NeisError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw NeisError.network
        }
    }
}
