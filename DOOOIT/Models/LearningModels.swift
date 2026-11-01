import Foundation
import SwiftData

// MARK: - 시험 벼락치기

struct CramUnit: Codable, Identifiable, Hashable {
    var id = UUID()
    var subject: String
    var chapter: String
    var title: String
    /// 완료한 단계 (LearnStep.rawValue)
    var done: [String] = []
}

@Model
final class ExamPlan {
    var id: UUID = UUID()
    var name: String = ""
    var examDate: Date = Date()
    var modeRaw: String = "standard"
    var unitsData: Data?
    var createdAt: Date = Date()

    init(name: String, examDate: Date, units: [CramUnit]) {
        self.id = UUID()
        self.name = name
        self.examDate = examDate
        self.createdAt = Date()
        self.units = units
    }

    var isBooster: Bool {
        get { modeRaw == "booster" }
        set { modeRaw = newValue ? "booster" : "standard" }
    }

    var units: [CramUnit] {
        get { unitsData.flatMap { try? JSONDecoder().decode([CramUnit].self, from: $0) } ?? [] }
        set { unitsData = try? JSONEncoder().encode(newValue) }
    }

    var dDay: Int {
        Calendar.current.dateComponents([.day], from: Date().startOfDay, to: examDate.startOfDay).day ?? 0
    }
}

// MARK: - AI가 만든 학습 자료 캐시

@Model
final class StudyContent {
    var key: String = ""
    var data: Data = Data()
    var createdAt: Date = Date()

    init(key: String, data: Data) {
        self.key = key
        self.data = data
        self.createdAt = Date()
    }
}

// MARK: - 문제 풀이 기록 (취약 유형 분석용)

@Model
final class QuizRecord {
    var subject: String = ""
    var unit: String = ""
    var step: String = ""
    var correct: Int = 0
    var total: Int = 0
    var date: Date = Date()

    init(subject: String, unit: String, step: String, correct: Int, total: Int) {
        self.subject = subject
        self.unit = unit
        self.step = step
        self.correct = correct
        self.total = total
        self.date = Date()
    }
}

// MARK: - AI에게 질문하기

@Model
final class AIQuestion {
    var id: UUID = UUID()
    var question: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var answer: String = ""
    var subject: String = ""
    var drawingData: Data?
    /// 0: 평가 안 함, 1: 도움 됨, -1: 도움 안 됨
    var helpful: Int = 0
    var createdAt: Date = Date()

    init(question: String, imageData: Data?, subject: String) {
        self.id = UUID()
        self.question = question
        self.imageData = imageData
        self.subject = subject
        self.createdAt = Date()
    }
}

// MARK: - 2022 개정 교육과정 단원 (고1 공통과목)

struct CurriculumUnit: Identifiable, Hashable {
    let chapter: String
    let title: String
    var id: String { chapter + "/" + title }
}

struct CurriculumSubject: Identifiable, Hashable {
    let name: String
    let symbol: String
    let units: [CurriculumUnit]
    var id: String { name }
}

enum Curriculum {
    private static func make(_ list: [(String, [String])]) -> [CurriculumUnit] {
        list.flatMap { chapter, titles in titles.map { CurriculumUnit(chapter: chapter, title: $0) } }
    }

    /// AI 학습에서 고를 수 있는 모든 과목: 고1 공통과목 + 초등 ~ 대학교 국·영·수·과·사
    static let subjects: [CurriculumSubject] = highSchoolCommon + DoitCurriculum.studySubjects.map { item in
        let symbols = ["국어": "book.fill", "영어": "character.book.closed.fill", "수학": "function", "과학": "atom", "사회": "globe.asia.australia.fill"]
        return CurriculumSubject(name: item.name, symbol: symbols[item.subject] ?? "book",
                                 units: item.units.map { CurriculumUnit(chapter: item.name, title: $0) })
    }

    static let highSchoolCommon: [CurriculumSubject] = [
        CurriculumSubject(name: "공통수학1", symbol: "function", units: make([
            ("다항식", ["다항식의 연산", "항등식과 나머지정리", "인수분해"]),
            ("방정식과 부등식", ["복소수와 이차방정식", "이차방정식과 이차함수", "여러 가지 방정식과 부등식"]),
            ("경우의 수", ["합의 법칙과 곱의 법칙", "순열과 조합"]),
            ("행렬", ["행렬과 그 연산"])
        ])),
        CurriculumSubject(name: "공통수학2", symbol: "function", units: make([
            ("도형의 방정식", ["선분의 내분", "두 직선의 평행과 수직", "원의 방정식", "도형의 이동"]),
            ("집합과 명제", ["집합의 연산", "명제와 조건", "절대부등식"]),
            ("함수와 그래프", ["합성함수와 역함수", "유리함수", "무리함수"])
        ])),
        CurriculumSubject(name: "공통국어", symbol: "book.fill", units: make([
            ("문학", ["현대시", "고전시가", "현대소설", "고전소설"]),
            ("문법", ["음운의 변동", "품사와 문장 성분", "문장의 짜임"]),
            ("독서", ["비문학 독해 전략", "논증 분석"])
        ])),
        CurriculumSubject(name: "공통영어", symbol: "character.book.closed.fill", units: make([
            ("어법", ["시제와 태", "관계사", "분사와 분사구문", "가정법"]),
            ("독해", ["주제·요지 파악", "빈칸 추론", "글의 순서와 문장 삽입"]),
            ("어휘", ["필수 어휘와 어구"])
        ]))
    ]
}
