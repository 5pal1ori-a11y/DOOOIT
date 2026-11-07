import Foundation

// 학교 정보 (NEIS 교육행정정보시스템 공개 API) — 순수 Foundation 모델
// 시간표·급식은 "학교 코드 + 학년/반 + 날짜"만 보내서 받아 와요. 기기 밖으로 다른 정보는 보내지 않아요.

// MARK: - 학교

enum SchoolKind: String, Codable, Sendable {
    case elementary, middle, high, other

    /// NEIS의 학교종류명 (SCHUL_KND_SC_NM)
    init(neisName: String) {
        switch neisName {
        case "초등학교": self = .elementary
        case "중학교": self = .middle
        case "고등학교": self = .high
        default: self = .other
        }
    }

    /// 고를 수 있는 학년
    var grades: ClosedRange<Int> { self == .elementary ? 1...6 : 1...3 }

    /// 시간표 API 이름
    var timetableEndpoint: String? {
        switch self {
        case .elementary: return "elsTimetable"
        case .middle: return "misTimetable"
        case .high: return "hisTimetable"
        case .other: return nil
        }
    }

    /// 화면에 보일 이름 (번역 키)
    var title: String {
        switch self {
        case .elementary: return "초등학교"
        case .middle: return "중학교"
        case .high: return "고등학교"
        case .other: return "학교"
        }
    }
}

struct School: Codable, Hashable, Identifiable, Sendable {
    /// 시도교육청 코드 (ATPT_OFCDC_SC_CODE)
    var officeCode: String
    /// 표준학교코드 (SD_SCHUL_CODE)
    var schoolCode: String
    var name: String
    /// 학교종류명 그대로 (초등학교, 중학교, 고등학교, 특수학교 …)
    var kindName: String
    /// 시도 이름 (서울특별시 …)
    var region: String
    var address: String
    /// 고등학교 구분 (일반고, 특성화고 …) — 없으면 빈 글자
    var highSchoolType: String = ""

    var id: String { officeCode + "/" + schoolCode }
    var kind: SchoolKind { SchoolKind(neisName: kindName) }

    /// 시도 이름 줄임 ("서울특별시" → "서울", "경기도" → "경기", "충청북도" → "충북")
    var shortRegion: String { NeisText.shortRegion(region) }
}

/// 고른 학교 + 학년/반 (UserDefaults에 JSON으로 저장)
struct SchoolSelection: Codable, Hashable, Sendable {
    var school: School
    var grade: Int
    var classNum: Int
    /// 고등학교 학과 이름 (DDDEP_NM) — 여러 학과가 같은 반 번호를 쓰는 학교에서만 고름
    var department: String = ""

    var classLabel: String { "\(grade)학년 \(classNum)반" }

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String) -> SchoolSelection? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        guard let value = try? JSONDecoder().decode(SchoolSelection.self, from: data) else { return nil }
        guard value.grade >= 1, value.classNum >= 1, !value.school.schoolCode.isEmpty else { return nil }
        return value
    }
}

/// 예전에 저장한 값(새 칸이 없는 JSON)도 읽도록 빠진 칸은 기본값
extension School {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(officeCode: try c.decode(String.self, forKey: .officeCode),
                  schoolCode: try c.decode(String.self, forKey: .schoolCode),
                  name: try c.decode(String.self, forKey: .name),
                  kindName: try c.decode(String.self, forKey: .kindName),
                  region: try c.decode(String.self, forKey: .region),
                  address: try c.decodeIfPresent(String.self, forKey: .address) ?? "",
                  highSchoolType: try c.decodeIfPresent(String.self, forKey: .highSchoolType) ?? "")
    }
}

extension SchoolSelection {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(school: try c.decode(School.self, forKey: .school),
                  grade: try c.decode(Int.self, forKey: .grade),
                  classNum: try c.decode(Int.self, forKey: .classNum),
                  department: try c.decodeIfPresent(String.self, forKey: .department) ?? "")
    }
}

// MARK: - 시간표

struct TimetableCell: Codable, Hashable, Sendable {
    /// yyyyMMdd
    var ymd: String
    var period: Int
    /// 과목 (빈 글자 가능)
    var subject: String
}

struct TimetableWeek: Codable, Equatable, Sendable {
    /// 그 주 월요일 yyyyMMdd
    var weekStart: String
    var cells: [TimetableCell]
    /// 응답에 들어 있던 학과 이름들 (고등학교: 같은 학년/반 번호가 학과마다 있을 때)
    var departments: [String] = []
    /// 응답에 들어 있던 반 번호들 (학년만 보냈을 때 쓰려고 — 보통 비어 있음)
    var classNames: [String] = []
    /// 키 없이 받아서 일부 교시를 못 받은 경우 true (nil이면 모두 받음)
    var incomplete: Bool? = nil

    /// 수업 칸이 하나도 없음 (휴업일 글만 있어도 비어 있는 것으로)
    var isEmpty: Bool { cells.allSatisfy { $0.subject.isEmpty || NeisParser.isHolidayText($0.subject) } }

    /// 그 주 안에서 가장 큰 교시 (쉬는 날 글만 있는 날은 빼고)
    var maxPeriod: Int { cells.filter { !$0.subject.isEmpty && !isHolidayDay($0.ymd) }.map(\.period).max() ?? 0 }

    func subject(_ ymd: String, period: Int) -> String {
        cells.first { $0.ymd == ymd && $0.period == period }?.subject ?? ""
    }

