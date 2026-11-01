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

    /// 고1 공통과목 (단원 목록은 DoitStudy.commonSubjects 한 곳에서 관리)
    static let highSchoolCommon: [CurriculumSubject] = DoitStudy.commonSubjects.map { common in
        let symbols = ["국어": "book.fill", "영어": "character.book.closed.fill", "수학": "function"]
        return CurriculumSubject(name: common.name, symbol: symbols[common.subject] ?? "book", units: make(common.chapters))
    }
}
