import Foundation

/// NEIS 응답(JSON) 읽기 — 네트워크 없이 글자만 다뤄서 어디서든 시험할 수 있어요.
///
/// 응답 모양
///   정상:   {"mealServiceDietInfo":[{"head":[{"list_total_count":N},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{…},…]}]}
///   없음:   {"RESULT":{"CODE":"INFO-200","MESSAGE":"해당하는 데이터가 없습니다."}}
///   오류:   {"RESULT":{"CODE":"ERROR-300","MESSAGE":"필수 값이 누락되어 있습니다. …"}}
enum NeisParser {
    typealias Row = [String: String]

    struct Page: Equatable {
        /// list_total_count (전체 줄 수)
        var total: Int
        var rows: [Row]
    }

    // MARK: 겉 모양

    /// 한 쪽 읽기. 데이터가 없으면 빈 쪽, 그 밖의 오류는 throw
    static func page(_ data: Data, service: String) throws -> Page {
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else {
            throw NeisError.malformed
        }
        // 서비스 키가 없고 RESULT만 있는 경우 (없음 · 오류)
        if let result = root["RESULT"] as? [String: Any] {
            return try handle(result: result)
        }
        guard let blocks = root[service] as? [Any] else { throw NeisError.malformed }
        var total = 0
        var rows: [Row] = []
        for block in blocks {
            guard let dict = block as? [String: Any] else { continue }
            if let head = dict["head"] as? [Any] {
                for item in head {
                    guard let h = item as? [String: Any] else { continue }
                    if let count = h["list_total_count"] { total = int(count) ?? total }
                    if let result = h["RESULT"] as? [String: Any] {
                        let empty = try handle(result: result)
                        if empty.rows.isEmpty, result["CODE"] as? String == "INFO-200" { return empty }
                    }
                }
            }
            if let list = dict["row"] as? [Any] {
                for entry in list {
                    guard let r = entry as? [String: Any] else { continue }
                    rows.append(r.reduce(into: Row()) { $0[$1.key] = string($1.value) })
                }
            }
        }
        return Page(total: max(total, rows.count), rows: rows)
    }

    /// RESULT 처리: 정상이면 빈 쪽(호출한 쪽에서 이어 읽음), INFO-200이면 빈 쪽, 그 밖에는 throw
    private static func handle(result: [String: Any]) throws -> Page {
        let code = (result["CODE"] as? String) ?? ""
        let message = (result["MESSAGE"] as? String) ?? ""
        if let error = NeisError.from(code: code, message: message) {
            if error == .noData { return Page(total: 0, rows: []) }
            throw error
        }
        return Page(total: 0, rows: [])
    }

    private static func string(_ value: Any) -> String {
        if let s = value as? String { return s }
        if value is NSNull { return "" }
        if let n = value as? NSNumber { return n.stringValue }
        return "\(value)"
    }

    private static func int(_ value: Any) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    // MARK: 학교

    static func schools(_ rows: [Row]) -> [School] {
        var seen = Set<String>()
        var result: [School] = []
        for r in rows {
            let office = (r["ATPT_OFCDC_SC_CODE"] ?? "").trimmingCharacters(in: .whitespaces)
            let code = (r["SD_SCHUL_CODE"] ?? "").trimmingCharacters(in: .whitespaces)
            let name = (r["SCHUL_NM"] ?? "").trimmingCharacters(in: .whitespaces)
            guard !office.isEmpty, !code.isEmpty, !name.isEmpty else { continue }
            let school = School(
                officeCode: office, schoolCode: code, name: name,
                kindName: r["SCHUL_KND_SC_NM"] ?? "",
                region: (r["LCTN_SC_NM"]?.isEmpty == false ? r["LCTN_SC_NM"] : r["ATPT_OFCDC_SC_NM"]) ?? "",
                address: [r["ORG_RDNMA"], r["ORG_RDNDA"]].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                highSchoolType: r["HS_SC_NM"] ?? "")
            if seen.insert(school.id).inserted { result.append(school) }
        }
        return result
    }

    // MARK: 급식