    /// 그날 시간표 (교시 순)
    func day(_ ymd: String) -> [TimetableCell] {
        cells.filter { $0.ymd == ymd && !$0.subject.isEmpty }.sorted { $0.period < $1.period }
    }

    /// 그날 칸이 모두 쉬는 날 안내 글 ("토요휴업일", "재량휴업일" …)
    func isHolidayDay(_ ymd: String) -> Bool {
        let items = day(ymd)
        return !items.isEmpty && items.allSatisfy { NeisParser.isHolidayText($0.subject) }
    }

    /// 쉬는 날 안내 글 (없으면 빈 글자)
    func holidayText(_ ymd: String) -> String {
        isHolidayDay(ymd) ? (day(ymd).first?.subject ?? "") : ""
    }

    /// 토요일 수업이 있는지 (토요휴업일 글뿐이면 없음)
    var hasSaturday: Bool {
        guard let sat = NeisDate.addDays(weekStart, 5) else { return false }
        return !day(sat).isEmpty && !isHolidayDay(sat)
    }
}

// MARK: - 급식

enum MealKind: Int, Codable, CaseIterable, Sendable {
    case breakfast = 1, lunch = 2, dinner = 3

    init?(neisCode: String) {
        guard let value = Int(neisCode.trimmingCharacters(in: .whitespaces)), let kind = MealKind(rawValue: value) else { return nil }
        self = kind
    }

    /// 화면 글자 (번역 키)
    var title: String {
        switch self {
        case .breakfast: return "조식"
        case .lunch: return "중식"
        case .dinner: return "석식"
        }
    }
}

struct Dish: Codable, Hashable, Sendable {
    var name: String
    /// 알레르기 번호 (1~19)
    var allergies: [Int]
}

struct NutrientLine: Codable, Hashable, Sendable {
    /// "탄수화물(g)"
    var label: String
    /// "109.0"
    var value: String
}

struct Meal: Codable, Hashable, Sendable {
    var kind: MealKind
    var dishes: [Dish]
    /// "640.5 Kcal"
    var calories: String
    var nutrients: [NutrientLine]

    /// 이 식사에 들어 있는 모든 알레르기 번호 (오름차순)
    var allAllergies: [Int] { Array(Set(dishes.flatMap(\.allergies))).sorted() }
}

struct MealDay: Codable, Hashable, Sendable {
    /// yyyyMMdd
    var ymd: String
    var meals: [Meal]

    func meal(_ kind: MealKind) -> Meal? { meals.first { $0.kind == kind } }
}

struct MealRange: Codable, Equatable, Sendable {
    var fromYMD: String
    var toYMD: String
    var days: [MealDay]

    func day(_ ymd: String) -> MealDay? { days.first { $0.ymd == ymd } }
}

// MARK: - 알레르기 표

enum Allergen {
    /// 학교급식법 표시 대상 19가지
    static let names: [Int: String] = [
        1: "난류", 2: "우유", 3: "메밀", 4: "땅콩", 5: "대두", 6: "밀", 7: "고등어", 8: "게", 9: "새우",
        10: "돼지고기", 11: "복숭아", 12: "토마토", 13: "아황산류", 14: "호두", 15: "닭고기", 16: "쇠고기",
        17: "오징어", 18: "조개류(굴,전복,홍합 포함)", 19: "잣"
    ]

    static func name(_ number: Int) -> String? { names[number] }

    static var legend: [(number: Int, name: String)] {
        names.keys.sorted().map { ($0, names[$0] ?? "") }
    }
}

// MARK: - 오류

enum NeisError: Error, Equatable, Sendable {
    /// INFO-200: 해당하는 데이터가 없어요 (정상 — 빈 결과로 다룸)
    case noData
    /// 인증키 문제 (INFO-100, ERROR-290 …)
    case badKey(String)
    /// 사용량 초과 (ERROR-337 …) · 이용 제한 (INFO-300)
    case limited(String)
    /// 요청 값 문제 (ERROR-300, ERROR-333, ERROR-336 …)
    case badRequest(String)
    /// 서버 문제 (ERROR-500, ERROR-600 …)
    case server(String)
    /// 모양이 달라서 못 읽음
    case malformed
    /// 네트워크 (연결 끊김 등)
    case network

    /// 오류 코드 → 종류
    static func from(code: String, message: String) -> NeisError? {
        switch code {
        case "INFO-000": return nil
        case "INFO-200": return .noData
        case "INFO-100", "INFO-290", "ERROR-290": return .badKey(message)
        case "INFO-300", "ERROR-337": return .limited(message)
        case "ERROR-300", "ERROR-310", "ERROR-333", "ERROR-336": return .badRequest(message)
        case "ERROR-500", "ERROR-600", "ERROR-601": return .server(message)
        default: return code.hasPrefix("ERROR") ? .server(message) : .badRequest(message)
        }
    }
}

// MARK: - 글자 도우미

enum NeisText {
    static func shortRegion(_ region: String) -> String {
        let map: [String: String] = [
            "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천", "광주광역시": "광주",
            "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종", "경기도": "경기", "강원특별자치도": "강원",
            "강원도": "강원", "충청북도": "충북", "충청남도": "충남", "전북특별자치도": "전북", "전라북도": "전북",
            "전라남도": "전남", "경상북도": "경북", "경상남도": "경남", "제주특별자치도": "제주"
        ]
        return map[region] ?? region
    }

    static func decodeEntities(_ text: String) -> String {
        var s = text
        for (from, to) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " ")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s
    }
}
