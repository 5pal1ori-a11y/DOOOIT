// 두잇 AI 테스트용 가짜(stub): iOS 전용 타입과 앱 데이터(DoitActions)를 흉내 냄
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// ---- Linux stubs for UIKit / SwiftData parts ----
class UIImage: Equatable { static func == (a: UIImage, b: UIImage) -> Bool { a === b } }
enum OCRService {
    static func recognize(_ image: UIImage, languageCorrection: Bool = true, languages: [String] = ["ko-KR", "en-US"]) async throws -> [OCRLine] { [] }
    static func recognizeMath(_ image: UIImage) async throws -> [OCRLine] { [] }
    static func readMathProblem(_ image: UIImage, thorough: Bool = true) async -> (text: String, improved: Bool) { ("", false) }
}
enum MathSymbolBar { static func pretty(_ s: String) -> String { s } }
@MainActor final class DoitActions {
    static let shared = DoitActions()
    var log: [String] = []
    var plansToday: [String] = ["수학 공부", "영어 학원"]
    var words: [(String, String)] = [("abundant", "풍부한"), ("resilient", "회복력 있는"), ("apple", "사과"), ("run", "달리다"), ("brave", "용감한")]
    func drainLog() -> [String] { defer { log = [] }; return log }
    func addMathNote(title: String?, problem: String, answer: String?, image: UIImage?) -> String { log.append("note"); return "오답노트 저장" }
    func addMemo(_ t: String) -> String { log.append("memo"); return "메모 저장: \(t.prefix(30))" }
    func addPlan(title: String, dateText: String?, timeText: String?, minutes: Int?, isStudy: Bool, allDay: Bool, repeatText: String?) -> String { log.append("plan"); return "[ADD PLAN] \(title) date=\(dateText ?? "-") time=\(timeText ?? "-") min=\(minutes ?? -1) study=\(isStudy)" }
    func addWords(_ pairs: [(String, String)]) -> String { "[ADD WORDS] \(pairs)" }
    func chatContext() -> DoitChat.Context { DoitChat.Context(now: Date(), todayMinutes: 95, goalMinutes: 180, remainingPlans: 2, dDay: "D-Day 기말고사: D-12") }
    func open(_ s: String) -> String { "[OPEN \(s)]" }
    func overview(dateText: String?) -> String { "[OVERVIEW \(dateText ?? "오늘")]" }
    func plans(on day: Date) -> [String] { plansToday }
    func quizWords(_ n: Int) -> [(term: String, meaning: String)] { Array(words.shuffled().prefix(n)).map { ($0.0, $0.1) } }
    func records(kind: String) -> String { "[RECORDS \(kind)]" }
    func savedMeaning(of t: String) -> String? { words.first { $0.0 == t.lowercased() }?.1 }
    func searchMemos(_ q: String) -> String { "[SEARCH \(q)]" }
    func settings(dDayTitle: String?, dDayDate: String?, studyGoalMinutes: Int?, wordGoal: Int?) -> String { "[SETTINGS \(dDayTitle ?? "-") \(dDayDate ?? "-") \(studyGoalMinutes ?? -1) \(wordGoal ?? -1)]" }
    func stats(days: Int) -> String { "[STATS \(days)]" }
    func studyCategoryNames() -> [String] { ["국어", "영어", "수학"] }
    func timer(action: String, title: String?, minutes: Int?) -> String { "[TIMER \(action) \(title ?? "-") \(minutes ?? -1)]" }
    func updatePlan(title: String, dateText: String?, action: String) -> String { "[UPDATE \(action) \(title)]" }
    var wordCount: Int { words.count }
    func weeklyReportText() -> String { "[WEEKLY REPORT]" }
}

// 사진 분석 (테스트에서는 항상 "문제 사진"으로 처리)
struct GraphAnalysisStub { enum Kind { case linear, quadratic, cubic, circle, unknown }; var kind: Kind = .unknown; var equation: String? }
struct ImageAnalysis {
    enum Kind { case mathProblem, document, graph, figure, photo, qrCode, empty }
    var kind: Kind = .mathProblem
    var graph: GraphAnalysisStub?
    var message: String = ""
}
enum VisionAnalyzer { static func analyze(_ image: UIImage) async -> ImageAnalysis { ImageAnalysis() } }
