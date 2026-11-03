#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 화면 사진 찍기용 (Debug 빌드에서만 · Release/TestFlight에는 들어가지 않음)
/// - 실행 인자: `-uiShot <화면>` (+ `-uiDark`)
/// - 데모 계정 · 메모리 저장소(예시 데이터)로 바로 그 화면을 엶. 키체인·계정 저장소는 건드리지 않음
/// - 설정값은 등록 기본값(registration domain)으로만 넣어서 저장되지 않음
enum UIShotScreen: String, CaseIterable {
    case home, study, words, mathList, mathNote, ai, planner, account, accountSettings, timer, auth
    case badges, badgeNew, mockExam, mockResult, soundMixer, voice
}

@MainActor
enum UIShot {
    static let screen: UIShotScreen? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiShot"), i + 1 < args.count else { return nil }
        return UIShotScreen(rawValue: args[i + 1])
    }()

    static var isActive: Bool { screen != nil }
    static var isDark: Bool { ProcessInfo.processInfo.arguments.contains("-uiDark") }

    static func matches(_ screens: UIShotScreen...) -> Bool {
        guard let screen else { return false }
        return screens.contains(screen)
    }

    static var demoUser: UserAccount? {
        screen == .auth ? nil : UserAccount(id: "uishot.demo", name: "김두잇", email: "dooit@example.com", provider: .email, createdAt: Date())
    }

    static var tab: AppTab {
        switch screen {
        case .study, .words, .mathList, .mathNote, .mockExam, .mockResult: return .study
        case .ai, .voice: return .ai
        case .planner: return .planner
        case .account, .accountSettings, .badges: return .account
        default: return .home
        }
    }

    /// 저장되지 않는 기본값으로만 (알림 권한 창·자동 타이머·라이브 액티비티 끔)
    static func prepareDefaults() {
        UserDefaults.standard.register(defaults: [
            "selectedTab": tab.rawValue,
            AppearanceMode.key: isDark ? AppearanceMode.dark.rawValue : AppearanceMode.light.rawValue,
            SettingsKey.notificationsEnabled: false,
            SettingsKey.autoStartTimer: false,
            SettingsKey.liveActivityEnabled: false,
            SettingsKey.dDayTitle: "기말고사",
            SettingsKey.dDayDate: Date().startOfDay.addingTimeInterval(86_400 * 23).timeIntervalSince1970,
            SettingsKey.dailyWordGoal: 20,
            SettingsKey.dailyStudyGoalMinutes: 180
        ])
    }

    /// 메모리에만 있는 저장소 + 예시 데이터
    static func makeContainer() -> ModelContainer {
        let schema = AccountStore.schema
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        seed(container.mainContext)
        return container
    }

    /// 화면이 뜬 뒤 할 일 (두잇 AI 예시 대화, 타이머 열기)
    static func afterLaunch(timer: StudyTimer) async {
        switch screen {
        case .ai:
            let assistant = DoitAssistant.shared
            guard assistant.messages.isEmpty else { return }
            await assistant.send("2x + 3 = 11 풀어줘")
            await assistant.send("오늘 공부 계획 알려줘")
        case .timer:
            try? await Task.sleep(for: .milliseconds(300))
            timer.isPresented = true
        case .soundMixer:
            AmbientSoundPlayer.shared.showDemo([.rain, .cafe, .clock], levels: [.rain: 0.7, .cafe: 0.45, .clock: 0.25])
            try? await Task.sleep(for: .milliseconds(300))
            timer.isPresented = true
        default:
            break
        }
    }

    // MARK: 예시 데이터

    private static func seed(_ context: ModelContext) {
        let now = Date()
        let today = now.startOfDay
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            today.addingTimeInterval(TimeInterval(day * 86_400 + hour * 3600 + minute * 60))
        }

        // 과목 · 카테고리 (실제 첫 실행과 같은 목록)
        let defs: [(String, String, String, Bool)] = [
            ("국어", "book.fill", "#EF4444", true),
            ("영어", "character.book.closed.fill", "#3B82F6", true),
            ("수학", "function", "#10B981", true),
            ("개인", "person.fill", "#EC4899", false),
            ("약속", "person.2.fill", "#F59E0B", false),
            ("운동", "figure.run", "#F97316", false)
        ]
        var cats: [String: PlanCategory] = [:]
        for (i, d) in defs.enumerated() {
            let c = PlanCategory(name: d.0, symbol: d.1, colorHex: d.2, isStudy: d.3, sortIndex: i)
            context.insert(c)
            cats[d.0] = c
        }

        // 플랜: 오늘 · 이번 주
        let morning = Plan(title: "영어 단어 30개", startDate: at(0, 7, 30), durationMinutes: 30, repeatRule: .daily,
                           category: cats["영어"], kind: .study)
        morning.completedKeys = [today.dayKey]
        context.insert(morning)
        context.insert(Plan(title: "수학 오답 복습", startDate: at(0, 16, 0), durationMinutes: 90, category: cats["수학"], kind: .study, lockApps: true))
        context.insert(Plan(title: "국어 비문학 2지문", startDate: at(0, 19, 30), durationMinutes: 60, category: cats["국어"], kind: .study))
        context.insert(Plan(title: "헬스", startDate: at(0, 21, 30), durationMinutes: 50, repeatRule: .weekly, category: cats["운동"]))
        context.insert(Plan(title: "스터디 모임", startDate: at(1, 18, 0), durationMinutes: 120, category: cats["약속"]))
        context.insert(Plan(title: "수학 모의고사", startDate: at(2, 9, 0), durationMinutes: 100, category: cats["수학"], kind: .study))
        context.insert(Plan(title: "엄마 생신", startDate: at(4, 0, 0), durationMinutes: 0, isAllDay: true, category: cats["개인"]))

        // 공부 기록: 지난 2주
        let pattern: [(String, Int)] = [("수학", 70), ("영어", 45), ("국어", 50), ("수학", 40), ("영어", 25)]
        for day in 0..<14 {
            let count = day == 0 ? 2 : (day % 3 == 0 ? 2 : 3)
            for k in 0..<count {
                let p = pattern[(day + k) % pattern.count]
                let minutes = p.1 + ((day * 7 + k * 11) % 25)
                context.insert(StudySession(title: "\(p.0) 공부", categoryName: p.0, start: at(-day, 9 + k * 4),
                                            seconds: minutes * 60, planKey: nil))
            }
        }

        // 영어 단어
        let words: [(String, String)] = [
            ("abandon", "버리다, 포기하다"), ("benefit", "이익, 혜택"), ("crucial", "중대한, 결정적인"),
            ("diverse", "다양한"), ("efficient", "효율적인"), ("frequent", "잦은, 빈번한"),
            ("generous", "관대한, 너그러운"), ("hesitate", "망설이다"), ("inevitable", "피할 수 없는"),
            ("justify", "정당화하다"), ("maintain", "유지하다"), ("neglect", "무시하다, 방치하다"),
            ("obtain", "얻다, 획득하다"), ("perceive", "인식하다"), ("reluctant", "꺼리는"),
            ("significant", "중요한, 상당한"), ("tendency", "경향"), ("urge", "촉구하다"),
            ("vital", "필수적인"), ("withdraw", "철회하다, 인출하다"), ("accurate", "정확한"),
            ("consequence", "결과"), ("distinguish", "구별하다"), ("evaluate", "평가하다")
        ]
        for (i, w) in words.enumerated() {
            let word = Word(term: w.0, meaning: w.1, deck: i < 16 ? "수능 필수" : "기본 단어장", createdAt: now.addingTimeInterval(TimeInterval(-86_400 * (10 - i % 10))))
            if i < 11 {
                word.learnedAt = now.addingTimeInterval(TimeInterval(-86_400 * (i % 4)))
                word.reviewStage = i % 5
                word.correctCount = 2 + i % 3
                word.nextReviewAt = i % 3 == 0 ? now.addingTimeInterval(-3600) : now.addingTimeInterval(86_400 * 2)
            }
            if i == 7 || i == 14 { word.wrongCount = 2; word.isStarred = true }
            context.insert(word)
        }

        // 오답노트: 수학(인식한 글 · 확인함) · 영어 · 오답 · 정답
        let mathText = "12번) 이차방정식 x² - 5x + 6 = 0 의 두 근을 α, β라 할 때, α² + β² 의 값은?\n① 11  ② 12  ③ 13  ④ 14  ⑤ 15"
        let math = MathNote(title: "이차방정식 근과 계수", imageData: nil, thumbnailData: thumbnail(mathText), recognizedText: mathText, correctAnswer: "13")
        math.subject = NoteSubject.math.rawValue
        math.unit = "이차방정식"
        math.kind = .math
        math.isRecognitionConfirmed = true
        math.myAnswer = "12"
        math.status = .wrong
        math.createdAt = now.addingTimeInterval(-3600 * 2)
        math.updatedAt = math.createdAt
        context.insert(math)

        let engText = "3번) 다음 빈칸에 들어갈 말로 가장 알맞은 것은?\nShe was too tired ______ the meeting.\n① attend  ② attending  ③ to attend  ④ attended  ⑤ attends"
        let eng = MathNote(title: "to부정사 빈칸", imageData: nil, thumbnailData: thumbnail(engText), recognizedText: engText, correctAnswer: "③")
        eng.subject = NoteSubject.english.rawValue
        eng.unit = "to부정사"
        eng.isRecognitionConfirmed = true
        eng.status = .unsolved
        eng.createdAt = now.addingTimeInterval(-86_400)
        eng.updatedAt = eng.createdAt
        context.insert(eng)

        let fnText = "7번) 일차함수 y = 2x - 4 의 그래프의 x절편은?"
        let fn = MathNote(title: "일차함수 x절편", imageData: nil, thumbnailData: thumbnail(fnText), recognizedText: fnText, correctAnswer: "2")
        fn.subject = NoteSubject.math.rawValue
        fn.unit = "일차함수"
        fn.kind = .math
        fn.isRecognitionConfirmed = true
        fn.myAnswer = "2"
        fn.status = .correct
        fn.createdAt = now.addingTimeInterval(-86_400 * 3)
        fn.updatedAt = fn.createdAt
        context.insert(fn)

        // 취약 개념
        let weak: [(String, String, String, Int, Int, Double)] = [
            ("수학", "이차방정식", "근과 계수의 관계", 3, 5, 0.25),
            ("영어", "to부정사", "too ~ to 구문", 2, 4, 0.35),
            ("수학", "일차함수", "x절편 · y절편", 1, 6, 0.7)
        ]
        for w in weak {
            let c = WeakConcept(key: "\(w.0)|\(w.1)|\(w.2)", subject: w.0, unit: w.1, concept: w.2, problemType: "")
            c.wrongCount = w.3
            c.attemptCount = w.4
            c.mastery = w.5
            c.lastWrongAt = now.addingTimeInterval(-86_400)
            // 틀린 뒤 다시 맞힌 기록 (배지)
            c.records = (0..<w.4).map { k in
                DoitMastery.Record(date: now.addingTimeInterval(TimeInterval(-86_400 * (6 - k))), correct: k % 2 == 1, level: 2 + k % 3, source: "유사 문제")
            }
            context.insert(c)
        }

        // AI 학습 · 모의고사 풀이 기록
        context.insert(QuizRecord(subject: "공통수학1", unit: "인수분해", step: "problem", correct: 3, total: 5))
        context.insert(QuizRecord(subject: "공통영어", unit: "관계사", step: "ox", correct: 4, total: 6))
        let mockDate = now.addingTimeInterval(-86_400 * 2)
        for (subject, unit, correct, total) in [("수학", "이차방정식", 4, 6), ("영어", "to부정사", 3, 4)] {
            let record = QuizRecord(subject: subject, unit: unit, step: DoitMockExam.step, correct: correct, total: total)
            record.date = mockDate
            context.insert(record)
        }
        context.insert(AIQuestion(question: "이차방정식 근의 공식 설명해줘", imageData: nil, subject: "수학"))

        // 메모
        let memo = Memo(title: "수학 공식", content: "근과 계수: α+β = -b/a, αβ = c/a\nα²+β² = (α+β)² - 2αβ")
        memo.isPinned = true
        context.insert(memo)
        context.insert(Memo(title: "이번 주 할 일", content: "- 영어 단어 2회독\n- 국어 문학 개념 정리"))

        try? context.save()
    }

    /// 문제 글을 흰 종이에 쓴 것 같은 작은 그림 (목록 썸네일)
    private static func thumbnail(_ text: String) -> Data? {
        let size = CGSize(width: 240, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            (text as NSString).draw(in: CGRect(x: 14, y: 14, width: size.width - 28, height: size.height - 28), withAttributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor(white: 0.15, alpha: 1),
                .paragraphStyle: style
            ])
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}

/// 사진 찍을 화면이면 처음부터 그 하위 화면을 열어 둠
private struct UIShotPush<Destination: View>: ViewModifier {
    @State var isPresented: Bool
    let destination: () -> Destination

    func body(content: Content) -> some View {
        content.navigationDestination(isPresented: $isPresented, destination: destination)
    }
}

extension View {
    func uiShotPush<Destination: View>(_ screens: UIShotScreen..., @ViewBuilder destination: @escaping () -> Destination) -> some View {
        modifier(UIShotPush(isPresented: UIShot.screen.map { screens.contains($0) } ?? false, destination: destination))
    }
}
#endif
