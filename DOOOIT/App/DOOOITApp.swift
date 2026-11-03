import SwiftUI
import SwiftData
import CoreData
import Combine

@main
struct DOOOITApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var auth: AuthManager
    @State private var studyTimer = StudyTimer.shared
    /// 지금 로그인한 계정의 저장소 (계정마다 따로)
    @State private var container: ModelContainer

    init() {
        let auth = AuthManager()
        #if DEBUG
        // 화면 사진 찍기 (-uiShot): 데모 계정 + 메모리 저장소 (실제 계정·저장소는 열지 않음)
        if UIShot.isActive {
            UIShot.prepareDefaults()
            auth.useUIShotAccount(UIShot.demoUser)
            _auth = State(initialValue: auth)
            _container = State(initialValue: UIShot.makeContainer())
            return
        }
        #endif
        _auth = State(initialValue: auth)
        AccountStore.switchSettings(to: auth.currentUser?.id)
        _container = State(initialValue: AccountStore.container(for: auth.currentUser?.id))
    }

    /// 저장소를 쓰는 서비스들을 지금 계정 저장소에 연결
    @MainActor
    private func attachServices() {
        let context = container.mainContext
        #if DEBUG
        if UIShot.isActive {
            studyTimer.attach(context: context)
            DoitActions.shared.context = context
            DoitMemory.shared.attach(folder: nil)
            return
        }
        #endif
        if auth.currentUser != nil { SeedData.seedIfNeeded(context) }
        studyTimer.attach(context: context)
        PlanScheduler.shared.start(context: context, timer: studyTimer)
        DoitActions.shared.context = context
        // 두잇 AI가 배운 내용도 계정마다 따로 (로그인 전에는 저장하지 않음)
        DoitMemory.shared.attach(folder: auth.currentUser.map { AccountStore.folder(for: $0.id) })
        WidgetSync.update(context: context)
    }

    /// 로그인·로그아웃·계정 바꾸기: 진행 중인 타이머를 정리하고 그 계정의 저장소와 설정으로 바꿈
    @MainActor
    private func switchAccount(to userID: String?) {
        if studyTimer.isActive { studyTimer.stop() }
        LiveActivityManager.shared.endAll()
        DoitAssistant.shared.reset()
        AccountStore.switchSettings(to: userID)
        container = AccountStore.container(for: userID)
        AccountStore.removePendingIfNeeded()
        attachServices()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(studyTimer)
                .modelContainer(container)
                .task {
                    #if DEBUG
                    if UIShot.isActive {
                        attachServices()
                        await UIShot.afterLaunch(timer: studyTimer)
                        return
                    }
                    #endif
                    attachServices()
                    PaddleOCRService.shared.autoDownloadIfNeeded()
                    await auth.verifyAppleCredential()
                }
                .onChange(of: auth.currentUser?.id) { _, newID in
                    switchAccount(to: newID)
                }
                // Google 로그인 화면에서 돌아온 주소
                .onOpenURL { url in _ = AuthManager.handleGoogleURL(url) }
                // iCloud 동기화를 켜거나 끄면 저장소를 다시 엶
                .onReceive(NotificationCenter.default.publisher(for: AccountStore.storeChanged)) { _ in
                    #if DEBUG
                    if UIShot.isActive { return }
                    #endif
                    container = AccountStore.container(for: auth.currentUser?.id)
                    attachServices()
                }
                // iCloud에서 자료를 받아 오면: 기기마다 만든 기본 카테고리 합치기
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).debounce(for: .seconds(2), scheduler: RunLoop.main)) { _ in
                    guard AccountStore.isSyncEnabled(for: auth.currentUser?.id) else { return }
                    SeedData.mergeDuplicateCategories(container.mainContext)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            #if DEBUG
            if UIShot.isActive { return }
            #endif
            if phase == .background || phase == .inactive {
                WidgetSync.update(context: container.mainContext)
            }
            if phase == .active {
                WidgetSync.update(context: container.mainContext)
                PlanScheduler.shared.tick()
                PlanScheduler.shared.rescheduleNotifications()
                // 뒤로 가서 끊긴 정밀 인식 받기를 이어서
                PaddleOCRService.shared.autoDownloadIfNeeded()
            }
        }
    }
}
