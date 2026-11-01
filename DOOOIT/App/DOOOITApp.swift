import SwiftUI
import SwiftData

@main
struct DOOOITApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var auth = AuthManager()
    @State private var studyTimer = StudyTimer.shared
    @State private var credits = CreditStore.shared

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Plan.self, PlanCategory.self, Word.self, MathNote.self, Memo.self, StudySession.self,
                ExamPlan.self, StudyContent.self, QuizRecord.self, AIQuestion.self
            )
        } catch {
            fatalError("데이터 저장소를 열 수 없어요: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(studyTimer)
                .environment(credits)
                .task {
                    let context = container.mainContext
                    SeedData.seedIfNeeded(context)
                    studyTimer.attach(context: context)
                    PlanScheduler.shared.start(context: context, timer: studyTimer)
                    credits.grantDailyIfNeeded()
                    RewardedAdManager.shared.start()
                    await auth.verifyAppleCredential()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                credits.grantDailyIfNeeded()
                PlanScheduler.shared.tick()
                PlanScheduler.shared.rescheduleNotifications()
            }
        }
    }
}
