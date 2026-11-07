import Foundation

/// NEIS 열린 데이터 API 주소 만들기 (https://open.neis.go.kr/hub/)
/// 보내는 것: 학교 코드 · 학년/반 · 날짜 · (있다면) 인증키. 키는 기기 설정(Info.plist)에서 읽고 저장소에는 두지 않아요.
///
/// 실제로 확인한 동작 (CI에서 키 없이 받은 응답):
/// - 키가 없으면 한 번에 최대 5줄. pIndex·pSize는 무시돼서 쪽을 넘겨도 같은 5줄이 와요 (KEY=sample은 오류)
/// - 대신 날짜(TI_FROM_YMD/TI_TO_YMD, MLSV_YMD), 교시(PERIO, 초·중만), 학교종류(SCHUL_KND_SC_NM), 교육청(ATPT_OFCDC_SC_CODE) 필터는 먹어요
/// - 그래서 키가 없을 땐 필터로 잘게 나눠 여러 번 받아요 (NeisChunker), 키가 있으면 pSize=1000 한 번
enum NeisAPI {
    static let host = "open.neis.go.kr"
    static let base = "https://open.neis.go.kr/hub/"

    /// 인증키 없이 받을 때 한 번에 올 수 있는 줄 수. 키가 있으면 최대 1000.
    static let keylessPageSize = 5
    static let keyedPageSize = 1000

    static func pageSize(hasKey: Bool) -> Int { hasKey ? keyedPageSize : keylessPageSize }

    /// Info.plist 값에서 쓸 수 있는 키만 (빈 글자 · 빌드 변수 자리표시는 없는 것으로)
    static func sanitizedKey(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") || trimmed.lowercased() == "sample" { return nil }
        return trimmed
    }

    static func url(endpoint: String, params: [(String, String)], key: String? = nil, pIndex: Int = 1, pSize: Int) -> URL? {
        guard var comps = URLComponents(string: base + endpoint) else { return nil }
        var items: [(String, String)] = []
        if let key, !key.isEmpty { items.append(("KEY", key)) }
        items.append(("Type", "json"))
        items.append(("pIndex", String(max(1, pIndex))))
        items.append(("pSize", String(max(1, pSize))))
        for (name, value) in params where !value.isEmpty { items.append((name, value)) }
        // 값 안의 + & = 같은 글자까지 직접 인코딩
        comps.percentEncodedQuery = items.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&")
        return comps.url
    }

    private static let allowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    // MARK: 요청 종류

    /// 학교 찾기. office(교육청 코드) · kindName(초등학교 …)으로 좁힐 수 있어요
    static func schoolSearch(name: String, office: String = "", kindName: String = "", key: String?, pIndex: Int = 1, pSize: Int) -> URL? {
        url(endpoint: "schoolInfo", params: [
            ("SCHUL_NM", name.trimmingCharacters(in: .whitespaces)),
            ("ATPT_OFCDC_SC_CODE", office), ("SCHUL_KND_SC_NM", kindName)
        ], key: key, pIndex: pIndex, pSize: pSize)
    }

    /// 학교 학과 목록 (고등학교)
    static func majors(school: School, key: String?, pIndex: Int = 1, pSize: Int) -> URL? {
        url(endpoint: "schoolMajorinfo", params: [
            ("ATPT_OFCDC_SC_CODE", school.officeCode), ("SD_SCHUL_CODE", school.schoolCode)
        ], key: key, pIndex: pIndex, pSize: pSize)
    }

    /// 급식. ymd가 있으면 그날 하루(조식·중식·석식 모두), 없으면 from~to
    static func meals(school: School, fromYMD: String, toYMD: String, ymd: String = "", key: String?, pIndex: Int = 1, pSize: Int) -> URL? {
        var params: [(String, String)] = [("ATPT_OFCDC_SC_CODE", school.officeCode), ("SD_SCHUL_CODE", school.schoolCode)]
        if ymd.isEmpty {
            params += [("MLSV_FROM_YMD", fromYMD), ("MLSV_TO_YMD", toYMD)]
        } else {
            params.append(("MLSV_YMD", ymd))
        }
        return url(endpoint: "mealServiceDietInfo", params: params, key: key, pIndex: pIndex, pSize: pSize)
    }

    /// 시간표. period가 있으면 그 교시만 (초·중등 API에서 먹어요)
    static func timetable(selection: SchoolSelection, fromYMD: String, toYMD: String, period: Int? = nil, key: String?, pIndex: Int = 1, pSize: Int) -> URL? {
        guard let endpoint = selection.school.kind.timetableEndpoint else { return nil }
        var params: [(String, String)] = [
            ("ATPT_OFCDC_SC_CODE", selection.school.officeCode), ("SD_SCHUL_CODE", selection.school.schoolCode),
            ("GRADE", String(selection.grade)), ("CLASS_NM", String(selection.classNum)),
            ("TI_FROM_YMD", fromYMD), ("TI_TO_YMD", toYMD)
        ]
        if selection.school.kind == .high, !selection.department.isEmpty { params.append(("DDDEP_NM", selection.department)) }
        if let period { params.append(("PERIO", String(period))) }
        return url(endpoint: endpoint, params: params, key: key, pIndex: pIndex, pSize: pSize)
    }

    // MARK: 쪽 나누기 (키가 있을 때)

    /// 다음에 받을 쪽 번호. 다 받았으면 nil
    static func nextPage(received: Int, total: Int, currentIndex: Int) -> Int? {
        received < total ? currentIndex + 1 : nil
    }

    /// 총 개수와 한 쪽 크기로 필요한 요청 수
    static func pageCount(total: Int, pageSize: Int) -> Int {
        guard total > 0, pageSize > 0 else { return 0 }
        return (total + pageSize - 1) / pageSize
    }
}

/// 키가 없어서 한 번에 5줄만 올 때, 필터로 잘게 나눠 받는 계획
enum NeisChunker {
    /// 학교 검색: 학교급별로 나눠서 (초·중·고 각각 5줄 → 최대 15줄)
    static let schoolKinds = ["초등학교", "중학교", "고등학교"]

    /// 같은 줄(모든 값이 같음) 한 번만
    static func merge(_ base: [NeisParser.Row], _ more: [NeisParser.Row]) -> [NeisParser.Row] {
        var result = base
        for row in more where !result.contains(row) { result.append(row) }
        return result
    }

    /// 하루 시간표를 5줄만 받았을 때 더 받아야 하는 교시들.
    /// 줄은 날짜·교시 순이라 받은 마지막 교시부터 남은 줄 수만큼 이어짐 (마지막 교시는 일부만 왔을 수 있어 다시 받음)
    static func missingPeriods(rows: [NeisParser.Row], total: Int, maxPeriod: Int = 12) -> [Int] {
        guard total > rows.count else { return [] }
        let seen = rows.compactMap { Int(($0["PERIO"] ?? "").trimmingCharacters(in: .whitespaces)) }
        guard let last = seen.max() else { return [] }
        let remaining = total - rows.count
        let upper = min(last + remaining, maxPeriod)
        return Array(last...max(last, upper)).filter { $0 <= maxPeriod }
    }

    /// 시간표를 키 없이 받을 날짜들: 월~금 + 토
    static func timetableDays(weekStart: String) -> [String] {
        NeisDate.weekDays(start: weekStart, includeSaturday: true)
    }
}
