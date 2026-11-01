import SwiftUI
import SwiftData

@main
struct DOOOITApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var auth = AuthManager()
    @State private var studyTimer = StudyTimer.shared

    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    /// 저장소 열기. 열 수 없으면 (예: 업데이트 뒤 형식이 맞지 않음) 앱이 매번 꺼지지 않도록
    /// 기존 파일을 지우지 않고 옆에 백업해 둔 뒤 새 저장소로 시작함
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Plan.self, PlanCategory.self, Word.self, MathNote.self, Memo.self, StudySession.self,
            ExamPlan.self, StudyContent.self, QuizRecord.self, AIQuestion.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            let support = URL.applicationSupportDirectory
            let stamp = Int(Date().timeIntervalSince1970)
            for name in ["default.store", "default.store-shm", "default.store-wal"] {
                let url = support.appending(path: name)
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                    try? FileManager.default.moveItem(at: url, to: support.appending(path: "\(name).backup-\(stamp)"))
                }
            }
            if let fresh = try? ModelContainer(for: schema) { return fresh }
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("데이터 저장소를 열 수 없어요: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(studyTimer)
                .task {
                    let context = container.mainContext
                    SeedData.seedIfNeeded(context)
                    studyTimer.attach(context: context)
                    PlanScheduler.shared.start(context: context, timer: studyTimer)
                    DoitActions.shared.context = context
                    WidgetSync.update(context: context)
                    await auth.verifyAppleCredential()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                WidgetSync.update(context: container.mainContext)
            }
            if phase == .active {
                WidgetSync.update(context: container.mainContext)
                PlanScheduler.shared.tick()
                PlanScheduler.shared.rescheduleNotifications()
            }
        }
    }
}
