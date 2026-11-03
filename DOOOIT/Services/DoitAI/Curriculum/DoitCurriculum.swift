import Foundation

/// 초등학교 ~ 대학교 교육과정 개념 사전 (국어·영어·수학·과학·사회)
/// 과목별 파일(Knowledge*.swift)에 나눠 담고, DoitKnowledge가 모두 모아서 검색해요.
enum SchoolLevel: String, CaseIterable, Codable {
    case elementary = "초등"
    case middle = "중학교"
    case high = "고등학교"
    case university = "대학교"
}

struct CurriculumEntry {
    let level: SchoolLevel
    /// 교과 단원 이름 (예: "분수의 덧셈과 뺄셈", "이차방정식", "미적분학")
    let unit: String
    /// 개념 이름 (첫 번째가 대표 이름, 나머지는 다른 이름·약어)
    let names: [String]
    /// 2~5문장 설명 (해요체). 줄바꿈으로 문장 묶음을 나누고, 예시는 "예: …" 줄로
    let body: String
}

/// 데이터 파일에서 짧게 쓰기 위한 도우미
func ce(_ level: SchoolLevel, _ unit: String, _ names: [String], _ body: String) -> CurriculumEntry {
    CurriculumEntry(level: level, unit: unit, names: names, body: body)
}

enum DoitCurriculum {
    /// 과목 → 개념 목록
    static var bySubject: [(subject: String, entries: [CurriculumEntry])] { allSubjects }

    /// 과목별 전체 개념 (기본 사전 + 보충 사전). 한 번만 합쳐 둠
    static let allSubjects: [(subject: String, entries: [CurriculumEntry])] = [
        ("국어", korean + koreanMore + koreanFill),
        ("영어", english + englishMore),
        ("수학", math + mathMiddleMore + mathMore + mathFill),
        ("과학", science + scienceMiddleMore + scienceMore + scienceFill),
        ("사회", social + socialMiddleMore + socialMore + socialFill)
    ]

    /// AI 학습 화면에 보여줄 과목·단원 (예: "중학교 수학" → 단원들)
    static var studySubjects: [(name: String, level: SchoolLevel, subject: String, units: [String])] {
        var result: [(String, SchoolLevel, String, [String])] = []
        for level in SchoolLevel.allCases {
            for (subject, entries) in bySubject {
                var units: [String] = []
                for item in entries where item.level == level && !units.contains(item.unit) { units.append(item.unit) }
                // 영어 문법 단원 (교육과정 사전에 없는 이름만 더함)
                if subject == "영어" { units += DoitGrammar.extraUnitNames(level: level, existing: units) }
                units = orderedByGrade(units, level: level, subject: subject)
                if !units.isEmpty { result.append(("\(level.rawValue) \(subject)", level, subject, units)) }
            }
        }
        return result
    }
}