    /// <br/> 같은 줄바꿈 표시로 나누기
    static func splitBreaks(_ text: String) -> [String] {
        let unified = text
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\r", with: "")
        return unified.split(separator: "\n", omittingEmptySubsequences: true)
            .map { NeisText.decodeEntities(String($0)).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 요리 한 줄 → 이름 + 알레르기 번호. "새우볶음밥(5.6.9.18)", "미역국 (5.6.9)", "*수제 요거트(2)"
    /// 번호는 줄 맨 끝의 괄호 하나만 알레르기로 봐요 ("배추김치(1) (9)" → 이름 "배추김치(1)", 알레르기 9)
    static func dish(_ line: String) -> Dish {
        var name = line.trimmingCharacters(in: .whitespaces)
        while let first = name.first, "*·•".contains(first) { name.removeFirst() }
        var numbers: [Int] = []
        let pattern = #"\s*\((\d{1,2}(?:\s*[.,]\s*\d{1,2})*)\s*[.,]?\s*\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = name as NSString
            if let match = regex.firstMatch(in: name, range: NSRange(location: 0, length: ns.length)) {
                let inner = ns.substring(with: match.range(at: 1))
                let values = inner.split(whereSeparator: { $0 == "." || $0 == "," || $0 == " " }).compactMap { Int($0) }
                // 알레르기 번호는 1~19만. 그 밖의 숫자가 섞인 괄호는 이름의 일부로 둠
                if !values.isEmpty, values.allSatisfy({ (1...19).contains($0) }) {
                    numbers = values
                    name = ns.replacingCharacters(in: match.range, with: "")
                }
            }
        }
        name = name.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        var uniq: [Int] = []
        for n in numbers where !uniq.contains(n) { uniq.append(n) }
        return Dish(name: name, allergies: uniq.sorted())
    }

    static func dishes(_ text: String) -> [Dish] {
        splitBreaks(text).map(dish).filter { !$0.name.isEmpty }
    }

    /// "탄수화물(g) : 109.0<br/>단백질(g) : 31.2" → 줄들
    static func nutrients(_ text: String) -> [NutrientLine] {
        splitBreaks(text).compactMap { line in
            guard let colon = line.firstIndex(where: { $0 == ":" || $0 == "：" }) else { return nil }
            let label = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return label.isEmpty || value.isEmpty ? nil : NutrientLine(label: label, value: value)
        }
    }

    /// 급식 줄들 → 날짜별 묶음 (날짜 오름차순, 식사는 조식 → 중식 → 석식)
    static func mealDays(_ rows: [Row]) -> [MealDay] {
        var byDay: [String: [Meal]] = [:]
        for r in rows {
            let ymd = r["MLSV_YMD"] ?? ""
            guard NeisDate.isValid(ymd), let kind = MealKind(neisCode: r["MMEAL_SC_CODE"] ?? "") ?? kindFromName(r["MMEAL_SC_NM"] ?? "") else { continue }
            let list = dishes(r["DDISH_NM"] ?? "")
            guard !list.isEmpty else { continue }
            let meal = Meal(kind: kind, dishes: list, calories: (r["CAL_INFO"] ?? "").trimmingCharacters(in: .whitespaces),
                            nutrients: nutrients(r["NTR_INFO"] ?? ""))
            // 같은 날 같은 식사가 두 번 오면 앞엣것 유지
            if !(byDay[ymd] ?? []).contains(where: { $0.kind == kind }) { byDay[ymd, default: []].append(meal) }
        }
        return byDay.keys.sorted().map { ymd in
            MealDay(ymd: ymd, meals: (byDay[ymd] ?? []).sorted { $0.kind.rawValue < $1.kind.rawValue })
        }
    }

    private static func kindFromName(_ name: String) -> MealKind? {
        switch name.trimmingCharacters(in: .whitespaces) {
        case "조식": return .breakfast
        case "중식": return .lunch
        case "석식": return .dinner
        default: return nil
        }
    }

    // MARK: 시간표

    /// 시간표 줄들 → 한 주. 같은 날 같은 교시에 줄이 여럿(선택과목 등)이면 과목을 " / "로 이어 붙임
    static func timetable(_ rows: [Row], weekStart: String) -> TimetableWeek {
        var slots: [String: [String]] = [:]       // "ymd|period" → 과목들
        var order: [(String, Int)] = []
        var departments: [String] = []
        var classNames: [String] = []
        for r in rows {
            let ymd = r["ALL_TI_YMD"] ?? ""
            guard NeisDate.isValid(ymd), let period = Int((r["PERIO"] ?? "").trimmingCharacters(in: .whitespaces)), period > 0 else { continue }
            let subject = cleanSubject(r["ITRT_CNTNT"] ?? "")
            let key = "\(ymd)|\(period)"
            if slots[key] == nil { order.append((ymd, period)); slots[key] = [] }
            if !subject.isEmpty, !(slots[key] ?? []).contains(subject) { slots[key]?.append(subject) }
            if let dept = r["DDDEP_NM"], !dept.isEmpty, !departments.contains(dept) { departments.append(dept) }
            if let cls = r["CLASS_NM"], !cls.isEmpty, !classNames.contains(cls) { classNames.append(cls) }
        }
        let cells = order.map { TimetableCell(ymd: $0.0, period: $0.1, subject: (slots["\($0.0)|\($0.1)"] ?? []).joined(separator: " / ")) }
            .sorted { ($0.ymd, $0.period) < ($1.ymd, $1.period) }
        return TimetableWeek(weekStart: weekStart, cells: cells, departments: departments, classNames: classNames)
    }

    /// 앞뒤 공백 · 겹친 공백 정리. "* 국어" 같은 앞 표시는 없앰
    static func cleanSubject(_ text: String) -> String {
        var s = NeisText.decodeEntities(text).trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("*") { s.removeFirst() }
        return s.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// 쉬는 날 안내 글인지 ("토요휴업일", "재량휴업일", "방학" …)
    static func isHolidayText(_ text: String) -> Bool {
        ["휴업", "방학", "공휴", "휴일", "개교기념", "대체"].contains { text.contains($0) }
    }
}
